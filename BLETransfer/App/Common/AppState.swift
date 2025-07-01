//
//  AppState.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 1/7/25.
//

enum AppState: String {
    case idle
    case scanning
    case connected
    case authenticating
    case authenticated
    case sending
    case receiving
    case sent
    
    var message: String {
        switch self {
        case .idle:
            return "Idle"
        case .scanning:
            return "Scanning..."
        case .connected:
            return "Connected"
        case .authenticating:
            return "Authenticating..."
        case .authenticated:
            return "Authenticated"
        case .sending:
            return "Sending..."
        case .receiving:
            return "Receiving..."
        case .sent:
            return "Sent"
        }
    }
}
