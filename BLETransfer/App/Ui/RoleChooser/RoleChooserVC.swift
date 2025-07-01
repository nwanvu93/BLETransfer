//
//  RoleChooserVC.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//

import UIKit

class RoleChooserVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check if a role has already been selected, redirect to the home screen immediately
        if RoleManager.shared.selectedRole != nil {
            AppManager.shared.redirectToHome()
        }
    }

    @IBAction func touchedServerRole(_ sender: Any) {
        // Save the role selected by the user
        RoleManager.shared.selectRole(role: .server)
        
        // Redirect to the home screen
        AppManager.shared.redirectToHome()
    }
    
    @IBAction func touchedClientRole(_ sender: Any) {
        // Save the role selected by the user
        RoleManager.shared.selectRole(role: .client)
        
        // Redirect to the home screen
        AppManager.shared.redirectToHome()
    }
}
