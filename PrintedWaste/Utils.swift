//
//  Utils.swift
//  PrintedWaste
//
//  Created by Kiefer Lin on 2024-05-09.
//

import Foundation
enum TimeFormat {
    case timeUntil
    case fullDate
    case halfDate
}

func convertUnixTimestamp(_ timestamp: TimeInterval, format: TimeFormat) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let now = Date()
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
    
    switch format {
    case .timeUntil:
        if let year = components.year, year > 0 {
            return "\(year)y ago"
        } else if let month = components.month, month > 0 {
            return "\(month)m ago"
        } else if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "just now"
        }
    case .fullDate:
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    case .halfDate:
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: date)
    }
}
