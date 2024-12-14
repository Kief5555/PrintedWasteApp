//
//  ToolsView.swift
//  PrintedWaste
//
//  Created by Kiefer Lin on 2024-12-13.
//

import SwiftUI



struct ToolsView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var isDarkMode: Bool {
          colorScheme == .dark
    }
    
    var body: some View {
            List {
                NavigationLink(destination: PDFMergerView()) {
                    HStack {
                        Image(systemName: "arrow.trianglehead.merge")
                            .applyStackImageStyling()
                        Text("PDF Merger")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                }
                .padding(0.1)
            }
            .navigationBarTitle("Tools")
    }
}


struct ToolsView_Previews: PreviewProvider {
    static var previews: some View {
        ToolsView()
    }
}
