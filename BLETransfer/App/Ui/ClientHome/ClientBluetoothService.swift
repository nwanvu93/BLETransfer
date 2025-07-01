//
//  ClientBluetoothService.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 30/6/25.
//
import CoreBluetooth

/// Service that manages Bluetooth connection and authentication for the Central (Client) device
final class ClientBluetoothService: NSObject {
    
    private var viewModel: ClientHomeViewModel!
    private var centralManager: CBCentralManager!
    private var connectingPeripheral: CBPeripheral?
    private var write4KeyCharacteristic: CBCharacteristic?
    
    /// Communication state used to track the authentication process step by step
    private var _communicationStep = 1
    
    /// Attaches the ViewModel used to interact with the UI
    func attachViewModel(_ viewModel: ClientHomeViewModel) {
        self.viewModel = viewModel
    }
    
    /// Initialize the `CBCentralManager` to start scanning deivces
    func startScanning() {
        assert(viewModel != nil)
        _communicationStep = 1
        
        /// Updates the UI to reflect the scanning state
        viewModel.state.accept(.scanning)
        
        /// Init the service
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true as NSNumber]
        )
    }
    
    /// Stops the scanning service and clears the last connected peripheral
    func stop() {
        viewModel.state.accept(.idle)
        centralManager.stopScan()
        
        if connectingPeripheral != nil {
            centralManager.cancelPeripheralConnection(connectingPeripheral!)
            connectingPeripheral = nil
        }
    }
    
    /// Provides the client's `Public Key` for the server's challenge
    func sendClientKeyToServer() {
        guard let peripheral = connectingPeripheral,
              let characteristic = write4KeyCharacteristic,
              let message = getKeySendingMessage() else { return }
        
        _communicationStep += 1
        peripheral.writeValue(message, for: characteristic, type: .withoutResponse)
    }
    
    /// Sends the signed server nonce so the server can verify the client's identity
    /// - Parameter signedNonceMessage: The signature as `Data`
    private func sendSignedNonceToServer(_ signedNonceMessage: Data) {
        guard let peripheral = connectingPeripheral,
              let characteristic = write4KeyCharacteristic else { return }
        
        _communicationStep += 1
        peripheral.writeValue(signedNonceMessage, for: characteristic, type: .withoutResponse)
    }
    
    /// Sends a file to the server
    /// - Parameter fileData: The file as `Data`
    func sendFileToServer(_ fileData: Data) {
        guard let peripheral = connectingPeripheral,
              let characteristic = write4KeyCharacteristic else { return }
        
        /// Updates the UI to reflect the sending state
        viewModel.state.accept(.sending)
        
        _communicationStep += 1
        
        /// Negotiates with the peripheral to determine the maximum transferable size between two devices
        /// DLE is automatically enabled by iOS if the device supports it
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let chunkSize = mtu
        print("Max chunk size: \(chunkSize) bytes")
        
        /// Chunk the file data into packages with the maximum allowed size for sending
        var offset = 0
        while offset < fileData.count {
            let end = min(offset + chunkSize, fileData.count)
            let chunk = fileData.subdata(in: offset..<end)
            
            /// Call `writeValue` continuously, the `Core Bluetooth` will manage the queue for sending
            /// Use the `.withResponse` type to ensure data chunks are not lost during transmission
            peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
            offset = end
        }
        
        // Sending End Of File signal
//        peripheral.writeValue(
//            Constants.kEndOfFileFlag.data(using: String.Encoding.utf8)!,
//            for: characteristic,
//            type: .withoutResponse
//        )
    }
    
    /// Called when the server is discovered by its name.
    /// Stops scanning and initiates a connection to the server.
    /// - Parameter peripheral: The server discovered by name
    private func connectPeripheral(_ peripheral: CBPeripheral) {
        /// Stops scanning for nearby devices
        centralManager.stopScan()
        
        /// Keeps a local reference to the server for later actions
        connectingPeripheral = peripheral
        
        /// Perform connection to the server
        centralManager.connect(peripheral)
    }
    
    /// Prepares the message protocol for sending the random nonce
    /// - Returns: The message as `Data`
    ///
    private func getNonceMessage() -> Data? {
        let nonceMessage = Com_Cramium_Sdk_NonceRequest.with {
            $0.nonce = viewModel.getNonceForSigning()
        }
        
        return try? nonceMessage.serializedData()
    }
    
    /// Prepares the message protocol for sending the public key
    /// - Returns: The message as `Data`
    ///
    private func getKeySendingMessage() -> Data? {
        let keySendingMessage = Com_Cramium_Sdk_IdentityPublicKey.with {
            $0.pubkey = DataManager.shared.getPublicKey()?.toDer() ?? Data()
        }
        
        return try? keySendingMessage.serializedData()
    }
}

// MARK: - CBCentralManagerDelegate
extension ClientBluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            //TODO: Will handle in case Bluetooth not available or powered off
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        let serverInfo = viewModel.serverInfo
        
        print("\(peripheral.name ?? "Unknown"), \(peripheral.identifier), rssi: \(rssi)")
        if peripheral.name == serverInfo?.deviceName {
            connectPeripheral(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        /// Updates the UI to reflect the connected state
        viewModel.state.accept(.connected)
        
        peripheral.discoverServices(nil)
        peripheral.delegate = self
        
        
    }
}

// MARK: - CBPeripheralDelegate
extension ClientBluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            _ = services.map({ (service: CBService) in
                peripheral.discoverCharacteristics(nil, for: service)
            })
        } else if let error = error {
            print("Client error in didDiscoverServices Error:- \(error.localizedDescription)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        /// Updates the UI to reflect the authenticating state
        viewModel.state.accept(.authenticating)
        
        for characteristic in characteristics {
            
            print("characteristic: \(characteristic.uuid)")
            
            switch characteristic.uuid.uuidString {
            case Constants.write2ServerUUID:
                write4KeyCharacteristic = characteristic
                if let message = getNonceMessage() {
                    peripheral.writeValue(message, for: characteristic, type: .withoutResponse)
                }
                break
            case Constants.serverBroadcastUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if let data = characteristic.value {
            
            print("Client receive data: \(data)")
            
            if _communicationStep == 1, let signedNonceMessage = try? Com_Cramium_Sdk_SignedNonce(serializedBytes: data) {
                print("Client receive signed nonce signature")
                viewModel.verifyServerSignature(signedNonceMessage.signature)
                
            } else if _communicationStep == 2, let serverNonceMessage = try? Com_Cramium_Sdk_NonceRequest(serializedBytes: data) {
                print("Client receive server nonce")
                
                if let signedServerNonce = viewModel.signServerNonce(serverNonceMessage.nonce) {
                    sendSignedNonceToServer(signedServerNonce)
                }
            } else if _communicationStep == 3, let verifyResult = try? Com_Cramium_Sdk_SignatureVerificationResult(serializedBytes: data) {
                
                if verifyResult.valid {
                    viewModel.state.accept(.authenticated)
                } else {
                    /// Reset the UI with the `idle` state
                    viewModel.state.accept(.idle)
                    
                    /// Alert error to the user
                    viewModel.errorTracker.acceptError(AppError.authenticationFailed)
                }
                
            } else if _communicationStep >= 4 {
                /// Updates the UI to reflect that the file was successfully sent
                viewModel.state.accept(.sent)
            }
        }
    }
}
