import SwiftUI
import Charts

struct QueueDataV2: Codable {
    let timestamp: TimeInterval
    let data: [String: ServerQueueData]
    
    // Convert milliseconds to seconds
    var date: Date {
        Date(timeIntervalSince1970: timestamp / 1000)
    }
}

struct ServerQueueData: Codable {
    let QueuePosition: Int
    let lastUpdated: TimeInterval
    let region: String

    enum CodingKeys: String, CodingKey {
        case QueuePosition
        case lastUpdated = "Last Updated"
        case region = "Region"
    }
}

enum QueueDataResponse: Codable {
    case success([QueueDataV2])
    case failure(ErrorResponse)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([QueueDataV2].self) {
            self = .success(array)
            return
        }
        if let errorResponse = try? container.decode(ErrorResponse.self) {
            self = .failure(errorResponse)
            return
        }
        throw DecodingError.typeMismatch(
            QueueDataResponse.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected to decode Array or ErrorResponse"
            )
        )
    }
}

struct ErrorResponse: Codable {
    let error: String
}


struct ChartData: Identifiable {
    let id = UUID()
    let date: String
    let queuePosition: Int
}

struct GFNServerView: View {
    let endpoint: String
    let server: String // Passed in from outside, not hardcoded

    @State private var chartData: [ChartData] = []
    @State private var isLoading = true
    @State private var selectedTimeRange: String = "24h"
    @State private var avgQueuePosition: Int?
    @State private var minQueuePosition: Int?
    @State private var maxQueuePosition: Int?
    @State private var selectedPoint: ChartData?
    @State private var chartSize: CGSize = .zero

