//
//  ServerHomeViewModel.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 30/6/25.
//

import Foundation
import RxSwift
import RxCocoa
import starkbank_ecdsa

final class ServerHomeViewModel: BaseViewModel {
    private var nonceForSigning: Data?
    private var clientPubkey: PublicKey?
    
    var verifyStatus = BehaviorRelay<Bool>(value: false)
    var state = BehaviorRelay<AppState>(value: .idle)
    
    func getNonceForSigning() -> Data {
        let nonce = Helper.randomNonce() ?? Data()
        nonceForSigning = nonce
        return nonce
    }
    
    func setClientPubkey(_ pubkey: Data) {
        clientPubkey = try? PublicKey.fromDer(pubkey)
    }
    
    func verifyClientSignature(_ signature: Data) {
        if let snt = try? Signature.fromDer(signature),
           let publicKey = clientPubkey,
           let nonceString = nonceForSigning?.base64EncodedString(options: .lineLength64Characters) {
            // Verify algorithms
            let success = Ecdsa.verify(message: nonceString, signature: snt, publicKey: publicKey)
            verifyStatus.accept(success)
            nonceForSigning = nil
            
            if !success {
                state.accept(.idle)
                errorTracker.acceptError(AppError.invalidSignature)
            }
            
            return
        }
        
        state.accept(.idle)
        errorTracker.acceptError(AppError.verifyFailed)
    }
}
