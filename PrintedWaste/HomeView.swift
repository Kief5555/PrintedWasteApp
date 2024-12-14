//
//  HomeView.swift
//  PrintedWaste
//
//  Created by Kiefer Lin on 2024-05-08.
//

import SwiftUI


struct StackImageStyling: ViewModifier {
    func body(content: Content) -> some View {
        content.frame(width: 30, height: 30)
            .foregroundColor(.white)
            .padding(3.0)
            .background(Color(UIColor.systemBlue))
            .cornerRadius(8) // Rounded corners
            .padding(.trailing, 8)
    }
}

extension View {
    func applyStackImageStyling() -> some View {
        self.modifier(StackImageStyling())
    }
}



struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var isDarkMode: Bool {
          colorScheme == .dark
    }
    
    var body: some View {
            List {
                NavigationLink(destination: GFNView()) {
                    HStack {
                        Image(systemName: "person.badge.clock")
                            .applyStackImageStyling()
                        Text("GFN Queue")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                }
                .padding(0.1)
                //.listRowBackground(Color(isDarkMode ? UIColor.systemGray6 : UIColor.white).opacity(0.8))
                Button(action: {
                    if let url = URL(string: "https://printedwaste.com/contact") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .applyStackImageStyling()
                        Text("Support")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .padding(0.1)
                //.listRowBackground(Color(isDarkMode ? UIColor.systemGray6 : UIColor.white).opacity(0.8))
            }
            .navigationBarTitle("Home")
    }
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
