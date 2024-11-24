import SwiftUI
import Charts

struct QueueDataV2: Codable {
    let timestamp: TimeInterval
    let data: [String: ServerQueueData]
}

struct ServerQueueData: Codable {
    let QueuePosition: Int
}

struct ChartData: Identifiable {
    let id = UUID()
    let date: String
    let queuePosition: Int
}

struct GFNServerView: View {
    var serverName: String
    @State private var chartData: [ChartData] = []
    @State private var isLoading = true
    @State private var selectedTimeRange: String = "24h"
    @State private var avgQueuePosition: Int?
    @State private var selectedPoint: ChartData?

    let timeRanges: [String: Int] = [
        "24h": 24,
        "7d": 7 * 24,
        "14d": 14 * 24,
        "30d": 30 * 24,
        "lifetime": 9999 * 24
    ]

    var body: some View {
        VStack {
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(timeRanges.keys.sorted(), id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            ZStack {
                Chart {
                    ForEach(chartData) { data in
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("Queue Position", data.queuePosition)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        // Highlight the selected point
                        if selectedPoint?.id == data.id {
                            PointMark(
                                x: .value("Date", data.date),
                                y: .value("Queue Position", data.queuePosition)
                            )
                            .foregroundStyle(.red)
                            .symbolSize(10)
                        }
                    }

                    if let avg = avgQueuePosition {
                        RuleMark(y: .value("Average", avg))
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Avg: \(avg)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 1)) { value in
                        if let stringValue = value.as(String.self) {
                            AxisValueLabel(stringValue, centered: true)
                        }
                        AxisTick()
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisValueLabel()
                        AxisTick()
                        AxisGridLine()
                    }
                }
                .padding()
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if let nearestData = findNearestDataPoint(at: value.location, in: chartData) {
                                selectedPoint = nearestData
                            }
                        }
                        .onEnded { _ in
                            selectedPoint = nil // Clear selection when gesture ends
                        }
                )

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        .scaleEffect(1.5)
                }
            }

            if let point = selectedPoint {
                TooltipView(data: point)
                    .transition(.opacity)
            }
        }
        .navigationTitle(serverName)
        .onAppear {
            fetchData()
        }
        .onChange(of: selectedTimeRange) { _ in
            fetchData()
        }
    }

    func fetchData() {
        guard let hours = timeRanges[selectedTimeRange] else { return }
        let urlString = "https://api.printedwaste.com/gfn/queue/cors?hours=\(hours)"
        guard let url = URL(string: urlString) else { return }

        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { isLoading = false }
            guard let data = data, error == nil else { return }
            do {
                let decodedData = try JSONDecoder().decode([QueueDataV2].self, from: data)
                let groupedData = processQueueData(decodedData)
                DispatchQueue.main.async {
                    self.chartData = groupedData
                    self.avgQueuePosition = calculateAverageQueuePosition(groupedData)
                }
            } catch {
                print("Failed to decode data: \(error)")
            }
        }.resume()
    }

    func processQueueData(_ data: [QueueDataV2]) -> [ChartData] {
        var groupedData: [String: [Int]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for entry in data {
            let date = formatter.string(from: Date(timeIntervalSince1970: entry.timestamp))
            if groupedData[date] == nil {
                groupedData[date] = []
            }

            for serverData in entry.data.values {
                groupedData[date]?.append(serverData.QueuePosition)
            }
        }

        var processedData: [ChartData] = []
        for (date, positions) in groupedData {
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

    func findNearestDataPoint(at location: CGPoint, in data: [ChartData]) -> ChartData? {
        // Logic to map the touch location to the nearest data point
        // Implement this logic based on your chart's scaling and position
        nil // Placeholder: implement the actual logic
    }
}

struct TooltipView: View {
    let data: ChartData

    var body: some View {
        VStack {
            Text("Date: \(data.date)")
                .font(.caption)
            Text("Queue Position: \(data.queuePosition)")
                .font(.caption)
                .bold()
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
    }
}
