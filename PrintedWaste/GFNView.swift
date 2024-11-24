//
//  GFNView.swift
//  PrintedWaste
//
//  Created by Kiefer Lin on 2024-05-09.
//

import SwiftUI
import Foundation
import SwiftDate

struct ServerData: Codable {
    let queuePosition: Int
    let lastUpdated: Int
    let name: String

    private enum CodingKeys: String, CodingKey {
        case queuePosition = "QueuePosition"
        case lastUpdated = "Last Updated"
        case name = "Name"
    }
}

struct RegionData: Codable {
    let servers: [String: ServerData]
}

typealias QueueData = [String: ServerData]

struct Subserver: Codable, Identifiable {
    let id: String
    let is4080Server: Bool
}

struct ServerRegion: Codable {
    let isAlliance: Bool
    let is4080Ready: Bool
    let subservers: [Subserver]
}




func loadServerData() -> AllServerData? {
    guard let url = Bundle.main.url(forResource: "serverData", withExtension: "json") else {
        print("Server data file not found.")
        return nil
    }

    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(AllServerData.self, from: data)
    } catch {
        print("Error decoding server data: \(error)")
        return nil
    }
}


typealias AllServerData = [String: ServerRegion]


struct GFNView: View {
    @State private var queueData: [String: QueueData] = [:]
    @State private var isLoading = true

    var body: some View {
            VStack {
                if isLoading {
                    ProgressView("LOADING...")
                } else {
                    List(queueData.sorted(by: { $0.key < $1.key }), id: \.key) { key, servers in
                        Section(header: Text(key).font(.headline)) {
                            ForEach(servers.sorted(by: { $0.key < $1.key }), id: \.key) { key, server in
                                ServerLink(key: key, server: server)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("GFN Queue")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await fetchData()
            }
            .onAppear {
                Task {
                    await fetchData()
                    setupAutoRefresh()
                }
            }
    }

    private func setupAutoRefresh() {
        Task {
            do {
                while true {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    await fetchData()
                }
            } catch {
                print("Error during auto-refresh: \(error)")
            }
        }
    }

    private func fetchData() async {
        guard let url = URL(string: "https://api.printedwaste.com/gfn/queue?advanced=true") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("PrintedWasteApp/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decodedData = try JSONDecoder().decode([String: QueueData].self, from: data)
            DispatchQueue.main.async {
                self.queueData = decodedData
                self.isLoading = false
            }
        } catch {
            print("Error fetching data: \(error)")
        }
    }
}

struct ServerLink: View {
    var key: String
    var server: ServerData

    var body: some View {
        NavigationLink(destination: GFNServerView(serverName: key)) {
            HStack {
                // Badge with queue position and conditional color
                Text("\(server.queuePosition)")
                    .font(.subheadline)
                    .padding(5)
                    .frame(width: 40, height: 30)
                    .background(
                        Rectangle()
                            .fill(
                                server.queuePosition > 100 ? Color.red :
                                server.queuePosition > 50 ? Color.yellow :
                                Color.green
                            )
                            .cornerRadius(10)
                    )
                    .foregroundColor(.black)
                
                VStack(alignment: .leading) {
                    Text("\(server.name)")
                    Text("\(key) • \(Date(timeIntervalSince1970: TimeInterval(server.lastUpdated)).toRelative(since: nil))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

