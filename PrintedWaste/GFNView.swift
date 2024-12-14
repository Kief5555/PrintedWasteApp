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

@propertyWrapper
struct SetStorage {
    private let key: String
    private let defaultValue: Set<String>
    private let storage: UserDefaults

    init(wrappedValue: Set<String> = [], key: String, storage: UserDefaults = .standard) {
        self.defaultValue = wrappedValue
        self.key = key
        self.storage = storage
    }

    var wrappedValue: Set<String> {
        get {
            let array = storage.array(forKey: key) as? [String] ?? []
            return Set(array)
        }
        set {
            storage.set(Array(newValue), forKey: key)
        }
    }
}

struct GFNView: View {
    @State private var queueData: [String: QueueData] = [:]
    @State private var isLoading = true
    @State private var favoriteServers: Set<String> = {
        let array = UserDefaults.standard.array(forKey: "favoriteServers") as? [String] ?? []
        return Set(array)
    }()

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Servers")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !favoriteServers.isEmpty {
                        Section {
                            ForEach(queueData.values.flatMap { $0.filter { favoriteServers.contains($0.key) } }
                                .sorted(by: { $0.key < $1.key }), id: \.key) { key, server in
                                ServerLink(key: key, server: server, isFavorite: true, toggleFavorite: toggleFavorite)
                            }
                        } header: {
                            Text("Favorites")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .textCase(nil)
                                .padding(.bottom, 4)
                        }
                    }
                    
                    ForEach(queueData.sorted(by: { $0.key < $1.key }), id: \.key) { key, servers in
                        Section {
                            ForEach(servers.sorted(by: { $0.key < $1.key }), id: \.key) { key, server in
                                if !favoriteServers.contains(key) {
                                    ServerLink(key: key, server: server, isFavorite: false, toggleFavorite: toggleFavorite)
                                }
                            }
                        } header: {
                            Text(key)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .textCase(nil)
                                .padding(.bottom, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationBarTitle("GFN Queue", displayMode: .inline)
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

    private func toggleFavorite(for serverKey: String) {
        if favoriteServers.contains(serverKey) {
            favoriteServers.remove(serverKey)
        } else {
            favoriteServers.insert(serverKey)
        }
        UserDefaults.standard.set(Array(favoriteServers), forKey: "favoriteServers")
    }
}

struct ServerLink: View {
    var key: String
    var server: ServerData
    var isFavorite: Bool
    var toggleFavorite: (String) -> Void

    var body: some View {
        NavigationLink(destination: GFNServerView(endpoint: "https://api.printedwaste.com", server: key)) {
            HStack(spacing: 12) {
                // Queue position badge
                Text("\(server.queuePosition)")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                server.queuePosition > 100 ? Color.red :
                                server.queuePosition > 50 ? Color(red: 0.85, green: 0.45, blue: 0) :
                                Color(red: 0.2, green: 0.5, blue: 0)
                            )
                    )
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(server.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        if isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(key)
                            .font(.system(size: 13))
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        Text(Date(timeIntervalSince1970: TimeInterval(server.lastUpdated)).toRelative(since: nil))
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .contextMenu {
            Button(action: {
                toggleFavorite(key)
            }) {
                Label(
                    isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: isFavorite ? "star.slash.fill" : "star.fill"
                )
            }
        }
    }
}

