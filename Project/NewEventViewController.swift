//
//  NewEventViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import UIKit
import JTAppleCalendar
import IQKeyboardManagerSwift
import SCLAlertView
import Eureka
import Firebase
import Reachability

class NewEventViewController: FormViewController  {
    
    // Firebase
    let databaseRef = Database.database().reference()
    let userID = Auth.auth().currentUser?.uid
    
    // Shared custom colors
    let greyColor = Shared.shared.greyColor
    let pinkColor = Shared.shared.pinkColor
    let lightPinkColor = Shared.shared.lightPinkColor
    
    let formatter = DateFormatter() // Allows dates to be formatted
    
    var displayName = "" // Holds display name of current user
    
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
        self.view.endEditing(true) // Hides keyboard
    }
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBAction func addEvent(_ sender: Any) {
        tableView.reloadData()
        
        // Gets values from the form
        let title: NameRow? = form.rowBy(tag: "TitleTag")
        let titleValue = title?.value
        let notes: TextRow? = form.rowBy(tag: "NotesTag")
        let notesValue = notes?.value
        let date: DateInlineRow? = form.rowBy(tag: "DateTag")
        let dateValue = date?.value
        let startTime: TimeInlineRow? = form.rowBy(tag: "StartTimeTag")
        let startTimeValue = startTime?.value
        let endTime: TimeInlineRow? = form.rowBy(tag: "EndTimeTag")
        let endTimeValue = endTime?.value
        let userKey: AccountRow? = form.rowBy(tag: "UserKeyTag")
        let userKeyValue = userKey?.value
        let share:SwitchRow? = form.rowBy(tag: "ShareTag")
        let shareValue = share?.value
        
        let userID = Auth.auth().currentUser?.uid // User ID
        
        // Validation
        let reachability = Reachability()!
        if reachability.connection == .none {
            SCLAlertView().showError("Error", subTitle: "An internet connection is required for adding events. Connect to the internet and try again.")
        }
        else if dateValue == nil || startTimeValue == nil || endTimeValue == nil || titleValue == nil  {
            SCLAlertView().showError("Error", subTitle: "Title field must contain between 1 and 40 characters.")
        }
        else if titleValue!.count > 40  {
            SCLAlertView().showError("Error", subTitle: "Title field must contain between 1 and 40 characters.\n\nCurrent number of characters: " + String(titleValue!.count) + ".")
        }
        else if shareValue == true { // If user is sharing event with another user
            shareEvent(userID: userID, titleValue: titleValue, notesValue: notesValue, dateValue: dateValue, startTimeValue: startTimeValue, endTimeValue: endTimeValue, userKeyValue: userKeyValue) // Saves event to sender and receiver's Firebase
        }
        else { // If user is saving the event for themselves only
            saveEvent(userID: userID, titleValue: titleValue, notesValue: notesValue, dateValue: dateValue, startTimeValue: startTimeValue, endTimeValue: endTimeValue, userKeyValue: userKeyValue) // Saves event to Firebase
        }
    }
    
    func shareEvent(userID: String?, titleValue: String?, notesValue: String?, dateValue: Date?, startTimeValue: Date?, endTimeValue: Date?, userKeyValue: String?) {
        
        // Characters which are allowed to be used in the user key
        let characterset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        
        // If user key doesn't contain a value
        if userKeyValue == nil {
            SCLAlertView().showError("Error", subTitle: "Due to the Share Event switch being activated, the User Key field must contain a value before sharing the event with another user.")
        }
            
            // If user key contains special characters (not in character set)
        else if userKeyValue?.rangeOfCharacter(from: characterset.inverted) != nil {
            SCLAlertView().showError("Error", subTitle: "No user exists with the key \"" + userKeyValue! + "\".")
        }
        else {
            
            // Gets reciever details
            databaseRef.child("Users").child(userKeyValue!).observeSingleEvent(of: .value, with: {
                (snapshot) in
                if let userDict = snapshot.value as? [String: AnyObject] {
                    let receiver = userDict["Display Name"] as! String
                    
                    
                    self.databaseRef.child("Users").child(userID!).updateChildValues(["Connection": userKeyValue!]) // Saves receiver ID to Firebase as current user's connection
                    
                    // Adds sender/receiver details to event notes
                    var senderNotesValue: String?
                    var receiverNotesValue: String?
                    if notesValue != nil {
                        senderNotesValue = notesValue! + " ~Sent to " + receiver + "."
                        receiverNotesValue = notesValue! + " ~Sent from " + self.displayName + "."
                    }
                    else {
                        senderNotesValue = "Sent to " + receiver + "."
                        receiverNotesValue = "Sent from " + self.displayName + "."
                    }
                    
                    // Saves sender/receiver event to Firebase
                    self.saveEvent(userID: userID, titleValue: titleValue, notesValue: senderNotesValue, dateValue: dateValue, startTimeValue: startTimeValue, endTimeValue: endTimeValue, userKeyValue: userKeyValue)
                    self.saveEvent(userID: userKeyValue, titleValue: titleValue, notesValue: receiverNotesValue, dateValue: dateValue, startTimeValue: startTimeValue, endTimeValue: endTimeValue, userKeyValue: userKeyValue)
                }
                else { // Reciever doesn't exist
                    SCLAlertView().showError("Error", subTitle: "No user exists with the key \"" + userKeyValue! + "\".")
                }
            })
        }
    }
    
    func saveEvent(userID: String?, titleValue: String?, notesValue: String?, dateValue: Date?, startTimeValue: Date?, endTimeValue: Date?, userKeyValue: String?) {
        
        // Turns dates into strings so that it can be stored in database
        formatter.dateFormat = "dd MM yyyy"
        let dateValueString = formatter.string(from: dateValue!)
        formatter.dateFormat = "HH:mm"
        let startTimeValueString = formatter.string(from: startTimeValue!)
        let endTimeValueString = formatter.string(from: endTimeValue!)
        
        if startTimeValueString > endTimeValueString {
            SCLAlertView().showError("Error", subTitle: "The start time must be earlier than the end time.")
        }
            
        else
        {
            
            // Uploads event to database
            var eventDetails = ""
            if notesValue == nil {
                eventDetails = "\nEvent: " + titleValue!
            }
            else {
                eventDetails = "\nEvent: " + titleValue! + "\nNotes: " + notesValue!
            }
            var eventTimes = startTimeValueString + " - " + endTimeValueString
            if startTimeValueString == "00:00" && endTimeValueString == "23:59" {
                eventTimes = "All-day"
            }
            let eventID = dateValueString + " @ " + eventTimes + eventDetails
            databaseRef.child("Events").child(userID!).childByAutoId().updateChildValues(["Event": eventID], withCompletionBlock: { (error, ref) in
                if error != nil {
                    SCLAlertView().showError("Error", subTitle: (error?.localizedDescription)!)
                }
                else {
                    self.dismiss(animated: true, completion: nil)  // Returns user to calendar/diary
                    self.view.endEditing(true) // Hides keyboard
                }
            })
        }
    }
    
    func setupForm() {
        // Sets up form
        if let selectedDate = Shared.shared.selectedDate {
            rowKeyboardSpacing = 20 // Sets distance between keyboard and text field
            form +++ Section("Details")
                <<< NameRow(){ row in
                    row.title = "Title"
                    row.tag = "TitleTag"
                    row.placeholder = "Title"
                    }
                    .cellUpdate { cell, row in
                        cell.textLabel?.textColor = .black
                        cell.height = ({return 60})
                        cell.titleLabel?.textColor = .black
                        if cell.textField.isEditing == false {
                            cell.imageView?.image = #imageLiteral(resourceName: "Title").tinted(with: self.greyColor)
                        }
                        else {
                            cell.imageView?.image = #imageLiteral(resourceName: "Title").tinted(with: self.pinkColor)
                        }
                }
                <<< TextRow(){
                    $0.title = "Notes"
                    $0.tag = "NotesTag"
                    $0.placeholder = "Notes (Optional)"
                    }
                    .cellUpdate { cell, row in
                        cell.textLabel?.textColor = .black
                        cell.height = ({return 60})
                        cell.titleLabel?.textColor = .black
                        if cell.textField.isEditing == false {
                            cell.imageView?.image = #imageLiteral(resourceName: "Notes").tinted(with: self.greyColor)
                        }
                        else {
                            cell.imageView?.image = #imageLiteral(resourceName: "Notes").tinted(with: self.pinkColor)
                        }
                }
                +++ Section("Date & Time")
                <<< DateInlineRow(){ row in
                    row.title = "Date"
                    row.tag = "DateTag"
                    row.value = selectedDate // Sets date to date selected in calendar
                    }
                    .cellSetup({ (cell, row) in
                        cell.detailTextLabel?.textColor = .black
                        cell.textLabel?.textColor = .black
                        cell.height = ({return 60})
                        cell.imageView?.image = #imageLiteral(resourceName: "Date").tinted(with: self.greyColor)
                    })
                    .onCollapseInlineRow({ (cell, row, pickerRow) in
                        cell.imageView?.image = #imageLiteral(resourceName: "Date").tinted(with: self.greyColor)
                    })
                    .onExpandInlineRow({ (cell, row, pickerRow) in
                        cell.imageView?.image = #imageLiteral(resourceName: "Date").tinted(with: self.pinkColor)
                    })
                
                <<< TimeInlineRow(){
                    $0.title = "Starts"
                    $0.tag = "StartTimeTag"
                    $0.value = selectedDate // Sets time to 00:00
                    }
                    .cellSetup({ (cell, row) in
                        cell.detailTextLabel?.textColor = .black
                        cell.textLabel?.textColor = .black
                        cell.height = ({return 60})
                        cell.imageView?.image = #imageLiteral(resourceName: "StartTime").tinted(with: self.greyColor)
                    })
                    .onCollapseInlineRow({ (cell, row, pickerRow) in
                        cell.imageView?.image = #imageLiteral(resourceName: "StartTime").tinted(with: self.greyColor)
                    })
                    .onExpandInlineRow({ (cell, row, pickerRow) in
                        cell.imageView?.image = #imageLiteral(resourceName: "StartTime").tinted(with: self.pinkColor)
                    })
                <<< TimeInlineRow(){
                    $0.title = "Ends"
                    $0.tag = "EndTimeTag"
                    
                    // Sets time to 23:59
                    let gregorian = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)!
                    var components = gregorian.components([.hour, .minute], from: selectedDate)
                    components.hour = 23
                    components.minute = 59
                    let endOfSelectedDate = gregorian.date(from: components)!
                    $0.value = endOfSelectedDate
                    }
                    .cellSetup({ (cell, row) in
                        cell.detailTextLabel?.textColor = .black
                        cell.textLabel?.textColor = .black
                        cell.height = ({return 60})
                        cell.imageView?.image = #imageLiteral(resourceName: "EndTime").tinted(with: self.greyColor)
                    })
                    .onCollapseInlineRow({ (cell, row, pickerRow) in
                        cell.imageView?.image = #imageLiteral(resourceName: "EndTime").tinted(with: self.greyColor)
                    })
                    .onExpandInlineRow({ (cell, row, pickerRow) in
                        cell.imageView?.image = #imageLiteral(resourceName: "EndTime").tinted(with: self.pinkColor)
                    })
                
                +++ Section("Share")
                <<< SwitchRow(){ row in
                    row.title = "Share Event?"
                    row.value = false
                    row.tag = "ShareTag"
                    }.onChange { row in
                        row.updateCell()
                    }.cellUpdate { cell, row in
                        cell.height = ({return 60})
                        cell.imageView?.image = #imageLiteral(resourceName: "Share").tinted(with: self.greyColor)
                }
                <<< AccountRow(){
                    $0.title = "User Key"
                    $0.hidden = Condition.predicate(NSPredicate(format: "$ShareTag == false"))
                    $0.placeholder = "User Key"
                    $0.tag = "UserKeyTag"
                    }
                    .cellUpdate { cell, row in
                        cell.textLabel?.textColor = .black
                        if cell.textField.isEditing == false {
                            cell.imageView?.image = #imageLiteral(resourceName: "Key").tinted(with: self.greyColor)
                        }
                        else {
                            cell.imageView?.image = #imageLiteral(resourceName: "Key").tinted(with: self.pinkColor)
                        }
                        cell.height = ({return 60})
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupForm() // Loads form
        
        // Loads the user ID of the last user the current user sent an event to
        databaseRef.child("Users").child(userID!).observeSingleEvent(of: .value, with: {
            (snapshot) in
            if let dict = snapshot.value as? [String: AnyObject] {
                self.form.setValues(["UserKeyTag": dict["Connection"] as? String])
                self.displayName = dict["Display Name"] as! String
            }
            self.tableView.reloadData() // Reloads form
        })
    }
}
