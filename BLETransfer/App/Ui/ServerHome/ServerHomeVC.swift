//
//  ServerHomeVC.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//

import CoreBluetooth
import UIKit
import RxSwift
import QuickLook

class ServerHomeVC: UIViewController {

    @IBOutlet weak var inputName: UITextField!
    @IBOutlet weak var inputRoot: UIView!
    
    @IBOutlet weak var handshakeRoot: UIView!
    @IBOutlet weak var lbServerName: UILabel!
    @IBOutlet weak var imServerInfo: UIImageView!
    @IBOutlet weak var lbMessage: UILabel!
    
    private let viewModel = ServerHomeViewModel()
    private let disposeBag = DisposeBag()
    
    private var peripheralManager: CBPeripheralManager!
    private var service: CBUUID!
    
    /// Characteristic used to receive data written by the client
    private let _client2ServerChar = CBMutableCharacteristic(
        type: CBUUID(string: Constants.write2ServerUUID),
        properties: [.write, .writeWithoutResponse],
        value: nil,
        permissions: [.writeable]
    )

    /// Characteristic used to send notifications to the client
    private let _server2ClientChar = CBMutableCharacteristic(
        type: CBUUID(string: Constants.serverBroadcastUUID),
        properties: [.notify],
        value: nil,
        permissions: [.readable, .writeable]
    )
    
    /// Communication state used to track the authentication process step by step
    private var _communicationStep = 1
    
    /// Placeholder data object to receive a file from the client
    private var receivedData = Data()
    
    /// A flag used to check if the current chunk is the last part of the file.
    /// This replaces the need for `Constants.kEndOfFileFlag`, saving one final write action from the client.
    /// Ends the file transfer and handles completion earlier.
    private var chunkSize = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Server"
        
