//
//  LaunchViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import UIKit
import Firebase
import IQKeyboardManagerSwift
import Reachability

class LaunchViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        let reachability = Reachability()! // Allows internet connection to be checked
        
        // User does not have an internet connection
        if reachability.connection == . none {
            self.performSegue(withIdentifier: "completeLoginSegue", sender: self) // Directs user to Home page
        }
        else { // User does have an internet connection
            
            Auth.auth().addStateDidChangeListener { auth, user in
                if user != nil { // User is signed in
                    let databaseRef = Database.database().reference()
                    
                    databaseRef.child("Users").child(user!.uid).observeSingleEvent(of: .value, with: {
                        (snapshot) in
                        
                        // If the user has no data in the database then direct them to profile page to complete signup
                        if snapshot.value as? [String: AnyObject] == nil
                        {
                            // User has not completed signup, show profile page to complete signup
                            self.performSegue(withIdentifier: "completeSignupSegue", sender: self)
                        }
                        else { // User has completed signup, show home screen
                            self.performSegue(withIdentifier: "loginSegue", sender: self) // Directs user to Home page
                        }
                    })
                }
                else { // No user is signed in, show user the login screen
                    self.performSegue(withIdentifier: "completeLoginSegue", sender: self) // Directs user to Home page
                }
            }
        }
    }
}
