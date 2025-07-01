//
//  DataManager.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//

import Foundation
import starkbank_ecdsa
import Security

final class DataManager {
   
    /// - Returns: The singleton object fo this class.
    static let shared: DataManager = {
        return DataManager()
    }()
    
    
    private let _keyServerName = "server.name"
    private let _privateKeyTag = "privateKeyTag"
    private let userDefaults = UserDefaults.standard
    private var privateKey: PrivateKey?
    
    private init() {}
    
    /// Attempts to retrieve the most recently generated key.
    /// If none exists, a new one is generated.
    ///
    func initData() {
        if (privateKey != nil) {
            return
        }
        
        /// Reads the last stored key from the Keychain.
        if let keyData = readPrivateKeyFromKeychain(), let key = try? PrivateKey.fromDer(keyData) {
            /// The last key was successfully restored.
            privateKey = key
            
            let publicKey = privateKey!.publicKey()
            print("The key was restored:\n\(publicKey.toPem())")
            return
        }
        
        /// Generates a new private key.
        let privateKey = PrivateKey(curve: prime256v1 /* Also known as secp256r1 */)
        
        /// Convert the PrivateKey object to Data object
        let keyData = privateKey.toDer()
        
        /// Calculates the size of the data in bits.
        let bitsOfData = (keyData.count * 8) as CFNumber
        
        /// Prepares the query used to save the key to the Keychain.
        let query = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: _privateKeyTag.data(using: .utf8)! as CFData,
            kSecAttrKeySizeInBits: bitsOfData,
            kSecValueData: keyData,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecReturnData: true as CFBoolean
        ] as CFDictionary
        /// Saves the key to the Keychain.
        let status = SecItemAdd(query, nil)
        
        switch status {
        case errSecSuccess:
            print("The key was saved successfully.")
        default:
            print("Err status: \(status)")
        }
    }
    
    /// Reads the most recently generated private key from the Keychain,
    /// identified by `_privateKeyTag`.
    ///
    /// - Returns: The `Data` representation of the private key.
    private func readPrivateKeyFromKeychain() -> Data? {
        let query = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: _privateKeyTag.data(using: .utf8)! as CFData,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            return item as? Data
        } else {
            print("Keychain read failed with status: \(status)")
            return nil
        }
    }
    
    /// Saves the server name to UserDefaults.
    ///
    /// - Parameter name: The server name entered by the user.
    ///
    func saveServerName(_ name: String) {
        userDefaults.set(name, forKey: _keyServerName)
    }
    
    /// Retrieves the server name from UserDefaults.
    ///
    /// - Returns: The last saved server name.
    func getServerName() -> String? {
        return userDefaults.string(forKey: _keyServerName)
    }
    
    /// Returns the public key generated from the private key.
    /// - Returns: The public key object.
    func getPublicKey() -> PublicKey? {
        guard let publicKey = privateKey?.publicKey() else { return nil }
        return publicKey
    }
    
    /// Prepares the server info for QR code display.
    /// - Returns: The JSON representation of the server info as a `String`.
    func prepareServerInfo() -> String {
        let serverName = getServerName() ?? ""
        let encodedPublicKey = getPublicKey()?.toPem() ?? ""
        
        let info = ServerInfo(
            identityPublicKey: encodedPublicKey,
            deviceId: Helper.getDeviceId(),
            deviceName: serverName,
            ownerUser: "vu.nguyenquang20@gmail.com",
            firmwareVersion: "1.0.3",
            timestamp: UInt32(Date().timeIntervalSince1970)
        )
        
        let json = try! JSONEncoder().encode(info)
        return String(data: json, encoding: .utf8)!
    }
    
    /// Signs the nonce using the private key.
    /// - Parameter nonce: The nonce as `Data`
    /// - Returns: The signature as `Data`
    func signNonce(_ nonce: Data) -> Data {
        let nonceString = nonce.base64EncodedString(options: .lineLength64Characters)
        let signature = Ecdsa.sign(message: nonceString, privateKey: privateKey!)
        return signature.toDer()
    }
}
