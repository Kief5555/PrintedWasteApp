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
    @State private var currenQueuePosition: Int?
    @State private var maxQueuePosition: Int?
    @State private var selectedPoint: ChartData?
    @State private var chartSize: CGSize = .zero
    @State private var tooltipPosition: CGPoint = .zero
    @State private var dateRangeText: String = ""

    let timeRanges: [String: Int] = [
        "24h": 24,
        "7d": 7 * 24,
        "14d": 14 * 24,
        "30d": 30 * 24,
        "lifetime": 9999 * 24
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Stats Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Current",
                        value: currenQueuePosition ?? 0,
                        color: .gray
                    )
                    StatCard(
                        title: "High",
                        value: maxQueuePosition ?? 0,
                        color: .red
                    )
                    StatCard(
                        title: "Low",
                        value: minQueuePosition ?? 0,
                        color: Color(red: 0.2, green: 0.5, blue: 0)
                    )
                    StatCard(
                        title: "Average",
                        value: avgQueuePosition ?? 0,
                        color: Color(red: 0.85, green: 0.45, blue: 0)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            // Date Range
            Text(dateRangeText)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // Chart
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    GeometryReader { geo in
                        let gradient = LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.2),
                                Color.blue.opacity(0.05),
                                Color.blue.opacity(0.02)
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
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .foregroundStyle(Color.blue)

                            if let selectedPoint = selectedPoint, selectedPoint.date == d.date {
                                RuleMark(
                                    x: .value("Selected", d.date)
                                )
                                .foregroundStyle(Color.gray.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                                PointMark(
                                    x: .value("Date", d.date),
                                    y: .value("Queue Position", d.queuePosition)
                                )
                                .foregroundStyle(.blue)
                                .symbolSize(100)
                            }
                        }
                        .frame(height: 220)
                        .chartYScale(domain: 0...max((maxQueuePosition ?? 200) + 20, 200))
                        .chartXAxis {
                            AxisMarks(values: .stride(by: 1)) { value in
                                AxisGridLine()
                                    .foregroundStyle(Color.gray.opacity(0.1))
                                AxisTick()
                                    .foregroundStyle(Color.gray.opacity(0.2))
                                AxisValueLabel(centered: true)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.gray.opacity(0.7))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .stride(by: 50)) { value in
                                AxisGridLine()
                                    .foregroundStyle(Color.gray.opacity(0.1))
                                AxisTick()
                                    .foregroundStyle(Color.gray.opacity(0.2))
                                AxisValueLabel() {
                                    if let intValue = value.as(Int.self) {
                                        Text("\(intValue)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.gray.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let localPoint = value.location
                                    tooltipPosition = value.location
                                    if let nearestData = findNearestDataPoint(at: localPoint, in: chartData, chartWidth: geo.size.width) {
                                        withAnimation(.easeInOut(duration: 0.1)) {
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
                        .overlay {
                            if let point = selectedPoint {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(point.date)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 4) {
                                        Text("Queue:")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        Text("\(point.queuePosition)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(10)
                                .background(Color(uiColor: .systemBackground).opacity(0.95))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.1), radius: 5)
                                .position(x: min(max(tooltipPosition.x, 80), geo.size.width - 80),
                                         y: max(tooltipPosition.y - 40, 40))
                            }
                        }
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Color(uiColor: .systemBackground))
        .navigationBarItems(trailing: 
            Menu {
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(timeRanges.keys.sorted(), id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
            } label: {
                HStack {
                    Text(selectedTimeRange)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.blue)
            }
        )
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
                    
                    // Get current queue position from the most recent data point
                    let currentPosition = decodedData
                        .sorted(by: { $0.date > $1.date }) // Sort by most recent
                        .first
                        .flatMap { $0.data[server]?.QueuePosition }
                    
                    DispatchQueue.main.async {
                        self.chartData = groupedData
                        self.avgQueuePosition = calculateAverageQueuePosition(groupedData)
                        self.minQueuePosition = groupedData.map(\.queuePosition).min()
                        self.maxQueuePosition = groupedData.map(\.queuePosition).max()
                        self.currenQueuePosition = currentPosition
                    }
                case .failure(let errorResponse):
                    print("Server Error: \(errorResponse.error)")
                }
            } catch {
                print("Failed to decode data: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response String: \(responseString)")
                }
            }
        }.resume()
    }

    func processQueueData(_ data: [QueueDataV2]) -> [ChartData] {
        let formatter = DateFormatter()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        // Determine aggregation interval and format based on time range
        let (aggregationUnit, dateFormat): (Calendar.Component, String) = {
            switch selectedTimeRange {
                case "24h":
                    return (.hour, "HH:mm")
                case "7d":
                    return (.hour, "MMM d HH:mm")
                case "14d", "30d", "lifetime":
                    return (.day, "MMM d")
                default:
                    return (.hour, "MMM d HH:mm")
            }
        }()
        
        formatter.dateFormat = dateFormat
        
        // Sort data by timestamp first
        let sortedData = data.sorted { $0.date < $1.date }
        
        // Group data by the appropriate time unit
        var timeWindows: [Date: [Int]] = [:]
        var earliestDate: Date?
        var latestDate: Date?
        
        for entry in sortedData {
            let date = entry.date
            
            // Get the start of the time unit (hour or day)
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            if aggregationUnit == .hour {
                components.hour = calendar.component(.hour, from: date)
            }
            let windowDate = calendar.date(from: components) ?? date
            
            if earliestDate == nil || date < earliestDate! {
                earliestDate = date
            }
            if latestDate == nil || date > latestDate! {
                latestDate = date
            }
            
            if let serverEntry = entry.data[server] {
                if timeWindows[windowDate] == nil {
                    timeWindows[windowDate] = []
                }
                timeWindows[windowDate]?.append(serverEntry.QueuePosition)
            }
        }
        
        // Process windows into data points
        var processedData: [ChartData] = []
        
        for (windowDate, positions) in timeWindows.sorted(by: { $0.key < $1.key }) {
            guard !positions.isEmpty else { continue }
            
            // Calculate value with outlier removal
            let mean = Double(positions.reduce(0, +)) / Double(positions.count)
            let variance = positions.map { pow(Double($0) - mean, 2) }.reduce(0, +) / Double(positions.count)
            let stdDev = sqrt(variance)
            
            // Filter out outliers (values more than 2 standard deviations from mean)
            let filteredPositions = positions.filter {
                abs(Double($0) - mean) <= 2 * stdDev
            }
            
            let finalValue = filteredPositions.isEmpty ?
                positions.reduce(0, +) / positions.count :
                filteredPositions.reduce(0, +) / filteredPositions.count
            
            processedData.append(ChartData(
                date: formatter.string(from: windowDate),
                queuePosition: finalValue
            ))
        }
        
        // Update date range text
        if let earliest = earliestDate, let latest = latestDate {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d"
            let startDate = displayFormatter.string(from: earliest)
            let endDate = displayFormatter.string(from: latest)
            DispatchQueue.main.async {
                self.dateRangeText = "\(startDate) - \(endDate)"
            }
        }
        
        // For 24h view, ensure we have enough points for smooth display
        if selectedTimeRange == "24h" && processedData.count < 24 {
            // Fill in missing hours with interpolated values
            var filledData: [ChartData] = []
            if let firstDate = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: earliestDate ?? Date())) {
                for hour in 0..<24 {
                    let currentDate = calendar.date(byAdding: .hour, value: hour, to: firstDate)!
                    let dateString = formatter.string(from: currentDate)
                    
                    if let existingPoint = processedData.first(where: { $0.date == dateString }) {
                        filledData.append(existingPoint)
                    } else {
                        // Find nearest points for interpolation
                        if let before = processedData.last(where: { $0.date < dateString }),
                           let after = processedData.first(where: { $0.date > dateString }) {
                            // Simple linear interpolation
                            let beforeIndex = processedData.firstIndex(where: { $0.date == before.date })!
                            let afterIndex = processedData.firstIndex(where: { $0.date == after.date })!
                            let progress = Double(hour - beforeIndex) / Double(afterIndex - beforeIndex)
                            let interpolatedValue = before.queuePosition + Int(Double(after.queuePosition - before.queuePosition) * progress)
                            filledData.append(ChartData(date: dateString, queuePosition: interpolatedValue))
                        }
                    }
                }
                if !filledData.isEmpty {
                    processedData = filledData
                }
            }
        }
        
        return processedData
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

struct StatCard: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(width: 100, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }
}
