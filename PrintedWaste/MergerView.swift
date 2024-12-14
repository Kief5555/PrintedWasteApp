//
//  MergerView.swift
//  PrintedWaste
//
//  Created by Kiefer Lin on 2024-12-13.
//

import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import PDFKit

struct PDFMergerView: View {
    @State private var selectedFiles: [MergeItem] = []
    @State private var isMerging: Bool = false
    @State private var errorMessage: String?
    @State private var showFilePicker = false
    @State private var showPhotoPicker = false
    @State private var mergedPDFURL: URL?
    @State private var showSourceMenu = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showPDFPreview = false
    @State private var previewURL: URL?
    @State private var mergedPDFData: Data?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Description section
            VStack(alignment: .leading, spacing: 8) {
                Text("Combine PDFs and Images")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Select multiple files to merge them into a single PDF document.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Selected files list
            if !selectedFiles.isEmpty {
                VStack(spacing: 0) {
                    List {
                        ForEach(selectedFiles) { item in
                            HStack(spacing: 12) {
                                // Preview thumbnail
                                Group {
                                    if let image = item.thumbnail {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .cornerRadius(6)
                                    } else {
                                        Image(systemName: "doc.fill")
                                            .foregroundColor(.accentColor)
                                            .frame(width: 40, height: 40)
                                    }
                                }
                                
                                Text(item.filename)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 8)
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove(perform: moveItems)
                        .onDelete(perform: removeItems)
                    }
                    .listStyle(.insetGrouped)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            selectedFiles.removeAll()
                        }) {
                            Label("Clear All", systemImage: "trash")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(isMerging ? 0 : 1)
                        .animation(.easeInOut, value: isMerging)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
            
            Spacer(minLength: 0)
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // Buttons section
            VStack(spacing: 16) {
                if !isMerging {
                    Button(action: { showSourceMenu = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Files")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .confirmationDialog("Choose Source", isPresented: $showSourceMenu) {
                        Button("Files") {
                            showFilePicker = true
                        }
                        Button("Photo Library") {
                            showPhotoPicker = true
                        }
                    }
                }
                
                if selectedFiles.count >= 2 {
                    Button(action: mergePDFs) {
                        if isMerging {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Merge Files")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isMerging)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .navigationTitle("PDF Merger")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf, UTType.image],
            allowsMultipleSelection: true
        ) { result in
            handleSelectedFiles(result)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotos,
            matching: .images
        )
        .onChange(of: selectedPhotos) { photos in
            handleSelectedPhotos(photos)
        }
        .sheet(isPresented: $showPDFPreview) {
            if let url = previewURL {
                PDFPreviewView(downloadURL: url, pdfData: mergedPDFData, isPresented: $showPDFPreview)
            }
        }
    }
    
    private func handleSelectedFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    if let item = try? await MergeItem(url: url) {
                        DispatchQueue.main.async {
                            selectedFiles.append(item)
                        }
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            let mergeItem = MergeItem(image: image, filename: "Image \(selectedFiles.count + 1)")
                            selectedFiles.append(mergeItem)
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to load image: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        selectedFiles.move(fromOffsets: source, toOffset: destination)
    }
    
    private func removeItems(at offsets: IndexSet) {
        selectedFiles.remove(atOffsets: offsets)
    }
    
    private func mergePDFs() {
        guard !selectedFiles.isEmpty else { return }
        
        isMerging = true
        errorMessage = nil
        
        Task {
            do {
                let url = URL(string: "https://api.printedwaste.com/pdf/merge")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                
                let boundary = "Boundary-\(UUID().uuidString)"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                var formData = Data()
                
                // Add files to form data
                for (index, item) in selectedFiles.enumerated() {
                    formData.append("--\(boundary)\r\n".data(using: .utf8)!)
                    
                    // Convert non-PDF files to JPEG
                    if !item.filename.lowercased().hasSuffix(".pdf"),
                       let image = item.thumbnail,
                       let jpegData = image.jpegData(compressionQuality: 0.8) {
                        formData.append("Content-Disposition: form-data; name=\"files\"; filename=\"image\(index).jpg\"\r\n".data(using: .utf8)!)
                        formData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                        formData.append(jpegData)
                    } else {
                        formData.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(item.filename)\"\r\n".data(using: .utf8)!)
                        formData.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
                        formData.append(item.data)
                    }
                    
                    formData.append("\r\n".data(using: .utf8)!)
                }
                
                formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
                request.httpBody = formData
                
                // Add timeout
                request.timeoutInterval = 30
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response status code: \(httpResponse.statusCode)")
                    print("Response: \(String(decoding: data, as: UTF8.self))")
                    
                    if httpResponse.statusCode == 200 {
                        if let jsonData = try? JSONDecoder().decode(MergeResponse.self, from: data) {
                            if let downloadURL = jsonData.data.download,
                               let url = URL(string: downloadURL) {
                                await MainActor.run {
                                    self.previewURL = url
                                    if let pdfData = jsonData.data.pdf {
                                        self.mergedPDFData = Data(base64Encoded: pdfData)
                                    }
                                    self.showPDFPreview = true
                                    self.selectedFiles.removeAll()
                                }
                            }
                        } else {
                            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                        }
                    } else {
                        // Print response body for debugging
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("Response body: \(responseString)")
                        }
                        throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    }
                }
            } catch {
                await MainActor.run {
                    print("Error: \(error)")
                    errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                isMerging = false
            }
        }
    }
}

// Helper structures
struct MergeResponse: Codable {
    let data: MergeData
}

struct MergeData: Codable {
    let download: String?
    let pdf: String?  // Base64 encoded PDF data
}

// New MergeItem structure to handle both files and images
struct MergeItem: Identifiable {
    let id = UUID()
    let filename: String
    let thumbnail: UIImage?
    let data: Data
    
    init(url: URL) throws {
        let data = try Data(contentsOf: url)
        self.data = data
        self.filename = url.lastPathComponent
        
        if url.pathExtension.lowercased() == "pdf" {
            // Create PDF thumbnail
            if let pdf = CGPDFDocument(url as CFURL),
               let page = pdf.page(at: 1) {
                let pageRect = page.getBoxRect(.mediaBox)
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                self.thumbnail = renderer.image { ctx in
                    UIColor.white.set()
                    ctx.fill(pageRect)
                    ctx.cgContext.translateBy(x: 0, y: pageRect.height)
                    ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                    ctx.cgContext.drawPDFPage(page)
                }
            } else {
                self.thumbnail = nil
            }
        } else {
            // Create image thumbnail
            self.thumbnail = UIImage(data: data)
        }
    }
    
    init(image: UIImage, filename: String) {
        self.thumbnail = image
        self.filename = filename
        self.data = image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}

struct PDFPreviewView: View {
    let downloadURL: URL
    let pdfData: Data?
    @Binding var isPresented: Bool
    @State private var loadedPDFData: Data?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading PDF...")
                } else if let error = error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.secondary)
                    }
                } else if let pdf = loadedPDFData {
                    PDFKitView(data: pdf)
                }
            }
            .navigationTitle("PDF Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIApplication.shared.open(downloadURL)
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                }
            }
        }
        .onAppear {
            if let providedData = pdfData {
                // Use the provided PDF data if available
                loadedPDFData = providedData
                isLoading = false
            } else {
                // Fall back to downloading if no data provided
                loadPDF()
            }
        }
    }
    
    private func loadPDF() {
        Task {  
            do {
                let (data, _) = try await URLSession.shared.data(from: downloadURL)
                await MainActor.run {
                    self.loadedPDFData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load PDF: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true)
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        
        // Add gesture recognizers for zooming
        if let scrollView = pdfView.subviews.first as? UIScrollView {
            scrollView.delegate = context.coordinator
            scrollView.bounces = true
            scrollView.bouncesZoom = true
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
            pdfView.goToFirstPage(nil)
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: PDFKitView
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }
    }
}

#Preview {
    PDFMergerView()
}