    let timeRanges: [String: Int] = [
        "24h": 24,
        "7d": 7 * 24,
        "14d": 14 * 24,
        "30d": 30 * 24,
        "lifetime": 9999 * 24
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(timeRanges.keys.sorted(), id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .pickerStyle(.menu)
                .padding()
            }

            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                } else {
                    GeometryReader { geo in
                        let gradient = LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.5),
                                Color.blue.opacity(0.2),
                                Color.blue.opacity(0.05)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        Chart(chartData) { d in
                            AreaMark(
                                x: .value("Date", d.date),
                                y: .value("Queue Position", d.queuePosition)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(gradient)

                            LineMark(
                                x: .value("Date", d.date),
                                y: .value("Queue Position", d.queuePosition)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .foregroundStyle(Color.blue)

                            if #available(iOS 16.4, *) {
                                PointMark(
                                    x: .value("Date", d.date),
                                    y: .value("Queue Position", d.queuePosition)
                                )
                                .foregroundStyle(selectedPoint?.id == d.id ? Color.blue : Color.blue.opacity(0.6))
                                .symbolSize(selectedPoint?.id == d.id ? 150 : 100)
                                .shadow(color: .blue.opacity(0.3), radius: selectedPoint?.id == d.id ? 4 : 2)
                            } else {
                                // Fallback on earlier versions
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: 1)) { value in
                                AxisGridLine()
                                    .foregroundStyle(.gray.opacity(0.2))
                                AxisTick()
                                    .foregroundStyle(.gray.opacity(0.6))
                                AxisValueLabel(centered: true)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisGridLine()
                                    .foregroundStyle(.gray.opacity(0.2))
                                AxisTick()
                                    .foregroundStyle(.gray.opacity(0.6))
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .chartBackground { proxy in
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(uiColor: .systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        .padding()
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let localPoint = value.location
                                    if let nearestData = findNearestDataPoint(at: localPoint, in: chartData, chartWidth: geo.size.width) {
                                        withAnimation(.easeInOut) {
                                            selectedPoint = nearestData
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeInOut) {
                                        selectedPoint = nil
                                    }
                                }
                        )
                        .onAppear {
                            chartSize = geo.size
                        }
                        .onChange(of: geo.size) { newSize in
                            chartSize = newSize
                        }
                        .overlay(alignment: .top) {
                            ZStack(alignment: .topTrailing) {
                                if let avg = avgQueuePosition {
                                    ReferenceLine(position: avg, label: "Avg: \(avg)", color: .orange)
                                }
                                if let minVal = minQueuePosition {
                                    ReferenceLine(position: minVal, label: "Min: \(minVal)", color: .green, alignment: .bottomLeading)
                                }
                                if let maxVal = maxQueuePosition {
                                    ReferenceLine(position: maxVal, label: "Max: \(maxVal)", color: .red)
                                }
                            }
                        }

                        if let point = selectedPoint {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(point.date)
                                    .font(.callout.bold())
                                    .foregroundStyle(.primary)
                                HStack {
                                    Text("Queue Position:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(point.queuePosition)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            .transition(.scale.combined(with: .opacity))
                            .padding(.top, 50)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(radius: 10)
                    .padding()
            )

            Spacer()
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            fetchData()
        }
        .onChange(of: selectedTimeRange) { _ in
            fetchData()
        }
    }

    func fetchData() {
        guard let hours = timeRanges[selectedTimeRange] else { return }
        let urlString = "\(endpoint)/gfn/queue/cors?hours=\(hours)&server=\(server)"
        guard let url = URL(string: urlString) else { return }

        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { isLoading = false }
            guard let data = data, error == nil else { return }

            do {
                let decodedResponse = try JSONDecoder().decode(QueueDataResponse.self, from: data)
                switch decodedResponse {
                case .success(let decodedData):
                    let groupedData = processQueueData(decodedData)
                    DispatchQueue.main.async {
                        self.chartData = groupedData
                        self.avgQueuePosition = calculateAverageQueuePosition(groupedData)
                        self.minQueuePosition = groupedData.map(\.queuePosition).min()
                        self.maxQueuePosition = groupedData.map(\.queuePosition).max()
                    }
                case .failure(let errorResponse):
                    print("Server Error: \(errorResponse.error)")
                    // Handle the error accordingly, e.g., show an alert to the user
                }
            } catch {
                print("Failed to decode data: \(error)")
                // Optionally, print the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response String: \(responseString)")
                }
            }
        }.resume()
    }

    func processQueueData(_ data: [QueueDataV2]) -> [ChartData] {
        var groupedData: [String: [Int]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm" // Adjust as needed

        for entry in data {
            let date = formatter.string(from: entry.date)

            if let serverEntry = entry.data[server] {
                if groupedData[date] == nil {
                    groupedData[date] = []
                }
                groupedData[date]?.append(serverEntry.QueuePosition)
            }
        }

        var processedData: [ChartData] = []
        for (date, positions) in groupedData {
            guard !positions.isEmpty else { continue }
            let average = positions.reduce(0, +) / positions.count
            processedData.append(ChartData(date: date, queuePosition: average))
        }

        return processedData.sorted(by: { $0.date < $1.date })
    }

    func calculateAverageQueuePosition(_ data: [ChartData]) -> Int? {
        guard !data.isEmpty else { return nil }
        let total = data.map { $0.queuePosition }.reduce(0, +)
        return total / data.count
    }

    func findNearestDataPoint(at location: CGPoint, in data: [ChartData], chartWidth: CGFloat) -> ChartData? {
        guard !data.isEmpty else { return nil }
        let totalCount = data.count
        if totalCount == 1 { return data[0] }

        let step = chartWidth / CGFloat(totalCount - 1)
        let indexFloat = location.x / step
        let nearestIndex = max(0, min(totalCount - 1, Int(round(indexFloat))))
        return data[nearestIndex]
    }
}

struct ReferenceLine: View {
    let position: Int
    let label: String
    let color: Color
    var alignment: Alignment = .topTrailing

    var body: some View {
        GeometryReader { proxy in
            let yPos = proxy.size.height * 0.2 // adjust if necessary
            Text(label)
                .font(.caption2)
                .foregroundColor(color)
                .padding(4)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                .position(x: alignment == .bottomLeading ? 40 : proxy.size.width - 40, y: yPos)
        }
    }
}
