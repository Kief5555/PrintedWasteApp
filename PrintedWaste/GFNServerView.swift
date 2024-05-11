//
//  GFNServerView.swift
//  PrintedWaste
//
//  Created by Kiefer Lin on 2024-05-10.
//

import Foundation
import SwiftUI

struct GFNServerView: View {
    var serverName: String
    @State private var queueData: [String: QueueData] = [:]
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("LOADING...")
            } else {
                Text("Hello")
            }
        }
    }
}
