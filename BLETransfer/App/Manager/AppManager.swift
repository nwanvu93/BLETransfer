//
//  AppManager.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//

import UIKit

/// Manages the UI and handles screen redirection within the app.
///
/// Provides a singleton instance accessed via `AppManager.shared`.
///
final class AppManager {
    
    /// - Returns: The singleton object fo this class.
    static let shared: AppManager = {
        return AppManager()
    }()
    
    private init() {}
    
    private func topWindow() -> UIWindow? {
        return (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window ?? nil
    }
    
    /// /// Redirect to the home screen based on the selected role
    func redirectToHome() {
        var targetVC: UIViewController?
        
        switch RoleManager.shared.selectedRole {
        case .server:
            targetVC = ServerHomeVC.loadNib()
        case .client:
            targetVC = ClientHomeVC.loadNib()
        default:
            return
        }
        
        if let vc = targetVC {
            let navigationController = UINavigationController()
            navigationController.viewControllers = [vc]
            topWindow()?.rootViewController = navigationController
            topWindow()?.makeKeyAndVisible()
        }
    }
}
