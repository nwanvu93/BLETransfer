//
//  Helper.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//

import UIKit

final class Helper {
    private init() {}
    
    static func generateQRCode(from string: String, size: CGSize) -> UIImage? {
        let data = string.data(using: .utf8)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            // Set the error correction level (L: 7%, M: 15%, Q: 25%, H: 30%)
            filter.setValue("M", forKey: "inputCorrectionLevel")

            if let qrImage = filter.outputImage {
                let scaleX = size.width / qrImage.extent.size.width
                let scaleY = size.height / qrImage.extent.size.height
                let transformedImage = qrImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                return UIImage(ciImage: transformedImage)
            }
        }
        return nil
    }
    
    static func getDeviceId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? ""
    }
    
    static func randomNonce(lenght: Int = 32) -> Data? {
        let nonce = NSMutableData(length: lenght)
        let result = SecRandomCopyBytes(kSecRandomDefault, nonce!.length, nonce!.mutableBytes)
        if result == errSecSuccess {
            return nonce! as Data
        } else {
            return nil
        }
    }
}
