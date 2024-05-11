//
//  ContentView.swift
//  PrintedWaste
//
//  Created by Kiefer Lin on 2024-05-05.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            TabView {
                // First Tab
                NavigationView {
                    HomeView()
                        .navigationBarTitle("Home")
                }
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                
                // Second Tab
                Text("Second Tab Content")
                    .tabItem {
                        Image(systemName: "2.circle")
                        Text("Second")
                    }
                
                // Third Tab
                SettingsView()
                    .tabItem {
                        Image(systemName: "person")
                        Text("Profile")
                    }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