        updateUI()
        initViewModel()
    }
    
    private func updateUI() {
        let serverName = DataManager.shared.getServerName()
        if let name = serverName, name.count > 0 {
            inputRoot.isHidden = true
            handshakeRoot.isHidden = false
            lbServerName.text = "Server Name: \(name)"
            lbMessage.text = "Scan the QR code to connect"
            prepareAndDisplayServerInfo()
        } else {
            inputRoot.isHidden = false
            handshakeRoot.isHidden = true
        }
    }
    
    /// Prepares server info as JSON and generates a QR code for it
    private func prepareAndDisplayServerInfo() {
        let imageSize = CGSize(width: 200, height: 200)
        DispatchQueue.global(qos: .userInteractive).async {
            let serverInfo = DataManager.shared.prepareServerInfo()
            print(serverInfo)
            
            guard let image = Helper.generateQRCode(from: serverInfo, size: imageSize) else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.imServerInfo.image = image
                self?.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
            }
        }
    }
    
    private func initViewModel() {
        viewModel.verifyStatus
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] status in
                print("Server verify client status: \(status)")
                if status {
                    self?.notifyClientSuccessResult()
                }
            })
            .disposed(by: disposeBag)
        
        viewModel.state
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] status in
                guard let sSelf = self else { return }
                
                switch status {
                case .idle:
                    sSelf.peripheralManager?.stopAdvertising()
                    sSelf.updateUI()
                default:
                    sSelf.inputRoot.isHidden = true
                    sSelf.handshakeRoot.isHidden = false
                    sSelf.lbMessage.text = status.message
                }
                
            })
            .disposed(by: disposeBag)
        
        viewModel.errorMessage
            .asObservable()
            .subscribe(onNext: { [weak self] error in
                guard let sSelf = self else { return }
                let alert = UIAlertController(
                    title: "Error",
                    message: (error as? AppError)?.localizedDescription ?? error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                sSelf.present(alert, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }

    @IBAction func touchedSave(_ sender: Any) {
        let serverName = inputName.text ?? ""
        if serverName.count == 0 {
            let alert = UIAlertController(
                title: "Error",
                message: "Server name cannot be empty.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        inputName.resignFirstResponder()
        
        DataManager.shared.saveServerName(serverName)
        updateUI()
    }
    
    // MARK: Bluetooth Peripheral Setup
    func createServices() {
        
        /// Ramdom ID for the service
        service = CBUUID(nsuuid: UUID())
        
        let myService = CBMutableService(type: service, primary: true)
        myService.characteristics = [_client2ServerChar, _server2ClientChar]
        peripheralManager.add(myService)
        
        /// Start advertising
        startAdvertising()
    }
    
    /// Starts broadcasting the server signal using the server name as the device name
    func startAdvertising() {
        _communicationStep = 1
        let serverName = DataManager.shared.getServerName()!
        peripheralManager.startAdvertising(
            [
                CBAdvertisementDataLocalNameKey: serverName,
                CBAdvertisementDataServiceUUIDsKey: [service]
            ]
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if service != nil {
            startAdvertising()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        peripheralManager.stopAdvertising()
        print("Stop Advertising")
    }
    
    /// Sign the nonce from client
    private func signClientNonce(_ value: Data) -> Data? {
        let signatureData = DataManager.shared.signNonce(value)
        let signedNonceMessage = Com_Cramium_Sdk_SignedNonce.with {
            $0.signature = signatureData
        }
        
        return try? signedNonceMessage.serializedData()
    }
    
    /// Prepare the nonce request message
    private func getNonceMessage() -> Data? {
        let nonceMessage = Com_Cramium_Sdk_NonceRequest.with {
            $0.nonce = viewModel.getNonceForSigning()
        }
        
        return try? nonceMessage.serializedData()
    }
    
    /// Prepare the verification message
    private func getVerifySuccessMessage() -> Data? {
        let verifyMessage = Com_Cramium_Sdk_SignatureVerificationResult.with {
            $0.valid = true
        }
        
        return try? verifyMessage.serializedData()
    }
    
    /// Notifies the client that the verification was successful
    private func notifyClientSuccessResult() {
        guard let message = getVerifySuccessMessage() else { return }
        _communicationStep += 1
        peripheralManager.updateValue(message, for: _server2ClientChar, onSubscribedCentrals: nil)
        viewModel.state.accept(.authenticated)
    }
    
    /// Handles file transfer completion and notifies the client
    private func handleCompleteFile() {
        if let image = UIImage(data: receivedData) {
            imServerInfo.image = image
        }
        peripheralManager.updateValue(Data(), for: _server2ClientChar, onSubscribedCentrals: nil)
        viewModel.state.accept(.sent)
        chunkSize = -1
    }
}

// MARK: - CBPeripheralManagerDelegate
extension ServerHomeVC: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .unknown:
            print("Bluetooth Device is UNKNOWN")
        case .unsupported:
            print("Bluetooth Device is UNSUPPORTED")
        case .unauthorized:
            print("Bluetooth Device is UNAUTHORIZED")
        case .resetting:
            print("Bluetooth Device is RESETTING")
        case .poweredOff:
            print("Bluetooth Device is POWERED OFF")
            peripheralManager.stopAdvertising()
        case .poweredOn:
            print("Bluetooth Device is POWERED ON")
            if service != nil {
                startAdvertising()
            } else {
                createServices()
            }
        @unknown default:
            print("Unknown State")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        print("Server started advertising")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let value = request.value {
                
                if _communicationStep == 1, let nonceMessage = try? Com_Cramium_Sdk_NonceRequest(serializedBytes: value) {
                    print("Server receive client nonce")
                    
                    if let signedNonceMessage = signClientNonce(nonceMessage.nonce) {
                        _communicationStep += 1
                        peripheralManager.updateValue(signedNonceMessage, for: _server2ClientChar, onSubscribedCentrals: nil)
                    }
                    
                } else if _communicationStep == 2, let keyMessage = try? Com_Cramium_Sdk_IdentityPublicKey(serializedBytes: value) {
                    print("Server receive client pubkey")
                    
                    viewModel.setClientPubkey(keyMessage.pubkey)
                    if let message = getNonceMessage() {
                        _communicationStep += 1
                        peripheralManager.updateValue(message, for: _server2ClientChar, onSubscribedCentrals: nil)
                    }
                    
                } else if _communicationStep == 3, let signedNonceMessage = try? Com_Cramium_Sdk_SignedNonce(serializedBytes: value) {
                    print("Server receive signed nonce signature")
                    
                    // verify signed nonce by client pubKey
                    viewModel.verifyClientSignature(signedNonceMessage.signature)
                    
                } else if _communicationStep == 4 {
                    // receive file
                    viewModel.state.accept(.receiving)
                    
                    print("Server receive chunk: \(value)")
                    
                    // Clear the last file data if it exist
                    if chunkSize < 0 {
                        receivedData.removeAll()
                    }
                    
                    // Append new chunk of data
                    receivedData.append(value)
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if self.viewModel.state.value == .receiving {
                            self.lbMessage.text = "\(AppState.receiving.message) \(self.receivedData.count) bytes"
                        }
                    }
                    
                    /// Responds to the client to confirm the server has successfully received the data
                    peripheralManager.respond(to: request, withResult: .success)
                    
                    /// Ends the file transfer if this chunk is the `EOF` flag
                    if let str = String(data: value, encoding: .utf8), str == Constants.kEndOfFileFlag {
                        print("Server receive file done: \(Date())")
                        handleCompleteFile()
                        return
                    }
                    
                    /// Ends the file transfer if this chunk is smaller than the previous one
                    if chunkSize > 0 && value.count < chunkSize {
                        print("Server receive file done by check chunk size \(Date())")
                        handleCompleteFile()
                        return
                    }
                    
                    /// Keep last chunk size
                    chunkSize = value.count
                }
                return
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        viewModel.state.accept(.authenticating)
    }
}
