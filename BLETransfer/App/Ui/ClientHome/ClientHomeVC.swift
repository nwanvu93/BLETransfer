//
//  ClientHomeVC.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//

import AVFoundation
import RxSwift
import UIKit

class ClientHomeVC: UIViewController {
    @IBOutlet weak var scanRoot: UIStackView!
    @IBOutlet weak var scanView: UIView!
    
    @IBOutlet weak var loadingRoot: UIView!
    @IBOutlet weak var loadingMessage: UILabel!
    @IBOutlet weak var btnSend: UIButton!
    
    private let bluetoothService = ClientBluetoothService()
    private let viewModel = ClientHomeViewModel()
    private let disposeBag = DisposeBag()
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Client"
        
        initViewModel()
        setupCameraForScan()
        
    }
    
    private func initViewModel() {
        viewModel.verifyStatus
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] status in
                guard let sSelf = self else { return }
                print("Client verify server status: \(status)")
                if status {
                    sSelf.bluetoothService.sendClientKeyToServer()
                }
            })
            .disposed(by: disposeBag)
        
        viewModel.state
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] status in
                guard let sSelf = self else { return }
                
                switch status {
                case .idle:
                    sSelf.setupCameraForScan()
                case .authenticated, .sent:
                    sSelf.loadingRoot.isHidden = true
                    sSelf.btnSend.isHidden = false
                default:
                    sSelf.scanRoot.isHidden = true
                    sSelf.loadingRoot.isHidden = false
                    sSelf.loadingMessage.text = status.message
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
        
        // Attach viewModel to the ClientBluetoothService
        bluetoothService.attachViewModel(viewModel)
    }
    
    override func viewWillAppear(_ animated: Bool) {
       super.viewWillAppear(animated)

       if (captureSession?.isRunning == false) {
           DispatchQueue.global(qos: .userInteractive).async { [weak self] in
               self?.captureSession.startRunning()
           }
       }
   }

   override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)

       stopScanning()
       
       bluetoothService.stop()
   }


    private func setupCameraForScan() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            setupFailed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            setupFailed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = scanView.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        scanView.layer.addSublayer(previewLayer)
        
        scanRoot.isHidden = false
        
        loadingRoot.isHidden = true
        btnSend.isHidden = true

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopScanning() {
        if (captureSession?.isRunning == true) {
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.captureSession.stopRunning()
                self?.captureSession = nil
            }
        }
        
        for layer in (scanView.layer.sublayers ?? []) {
            layer.removeFromSuperlayer()
        }
        
        previewLayer = nil
    }
    
    func onScanned(code: String) {
        if let serverInfo = try? JSONDecoder().decode(ServerInfo.self, from: code.data(using: .utf8)!) {
            viewModel.serverInfo = serverInfo
            
            print("Client is looking up server \(serverInfo.deviceName)")
            
            bluetoothService.startScanning()
        }
    }
    
    func setupFailed() {
        let ac = UIAlertController(
            title: "Setup camera failed",
            message: "Your device does not support for scanning",
            preferredStyle: .alert
        )
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    @IBAction func touchedSend(_ sender: Any) {
        let vc = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .jpeg, .png],
            asCopy: true
        )
        vc.allowsMultipleSelection = false
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
}

extension ClientHomeVC: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        stopScanning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onScanned(code: stringValue)
        }
    }
}

extension ClientHomeVC : UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
        bluetoothService.sendFileToServer(data)
    }
}
