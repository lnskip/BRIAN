//
//  NewPostViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import UIKit
import SCLAlertView
import Firebase
import Eureka
import SCLAlertView
import Reachability

class NewPostViewController: FormViewController  {
    
    @IBAction func cancel(_ sender: Any) {
        view.endEditing(true) // Hides keyboard
        self.dismiss(animated: true, completion: nil) // Dismisses view controller
    }
    
    @IBAction func post(_ sender: Any) {
        let postText: TextAreaRow? = form.rowBy(tag: "PostTextTag")
        let postTextValue = postText?.value
        
        let reachability = Reachability()!
        if reachability.connection == .wifi || reachability.connection == .cellular {
            
            if postTextValue?.count != nil && (postTextValue?.count)! <= 280 {
                
                // Firebase
                let userID = Auth.auth().currentUser?.uid
                let databaseRef = Database.database().reference()
                
                let userPost = ["User": userID!, "Text": postTextValue!, "Score": 0, "Reply Count": 0, "Timestamp": NSDate().timeIntervalSince1970] as [String : Any]
                
                // Gets selectedPostID
                if let selectedPostID = Shared.shared.selectedPostID {
                    
                    // Saves post to Firebase
                    if selectedPostID == "" { // If post is being added from main forum page
                        databaseRef.child("Posts").childByAutoId().updateChildValues(userPost, withCompletionBlock: { (error, ref) in
                            if error != nil {
                                SCLAlertView().showError("Error", subTitle: (error?.localizedDescription)!)
                            }
                            else {
                                self.view.endEditing(true) // Hides keyboard
                                self.dismiss(animated: true, completion: nil) // Dismisses view controller
                            }
                        })
                    }
                    else { // If post is being added from reply to forum post page
                        
                        // Adds reply
                        databaseRef.child("Posts").child(selectedPostID).child("Replies").childByAutoId().updateChildValues(userPost, withCompletionBlock: { (error, ref) in
                            if error != nil {
                                self.view.endEditing(true) // Hides keyboard
                                SCLAlertView().showError("Error", subTitle: (error?.localizedDescription)!) // Error message
                            }
                            else {
                                self.view.endEditing(true) // Hides keyboard
                                self.dismiss(animated: true, completion: nil) // Dismisses view controller
                            }
                        })
                        
                        // Updates number of replies by +1 in Firebase
                        let replyCountDatabaseRef =  databaseRef.child("Posts").child(selectedPostID).child("Reply Count")
                        replyCountDatabaseRef.observeSingleEvent(of: .value, with: {
                            (snapshot) in
                            var value = snapshot.value as! Int
                            value += 1
                            replyCountDatabaseRef.setValue(value)
                        })
                    }
                }
            }
            else {
                self.view.endEditing(true) // Hides keyboard
                
                if let characterCount = postTextValue?.count {
                    SCLAlertView().showError("Error", subTitle: "New posts must contain between 1 and 280 characters. \n\nCurrent number of characters: " + String(characterCount) + ".") // Error messag
                }
                else {
                    SCLAlertView().showError("Error", subTitle: "New posts must contain between 1 and 280 characters.") // Error message
                }
            }
        }
        else {
            self.view.endEditing(true) // Hides keyboard
            SCLAlertView().showError("Error", subTitle: "An internet connection is required for posting. Connect to the internet and try again.") // Error message
        }
    }
    
    func setupForm() {
        // Sets up form
        rowKeyboardSpacing = 20 // Sets distance between keyboard and text field
        form +++ Section("Create Post")
            <<< TextAreaRow(){ row in
                row.title = "Post"
                row.tag = "PostTextTag"
                row.placeholder = "Share something with the Brian community!"
                row.textAreaHeight = .dynamic(initialTextViewHeight: 120)
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        setupForm() // Loads form
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        // Shows keyboard instantly
        let row = self.form.rowBy(tag: "PostTextTag") as! TextAreaRow
        row.cell.textView.becomeFirstResponder()
    }
}

