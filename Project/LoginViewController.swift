//
//  LoginViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import UIKit
import FirebaseAuth
import IQKeyboardManagerSwift
import SCLAlertView
import Reachability

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    // UI Variables
    @IBOutlet weak var segmentControl: UISegmentedControl!
    @IBOutlet weak var userEmail: UITextField!
    @IBOutlet weak var userPassword: UITextField!
    @IBOutlet weak var loginOrSignUpButton: UIButton!
    @IBOutlet weak var loginBackground: UIImageView!
    @IBOutlet weak var loginBackgroundDetails: UIImageView!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    
    var forgotPasswordButtonSelected = false // Holds whether or not forgotPasswordButton is selected
    @IBAction func forgotPassword(_ sender: Any) {
        // Hides and disables Password field as it is not needed to send password reset email
        userPassword.isEnabled = false
        userPassword.isHidden = true
        
        userEmail.returnKeyType = UIReturnKeyType.go // Sets return key to Go as Password field is hidden
        
        if forgotPasswordButton.title(for: UIControlState.normal) == "Forgot Password?" {
            forgotPasswordButtonSelected = true // forgotPasswordButton is selected
            userPassword.text = "" // Removes any text in password field
            userPassword.isEnabled = false // Disables password field
            
            // Button behaviours
            loginOrSignUpButton.setTitle("Send Reset Email", for: UIControlState.normal)
            forgotPasswordButton.setTitle("Cancel", for: UIControlState.normal)
        }
        else {
            segmentOptionSelected((Any).self) // Reselects segment control option (resetting login UI)
        }
    }
    
    @IBAction func segmentOptionSelected(_ sender: Any) {
        
        forgotPasswordButtonSelected = false // forgotPasswordButton is not selected
        userPassword.isEnabled = true // Enables password field
        userPassword.isHidden = false // Shows password field
        userEmail.returnKeyType = UIReturnKeyType.next // Sets return key to Next as Password field is beneath
        
        // Button behaviours
        forgotPasswordButton.setTitle("Forgot Password?", for: UIControlState.normal)
        
        switch segmentControl.selectedSegmentIndex {
        case 0: loginOrSignUpButton.setTitle("Login", for: UIControlState.normal)
        case 1: loginOrSignUpButton.setTitle("Signup", for: UIControlState.normal)
        default: break;
        }
    }
    
    @IBAction func loginOrSignUp(_ sender: Any) {
        self.view.endEditing(true) // Hides keyboard
        
        // Checks that user has internet connecting before attempting to login (validation)
        let reachability = Reachability()!
        if reachability.connection == .none {
            SCLAlertView().showError("Error", subTitle: "An internet connection is required for logging in. Connect to the internet and try again.")
            shakeLoginUI()
        }
        else {
            
            if forgotPasswordButtonSelected == true // If the user has selected the forgottenPasswordButton
            {
                Auth.auth().sendPasswordReset(withEmail: userEmail.text!) { error in
                    if error != nil
                    {
                        if let error = error?.localizedDescription
                        {
                            SCLAlertView().showError("Error", subTitle: error)
                            self.shakeLoginUI() // Pops up error message
                        }
                    }
                    else
                    {
                        SCLAlertView().showSuccess("Success!", subTitle: "A password reset email has been sent to " + self.userEmail.text! + ".")
                        self.segmentOptionSelected((Any).self) // Reselects segment control option (resetting login UI)
                    }
                }
            }
                
            else // If user has selected Login/Signup segment control option
            {
                if userEmail.text != ""
                {
                    if segmentControl.selectedSegmentIndex == 0 // Login
                    {
                        Auth.auth().signIn(withEmail: userEmail.text!, password: userPassword.text!, completion: { (user, error) in
                            if user != nil // Login successful
                            {
                                self.performSegue(withIdentifier: "loginSegue", sender: self) // Directs user to Home page
                            }
                            else // Login unsuccessful
                            {
                                if let error = error?.localizedDescription // Sets signInError as the discription of specific error
                                {
                                    SCLAlertView().showError("Error", subTitle: error)
                                    self.shakeLoginUI() // Pops up error message
                                }
                            }
                        })
                    }
                    else // Signup
                    {
                        // Add a text field
                        let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
                        let alert = SCLAlertView(appearance: appearance)
                        let confirmationPassword = alert.addTextField("Confirm Password")
                        confirmationPassword.isSecureTextEntry = true
                        alert.addButton("Cancel") {}
                        alert.addButton("Confirm") {
                            self.view.endEditing(true) // Hides keyboard 
                            
                            // If confirmation password matches password
                            if confirmationPassword.text == self.userPassword.text! {
                                Auth.auth().createUser(withEmail: self.userEmail.text!, password: self.userPassword.text!, completion: { (user, error) in
                                    if user != nil // Signup successful
                                    {
                                        self.performSegue(withIdentifier: "signupSegue", sender: self) // Directs user to signup/profile page
                                    }
                                    else //Signup unsuccessful
                                    {
                                        if let error = error?.localizedDescription
                                        {
                                            SCLAlertView().showError("Error", subTitle: error)
                                            self.shakeLoginUI()
                                        }
                                    }
                                })
                            }
                            else { // Confirmation password did not match password
                                SCLAlertView().showError("Error", subTitle: "The password and confirmation password do not match. These fields must match before proceeding.")
                                self.shakeLoginUI()
                            }
                        }
                        alert.showEdit("Confirmation", subTitle: "Re-enter the password to continue.")
                    }
                }
                else
                {
                    SCLAlertView().showError("Error", subTitle: "An email address must be provided.")
                    shakeLoginUI()
                }
            }
        }
    }
    
    // Animates the login user interface
    func shakeLoginUI() {
        segmentControl.shakeAnimation()
        userEmail.shakeAnimation()
        userPassword.shakeAnimation()
        loginOrSignUpButton.shakeAnimation()
        loginBackground.shakeAnimation()
        loginBackgroundDetails.shakeAnimation()
        forgotPasswordButton.shakeAnimation()
    }
    
    // Configures the return keyboard key behaviour
    func textFieldShouldReturn(_: UITextField) -> Bool {
        if IQKeyboardManager.sharedManager().canGoNext == true
        {
            IQKeyboardManager.sharedManager().goNext()
        }
        else
        {
            self.loginOrSignUp((Any).self)
        }
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib
        self.navigationController?.isNavigationBarHidden = true
        
        // Allows the return keyboard key to function as required
        userEmail.delegate = self
        userPassword.delegate = self
        
    }
}

