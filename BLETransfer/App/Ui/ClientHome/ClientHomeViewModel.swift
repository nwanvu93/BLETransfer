//
//  ClientHomeViewModel.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//
import Foundation
import RxSwift
import RxCocoa
import starkbank_ecdsa

final class ClientHomeViewModel: BaseViewModel {
    
    var serverInfo: ServerInfo?
    private var nonceForSigning: Data?
    
    var verifyStatus = BehaviorRelay<Bool>(value: false)
    var state = BehaviorRelay<AppState>(value: .idle)
    
    func getNonceForSigning() -> Data {
        let nonce = Helper.randomNonce() ?? Data()
        nonceForSigning = nonce
        return nonce
    }
    
    func verifyServerSignature(_ signature: Data) {
        if let snt = try? Signature.fromDer(signature),
           let keyInString = serverInfo?.identityPublicKey,
           let publicKey = try? PublicKey.fromPem(keyInString),
           let nonceString = nonceForSigning?.base64EncodedString(options: .lineLength64Characters) {
            
            // Verify algorithms
            let success = Ecdsa.verify(message: nonceString, signature: snt, publicKey: publicKey)
            verifyStatus.accept(success)
            nonceForSigning = nil
            
            if !success {
                errorTracker.acceptError(AppError.invalidSignature)
            }
            
            return
        }
        
        errorTracker.acceptError(AppError.verifyFailed)
    }
    
    func signServerNonce(_ serverNonce: Data) -> Data? {
        let signatureData = DataManager.shared.signNonce(serverNonce)
        let signedNonceMessage = Com_Cramium_Sdk_SignedNonce.with {
            $0.signature = signatureData
        }
        
        return try? signedNonceMessage.serializedData()
    }
}
