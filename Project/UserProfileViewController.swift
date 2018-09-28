//
//  UserProfileViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import UIKit
import Firebase
import IQKeyboardManagerSwift
import Eureka
import SCLAlertView
import ImageRow
import Reachability
import SwiftLocation

class UserProfileViewController: FormViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Firebase
    let storageRef = Storage.storage().reference()
    let databaseRef = Database.database().reference()
    let profilePictureID = NSUUID().uuidString
    let userID = Auth.auth().currentUser?.uid
    let user = Auth.auth().currentUser
    
    // Variables
    var displayNameExists = false
    var reAuthOccurred = false
    var errorOccurred = false
    var emailChangeError = ""
    var signingUp = false
    var currentUserDisplayName = ""
    var currentUserFullName = ""
    
    // Shared custom colors
    let greyColor = Shared.shared.greyColor
    let pinkColor = Shared.shared.pinkColor
    let lightPinkColor = Shared.shared.lightPinkColor
    
    // UI Variables
    @IBOutlet weak var saveBarButton: UIBarButtonItem!
    
    let reachability = Reachability()! // Allows internet connection to be checked
    
    @IBAction func save(_ sender: Any) {
        self.tableView.reloadData()
        
        // Resets variable values
        displayNameExists = false
        reAuthOccurred = false
        errorOccurred = false
        emailChangeError = ""
        
        getCurrentUserNames() // Gets the names of current user
        
        // Gets values from the form
        let displayName: AccountRow? = form.rowBy(tag: "DisplayNameTag")
        let displayNameValue = displayName?.value
        let fullName: NameRow? = form.rowBy(tag: "FullNameTag")
        let fullNameValue = fullName?.value
        let email: EmailRow? = form.rowBy(tag: "EmailTag")
        let emailValue = email?.value
        let newPassword: PasswordRow? = form.rowBy(tag: "NewPasswordTag")
        let newPasswordValue = newPassword?.value
        let confirmPassword: PasswordRow? = form.rowBy(tag: "ConfirmPasswordTag")
        let confirmPasswordValue = confirmPassword?.value
        let brainInjury: PickerInlineRow<String>? = form.rowBy(tag: "BrainInjuryTag")
        let brainInjuryValue = brainInjury?.value
        let emergencyRelation: PickerInlineRow<String>? = form.rowBy(tag: "ECRelationTag")
        let emergencyRelationValue = emergencyRelation?.value
        let emergencyFullName: NameRow? = form.rowBy(tag: "ECFullNameTag")
        let emergencyFullNameValue = emergencyFullName?.value
        let emergencyContactNumber: PhoneRow? = form.rowBy(tag: "ECNumberTag")
        let emergencyContactNumberValue = emergencyContactNumber?.value
        let profilePicture: ImageRow? = form.rowBy(tag: "ProfilePictureTag")
        let profilePictureValue = profilePicture?.value
        
        // Firebase
        let usersRef = databaseRef.child("Users")
        
        // If user is not connected to the internet then error
        if reachability.connection == .none {
            SCLAlertView().showError("Error", subTitle: "An internet connection is required for saving the profile. Connect to the internet and try again.")
        }
            
            // If compulsory fields left blank then error
        else if displayNameValue == nil || displayNameValue == "" ||
            fullNameValue == nil || fullNameValue == "" ||
            brainInjuryValue == nil || brainInjuryValue == ""
        {
            handlePreSaveError(errorMessage: "All fields within the User Profile section (except the Profile Picture field) must contain a value before saving the profile.")
        }
        else if emailValue == nil || emailValue == "" {
            handlePreSaveError(errorMessage: "The email field must contain a value before saving the profile.")
        }
        else if brainInjuryValue != "None" && (emergencyRelationValue == nil || emergencyRelationValue == "" || emergencyFullNameValue == nil || emergencyFullNameValue == "" || emergencyContactNumberValue == nil || emergencyContactNumberValue == "") {
            handlePreSaveError(errorMessage: "Due to a TBI/ABI being selected within the Brain Injury field, all fields within the Emergency Contact section must contain a value before saving the profile.")
        }
        else if newPasswordValue != confirmPasswordValue {
            handlePreSaveError(errorMessage: "The new password does not match the confirmation password. These fields must match before saving the profile.")
        }
        else {
            
            // Characters which are allowed to be used in a display name
            let characterset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_. ")
            
            // Checks if Display Name is too long (not counting spaces as they will be removed anyway)
            if (displayNameValue!.replacingOccurrences(of: " ", with: "").count > 24) {
                self.handlePreSaveError(errorMessage: "Display Name is too long, shorten it to 24 characters or less before saving the profile.")
            }
                
                // If display name contains special characters (not in character set)
            else if displayNameValue!.rangeOfCharacter(from: characterset.inverted) != nil {
                self.handlePreSaveError(errorMessage: "Display Name contains forbidden (special) characters, remove these before saving the profile. \n\nCharacters that may be used: abcdefghijklmnopqrstuvwxyz0123456789_.")
            }
                
            else {
                
                //Checks Display Name availability
                usersRef.observeSingleEvent(of: .value, with: { (snapshot) in
                    for snap in snapshot.children {
                        let userSnap = snap as! DataSnapshot
                        if let userDict = userSnap.value as? [String:AnyObject] { // The child data of each user
                            let userDisplayName = userDict["Display Name"] as? String // Gets Display Name of each user
                            
                            if displayNameValue == userDisplayName && self.currentUserDisplayName != userDisplayName {
                                self.displayNameExists = true
                            }
                        }
                    }
                    
                    // Display error message if Display Name is already taken.
                    if self.displayNameExists == true {
                        self.handlePreSaveError(errorMessage: "Display Name is already in use by another account, it must be unique before saving the profile.")
                    }
                    else {
                        self.saveProfile(displayNameValue: displayNameValue, fullNameValue: fullNameValue, brainInjuryValue: brainInjuryValue, emergencyRelationValue: emergencyRelationValue, emergencyFullNameValue: emergencyFullNameValue, emergencyContactNumberValue: emergencyContactNumberValue) // Updates Display Name, Full Name
                        self.saveProfilePicture(profilePicture: profilePicture, profilePictureValue: profilePictureValue) // Updates the Profile Picture
                        self.saveSensitiveData(emailValue: emailValue, newPasswordValue: newPasswordValue, confirmPasswordValue: confirmPasswordValue) // Updates Email and Password
                        
                    }
                    
                    // If no error/reauth alerts then success!
                    if self.errorOccurred == false  && self.reAuthOccurred == false {
                        
                        if self.signingUp == true { // If user is competing signup
                            self.performSegue(withIdentifier: "completedSignupSegue", sender: self) // Directs user to Home page
                            if brainInjuryValue != "None" {  // If the user has stated that they have a brain injury
                                
                                // Requests location services to allow SOS messages to be sent to emergency contact with location (if not already done)
                                Locator.requestAuthorizationIfNeeded()
                            }
                        }
                        else {
                            let appearance = SCLAlertView.SCLAppearance(
                                showCloseButton: false
                            )
                            let alertView = SCLAlertView(appearance: appearance)
                            alertView.addButton("Done") {
                                if brainInjuryValue != "None" {  // If the user has stated that they have a brain injury
                                    
                                    // Requests location services to allow SOS messages to be sent to emergency contact with location (if not already done)
                                    Locator.requestAuthorizationIfNeeded()
                                }
                            }
                            alertView.showSuccess("Success!", subTitle: "Profile updated successfully.")
                        }
                    }
                })
            }
        }
    }
    
    func handlePreSaveError(errorMessage: String) {
        
        // Handles any pre-save errors that may occur
        SCLAlertView().showError("Not Saved", subTitle: errorMessage)
        errorOccurred = true
    }
    
    
    func handlePostSaveError(errorMessage: String) {
        
        // Handles any post-save errors that may occur
        SCLAlertView().showError("Partially Saved", subTitle: errorMessage)
        errorOccurred = true
        
        // Reloads form to show the user what has been saved and what hasn't
        self.loadFormData()
        self.form.setValues(["NewPasswordTag": nil, "ConfirmPasswordTag": nil])
        self.tableView.reloadData()
    }
    
    func getCurrentUserNames() {
        
        // Checks current user's current Display Name
        databaseRef.child("Users").child(userID!).observeSingleEvent(of: .value, with: {
            (snapshot) in
            if let currentUserDict = snapshot.value as? [String: AnyObject]
            {
                self.currentUserDisplayName = currentUserDict["Display Name"] as! String // Gets Display Name of current user
                self.currentUserFullName = currentUserDict["Full Name"] as! String // Gets Full Name of current user
            }
        })
    }
    
    func saveProfile(displayNameValue: String?, fullNameValue: String?, brainInjuryValue: String?, emergencyRelationValue: String?, emergencyFullNameValue: String?, emergencyContactNumberValue: String?) {
        
        // Saves the profile
        var userProfile = [String: Any]()
        
        // If user does not have a brain injury
        if brainInjuryValue == "None" {
            
            // Update Firebase by deleting any data which contradict brainInjuryValue = None
            self.databaseRef.child("Users").child(self.userID!).child("EC Relation").removeValue()
            self.databaseRef.child("Users").child(self.userID!).child("EC Full Name").removeValue()
            self.databaseRef.child("Users").child(self.userID!).child("EC Number").removeValue()
            
            // Creates dictionary of form values (and also makes display name lowercased and removes spaces)
            userProfile = ["Display Name": displayNameValue!.lowercased().replacingOccurrences(of: " ", with: ""),
                           "Full Name": fullNameValue!, "Brain Injury": brainInjuryValue!]
        }
            
        else { // Save emergency contact details
            userProfile = ["Display Name": displayNameValue!.lowercased().replacingOccurrences(of: " ", with: ""),
                           "Full Name": fullNameValue!, "Brain Injury": brainInjuryValue!, "EC Relation": emergencyRelationValue!,
                           "EC Full Name": emergencyFullNameValue!, "EC Number": emergencyContactNumberValue!]
        }
        
        // Updates Display Name, Full Name
        self.databaseRef.child("Users").child(self.userID!).updateChildValues(userProfile, withCompletionBlock: { (error, ref) in
            if error != nil {
                self.handlePostSaveError(errorMessage: "Display Name, Full Name and/or Brain Injury could not be updated. " + (error?.localizedDescription)!)
            }
        })
    }
    
    func saveProfilePicture(profilePicture: ImageRow?, profilePictureValue: UIImage?) {
        let storedProfilePicture = storageRef.child("profile_pictures").child(profilePictureID)
        
        // Updates profile picture in Firebase
        if profilePictureValue != nil {
            if profilePicture?.wasChanged == true { // Only updates if profile picture was changed
                if let uploadData = UIImagePNGRepresentation(profilePictureValue!) {
                    storedProfilePicture.putData(uploadData, metadata: nil, completion: { (metadata, error) in
                        if error != nil {
                            self.handlePostSaveError(errorMessage: "Profile Picture could not be updated. " + (error?.localizedDescription)!)
                        }
                        storedProfilePicture.downloadURL(completion: { (url, error) in
                            if error != nil {
                                self.handlePostSaveError(errorMessage: "Profile Picture could not be updated. " + (error?.localizedDescription)!)
                            }
                            if let urlText = url?.absoluteString {
                                self.databaseRef.child("Users").child(self.userID!).updateChildValues(["Profile Picture" : urlText], withCompletionBlock: { (error, ref) in
                                    if error != nil {
                                        self.handlePostSaveError(errorMessage: "Profile Picture could not be updated. " + (error?.localizedDescription)!)
                                    }
                                })
                            }
                        })
                    })
                }
            }
        }
        else {
            self.databaseRef.child("Users").child(self.userID!).child("Profile Picture").setValue(nil) // If no picture then set the profile picture's url to nil
        }
    }
    
    func saveSensitiveData(emailValue: String?, newPasswordValue: String?, confirmPasswordValue: String?) {
        
        // Prevents multiple alerts occuring at once
        if displayNameExists == false {
            
            // Updates email and/or password in Firebase
            if (emailValue != nil && emailValue != self.user?.email) || newPasswordValue != nil {
                self.reAuthOccurred = true
                
                // Reauthorises user with popup alert
                let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
                let alert = SCLAlertView(appearance: appearance)
                let textField = alert.addTextField("Enter Password")
                textField.isSecureTextEntry = true
                alert.addButton("Cancel") {}
                alert.addButton("Authorise") {
                    let credential = EmailAuthProvider.credential(withEmail: self.user!.email!, password: textField.text!)
                    self.user?.reauthenticate(with: credential) { error in
                        if let error = error {
                            if error.localizedDescription == "We have blocked all requests from this device due to unusual activity. Try again later." {
                                self.handlePostSaveError(errorMessage: error.localizedDescription)
                            }
                            else {
                                self.handlePostSaveError(errorMessage: "Email and/or password could not be updated. " +  error.localizedDescription)
                            }
                        }
                        else {
                            
                            // Changes email
                            if emailValue != nil && emailValue != self.user?.email {
                                self.self.reAuthOccurred = true
                                self.user?.updateEmail(to: emailValue!) { (error) in
                                    if error != nil {
                                        if newPasswordValue == nil { // Prevents multiple error alerts
                                            self.handlePostSaveError(errorMessage: "Email could not be updated. " + (error?.localizedDescription)!)
                                        }
                                        else {
                                            self.emailChangeError = (error?.localizedDescription)!
                                        }
                                    }
                                    else {
                                        if newPasswordValue == nil { // Prevents multiple success alerts
                                            SCLAlertView().showSuccess("Success!", subTitle: "Profile updated successfully.")
                                        }
                                    }
                                }
                            }
                            
                            // Changes password
                            if newPasswordValue != nil {
                                self.reAuthOccurred = true
                                self.user?.updatePassword(to: confirmPasswordValue!) { (error) in
                                    if error != nil {
                                        if self.emailChangeError == "" {
                                            if emailValue == self.user?.email {
                                                self.handlePostSaveError(errorMessage: "Password could not be updated. " + (error?.localizedDescription)!)
                                            }
                                            else {
                                                self.handlePostSaveError(errorMessage: "Email updated successfully, but password was not. " + (error?.localizedDescription)!)
                                            }
                                        }
                                        else {
                                            self.handlePostSaveError(errorMessage: "Email and password could not be updated. " + self.emailChangeError + " " + (error?.localizedDescription)!)
                                        }
                                    }
                                    else {
                                        if self.emailChangeError != "" {
                                            self.handlePostSaveError(errorMessage: "Password updated successfully, but email was not. " + self.emailChangeError)
                                        }
                                        else {
                                            SCLAlertView().showSuccess("Success!", subTitle: "Profile updated successfully.")
                                            self.form.setValues(["NewPasswordTag": nil, "ConfirmPasswordTag": nil])
                                            self.tableView.reloadData()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                alert.showEdit("Authentication", subTitle: "The password must be entered to make these changes.")
            }
        }
    }
    
    func logout() {
        
        // Signs user out if they select Logout option
        let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
        let alert = SCLAlertView(appearance: appearance)
        alert.addButton("Cancel") {
        }
        alert.addButton("Logout") {
            try! Auth.auth().signOut() // Signs the current user out from Firebase
            self.performSegue(withIdentifier: "profileToLoginSegue", sender: self) // Directs user to Home page
        }
        alert.showWarning("Confirmation", subTitle: "Are you sure you want to logout before completing the signup process?")
    }
    
    func deleteAccount() {
        
        // Only allow user to delete the account if they have an internet connection
        if reachability.connection == .none {
            SCLAlertView().showError("Error", subTitle: "An internet connection is required for deleting the account and it's associated data. Connect to the internet and try again.")
        }
        else {
            
            // Makes user confirm before they can continue
            let warningAppearance = SCLAlertView.SCLAppearance(showCloseButton: false)
            let warningAlert = SCLAlertView(appearance: warningAppearance)
            warningAlert.addButton("Cancel") {
            }
            warningAlert.addButton("Delete Account") {
                
                // Reauthorises user with popup alert
                let authAppearance = SCLAlertView.SCLAppearance(showCloseButton: false)
                let authAlert = SCLAlertView(appearance: authAppearance)
                let textField = authAlert.addTextField("Enter Password")
                textField.isSecureTextEntry = true
                authAlert.addButton("Cancel") {
                }
                authAlert.addButton("Authorise") {
                    let credential = EmailAuthProvider.credential(withEmail: self.user!.email!, password: textField.text!)
                    self.user?.reauthenticate(with: credential) { error in
                        if let error = error {
                            SCLAlertView().showError("Error", subTitle: error.localizedDescription)
                        } else {
                            
                            // Deletes Game data
                            self.databaseRef.child("Game Scores").child(self.userID!).removeValue { error, _ in
                                if let error = error {
                                    SCLAlertView().showError("Error", subTitle: error.localizedDescription)
                                }
                                else
                                {
                                    
                                    // Deletes Event data
                                    self.databaseRef.child("Events").child(self.userID!).removeValue { error, _ in
                                        if let error = error {
                                            SCLAlertView().showError("Error", subTitle: error.localizedDescription)
                                        }
                                        else
                                        {
                                            // Deletes Profile data
                                            self.databaseRef.child("Users").child(self.userID!).removeValue { error, _ in
                                                if let error = error {
                                                    SCLAlertView().showError("Error", subTitle: error.localizedDescription)
                                                }
                                                else {
                                                    
                                                    // Deletes the account
                                                    self.user?.delete(completion: { (error) in
                                                        if let error = error {
                                                            SCLAlertView().showError("Error", subTitle: error.localizedDescription)
                                                        }
                                                        else {
                                                            self.performSegue(withIdentifier: "profileToLoginSegue", sender: self) // Directs user to Login Page
                                                        }
                                                    })
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                authAlert.showEdit("Authentication", subTitle: "The password must be entered to delete the account.")
            }
            warningAlert.showWarning("Warning", subTitle: "Are you sure you want to delete the account and it's associated data? This action cannot be undone. \n\n Note: Users will still be able to view previous posts created from this account, but the associated Profile Picture and Display Name will be removed from them.")
        }
    }
    
    func setupForm() {
        
        // Sets up form
        rowKeyboardSpacing = 20 // Sets distance between keyboard and text field
        
        form +++ Section("User Profile")
            <<< ImageRow() { row in
                row.title = "Profile Picture"
                row.sourceTypes = [.PhotoLibrary]
                row.clearAction = .yes(style: UIAlertActionStyle.destructive)
                row.tag = "ProfilePictureTag"
                row.allowEditor = true
                row.useEditedImage = true // Sets profile picture to default profile pic image
                row.placeholderImage = #imageLiteral(resourceName: "DefaultProfilePicture").tinted(with: self.greyColor)
                }
                .cellUpdate { cell, row in
                    cell.textLabel?.textColor = .black
                    cell.imageView?.image = #imageLiteral(resourceName: "DefaultProfilePicture").tinted(with: self.greyColor)
                    cell.accessoryView?.layer.cornerRadius = (cell.accessoryView?.layer.frame.height)! / 2 // Makes profile picture a circle
                    cell.height = ({return 60})
                }
                .onCellSelection({ (cell, row) in
                    if row.value == nil {
                        cell.imageView?.image = #imageLiteral(resourceName: "DefaultProfilePicture").tinted(with: self.pinkColor)
                    }
                })
            
            <<< AccountRow(){
                $0.title = "Display Name"
                $0.placeholder = "Display Name"
                $0.tag = "DisplayNameTag"
                }
                .cellUpdate { cell, row in
                    cell.textLabel?.textColor = .black
                    if cell.textField.isEditing == false {
                        cell.imageView?.image = #imageLiteral(resourceName: "DisplayName").tinted(with: self.greyColor)
                    }
                    else {
                        cell.imageView?.image = #imageLiteral(resourceName: "DisplayName").tinted(with: self.pinkColor)
                    }
                    cell.height = ({return 60})
            }
            <<< NameRow(){
                $0.title = "Full Name"
                $0.placeholder = "Full Name"
                $0.tag = "FullNameTag"
                }
                .cellUpdate { cell, row in
                    cell.textLabel?.textColor = .black
                    if cell.textField.isEditing == false {
                        cell.imageView?.image = #imageLiteral(resourceName: "Profile").tinted(with: self.greyColor)
                    }
                    else {
                        cell.imageView?.image = #imageLiteral(resourceName: "Profile").tinted(with: self.pinkColor)
                    }
                    cell.height = ({return 60})
            }
            <<< PickerInlineRow<String>(){
                $0.title = "Brain Injury"
                $0.tag = "BrainInjuryTag"
                $0.options = ["None", "ABI", "TBI"]
                $0.value = "None"
                }
                .cellSetup({ (cell, row) in
                    cell.detailTextLabel?.textColor = .black
                    cell.textLabel?.textColor = .black
                    cell.height = ({return 60})
                    cell.imageView?.image = #imageLiteral(resourceName: "Brain").tinted(with: self.greyColor)
                })
                .onCollapseInlineRow({ (cell, row, pickerRow) in
                    cell.imageView?.image = #imageLiteral(resourceName: "Brain").tinted(with: self.greyColor)
                })
                .onExpandInlineRow({ (cell, row, pickerRow) in
                    cell.imageView?.image = #imageLiteral(resourceName: "Brain").tinted(with: self.pinkColor)
                })
            
            +++ Section("Emergency Contact") {
                $0.hidden = Condition.predicate(NSPredicate(format: "$BrainInjuryTag == 'None'"))
            }
            <<< PickerInlineRow<String>(){ row in
                row.title = "Relation"
                row.tag = "ECRelationTag"
                row.options = ["Guardian", "Mother","Father","Brother","Sister","Cousin","Aunty","Uncle", "Grandfather","Grandmother","Son", "Daughter", "Nephew", "Niece", "Grandson", "Granddaughter", "Girlfriend", "Boyfriend", "Husband", "Wife", "Friend", "Carer"]
                row.value = "Guardian"
                }
                .cellSetup({ (cell, row) in
                    cell.detailTextLabel?.textColor = .black
                    cell.textLabel?.textColor = .black
                    cell.height = ({return 60})
                    cell.imageView?.image = #imageLiteral(resourceName: "Relation").tinted(with: self.greyColor)
                })
                .onCollapseInlineRow({ (cell, row, pickerRow) in
                    cell.imageView?.image = #imageLiteral(resourceName: "Relation").tinted(with: self.greyColor)
                })
                .onExpandInlineRow({ (cell, row, pickerRow) in
                    cell.imageView?.image = #imageLiteral(resourceName: "Relation").tinted(with: self.pinkColor)
                })
            <<< NameRow(){
                $0.title = "Full Name"
                $0.placeholder = "Full Name"
                $0.tag = "ECFullNameTag"
                }
                .cellUpdate { cell, row in
                    cell.textLabel?.textColor = .black
                    if cell.textField.isEditing == false {
                        cell.imageView?.image = #imageLiteral(resourceName: "Profile").tinted(with: self.greyColor)
                    }
                    else {
                        cell.imageView?.image = #imageLiteral(resourceName: "Profile").tinted(with: self.pinkColor)
                    }
                    cell.height = ({return 60})
            }
            <<< PhoneRow(){
                $0.title = "Contact Number"
                $0.placeholder = "Contact Number"
                $0.tag = "ECNumberTag"
                }
                .cellUpdate { cell, row in
                    cell.textLabel?.textColor = .black
                    if cell.textField.isEditing == false {
                        cell.imageView?.image = #imageLiteral(resourceName: "Phone").tinted(with: self.greyColor)
                    }
                    else {
                        cell.imageView?.image = #imageLiteral(resourceName: "Phone").tinted(with: self.pinkColor)
                    }
                    cell.height = ({return 60})
            }
            
            +++ Section("Security") {
                $0.tag = "SecuritySectionTag"
            }
            <<< EmailRow(){ row in
                row.title = "Login/Email"
                row.placeholder = "Email"
                row.tag = "EmailTag"
                }
                .cellUpdate { cell, row in
                    cell.textLabel?.textColor = .black
                    if cell.textField.isEditing == false {
                        cell.imageView?.image = #imageLiteral(resourceName: "Email").tinted(with: self.greyColor)
                    }
                    else {
                        cell.imageView?.image = #imageLiteral(resourceName: "Email").tinted(with: self.pinkColor)
                    }
                    cell.height = ({return 60})
            }
            <<< PasswordRow(){
                $0.title = "New Password"
                $0.placeholder = "New Password"
                $0.tag = "NewPasswordTag"
                
                }
                .cellUpdate { cell, row in
                    cell.textLabel?.textColor = .black
                    if cell.textField.isEditing == false {
                        cell.imageView?.image = #imageLiteral(resourceName: "Password").tinted(with: self.greyColor)
                    }
                    else {
                        cell.imageView?.image = #imageLiteral(resourceName: "Password").tinted(with: self.pinkColor)
                    }
                    cell.height = ({return 60})
            }
            <<< PasswordRow(){
                $0.title = "Confirm"
                $0.placeholder = "New Password"
                $0.tag = "ConfirmPasswordTag"
                $0.hidden = Condition.predicate(NSPredicate(format: "$NewPasswordTag == nil"))
                
                }
                .cellUpdate { cell, row in
                    cell.textLabel?.textColor = .black
                    if cell.textField.isEditing == false {
                        cell.imageView?.image = #imageLiteral(resourceName: "Password").tinted(with: self.greyColor)
                    }
                    else {
                        cell.imageView?.image = #imageLiteral(resourceName: "Password").tinted(with: self.pinkColor)
                    }
                    cell.height = ({return 60})
            }
            
            +++ Section("Delete Account") {
                $0.tag = "DeleteAccountSectionTag"
            }
            <<< ButtonRow(){ row in
                row.title = "Delete Account & Associated Data"
                row.tag = "DeleteAccountTag"
                }
                .cellUpdate { cell, row in
                    cell.height = ({return 60})
                    cell.textLabel?.textColor = .red
                }
                .onCellSelection({ (cell, row) in
                    self.deleteAccount()
                })
            
            +++ Section("Logout") {
                $0.tag = "LogoutSectionTag"
                $0.hidden = true
            }
            <<< ButtonRow(){ row in
                row.title = "Logout & Finish Later"
                row.tag = "LogoutTag"
                }
                .cellUpdate { cell, row in
                    cell.height = ({return 60})
                    cell.textLabel?.textColor = .red
                }
                .onCellSelection({ (cell, row) in
                    self.logout()
                })
    }
    
    func loadFormData() {
        
        // Loads profile information
        databaseRef.child("Users").child(userID!).observeSingleEvent(of: .value, with: {
            (snapshot) in
            if let dict = snapshot.value as? [String: AnyObject] {
                
                // Set form values
                self.form.setValues([
                    "EmailTag": Auth.auth().currentUser?.email,
                    "DisplayNameTag": dict["Display Name"] as! String,
                    "FullNameTag": dict["Full Name"] as! String,
                    "BrainInjuryTag": dict["Brain Injury"] as! String,
                    ])
                
                // Set further form values if they exist
                if dict["EC Relation"] as? String != nil {
                    self.form.setValues([
                        "ECRelationTag": dict["EC Relation"] as! String,
                        "ECFullNameTag": dict["EC Full Name"] as? String,
                        "ECNumberTag": dict["EC Number"] as? String,
                        ])
                }
                
                self.tableView.reloadData() // Reloads form
                
                // Loads profile picture if the user has one
                if let profilePicureURL = dict["Profile Picture"] as? String
                {
                    let url = URL(string: profilePicureURL)
                    URLSession.shared.dataTask(with: url!, completionHandler: { (data, response, error) in
                        if error != nil { // Validation
                            SCLAlertView().showError("Error", subTitle: (error?.localizedDescription)!) // Validation
                        }
                        DispatchQueue.main.async {
                            self.form.setValues(["ProfilePictureTag": UIImage(data: data!)])
                            self.tableView.reloadData()
                        }
                    }).resume()
                }
            }
            else { // If user has yet to complete signup
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { // Gives time for transition animation to complete
                    SCLAlertView().showInfo("Signup", subTitle: "Fill out this short form to complete signing up.")
                }
                
                self.signingUp = true
                self.form.setValues(["EmailTag": Auth.auth().currentUser?.email])
                self.tableView.reloadData()
                
                // Hides/Shows sections/rows depending on whether user is signing up or editing existing profile
                DispatchQueue.main.async() {
                    self.form.sectionBy(tag: "DeleteAccountSectionTag")!.hidden = true
                    self.form.sectionBy(tag: "DeleteAccountSectionTag")!.evaluateHidden()
                    self.form.sectionBy(tag: "SecuritySectionTag")!.hidden = true
                    self.form.sectionBy(tag: "SecuritySectionTag")!.evaluateHidden()
                    self.form.sectionBy(tag: "LogoutSectionTag")!.hidden = false
                    self.form.sectionBy(tag: "LogoutSectionTag")!.evaluateHidden()
                }
            }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupForm() // Sets up form
        loadFormData() // Loads user profile data
    }
}
