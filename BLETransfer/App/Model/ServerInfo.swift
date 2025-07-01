//
//  ServerInfo.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//

struct ServerInfo: Encodable, Decodable {
    var identityPublicKey: String
    var deviceId: String
    var deviceName: String
    var ownerUser: String
    var firmwareVersion: String
    var timestamp: UInt32
}
