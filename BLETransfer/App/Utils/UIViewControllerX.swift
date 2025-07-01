//
//  UIViewControllerX.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//
import UIKit

public extension UIViewController {
    static func loadNib() -> Self {
        func instantiateFromNib<T: UIViewController>() -> T {
            return T.init(nibName: String(describing: T.self), bundle: nil)
        }
        return instantiateFromNib()
    }
}
