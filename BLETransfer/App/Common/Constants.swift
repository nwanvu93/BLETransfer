//
//  Constants.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 30/6/25.
//

struct Constants {
    
    /// Specific ID for the characteristic used to send data from central to peripheral
    static let write2ServerUUID = "D980088D-D2E2-44B3-8716-BD7CAF1CB340"
    
    /// Specific ID for the characteristic used to notify signal from peripheral to central
    static let serverBroadcastUUID = "A3A80BD0-DCC1-4384-ABAF-F99C525D3E4B"
    
    /// The flag that marks the end of file transmission
    static let kEndOfFileFlag = "EOF"
}
