//
//  AppError.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 30/6/25.
//

enum AppError: Error {
    case invalidSignature
    case verifyFailed
    case authenticationFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidSignature:
            return "Invalid signature!";
        case .verifyFailed:
            return "Verify signature failed!";
        case .authenticationFailed:
            return "Authentication failed!"
        }
    }
}
