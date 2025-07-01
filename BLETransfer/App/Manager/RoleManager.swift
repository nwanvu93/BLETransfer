//
//  RoleManager.swift
//  BLETransfer
//
//  Created by Vũ Nguyễn on 27/6/25.
//


/// Keeps track of the role selected by the user
///
/// Provides a singleton instance accessed via `RoleManager.shared`.
///
final class RoleManager {
    
    /// - Returns: The singleton object fo this class.
    static let shared: RoleManager = {
        return RoleManager()
    }()
    
    private(set) var selectedRole: RoleType?
    
    private init() {}
    
    /// Called when the user interacts with the UI
    ///
    /// - Parameters:
    ///   - role: The `RoleType` object
    func selectRole(role: RoleType) {
        self.selectedRole = role
    }
}
