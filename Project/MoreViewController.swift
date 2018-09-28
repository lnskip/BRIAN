//
//  MoreTableViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import SCLAlertView
import MessageUI
import SwiftLocation
import Reachability

class MoreTableViewController: UITableViewController, MFMessageComposeViewControllerDelegate
{
    // Firebase
    let databaseRef = Database.database().reference()
    let userID = Auth.auth().currentUser?.uid
    
    var pageNames = [String]() // Array variable
    
    // Alert for informing user that it may take 15 seconds to retrieve their location
    let infoAlert = SCLAlertView(appearance: SCLAlertView.SCLAppearance(showCloseButton: false))
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        self.dismiss(animated: true) // Dismisses messaging view controller
        infoAlert.hideView() // Hides info alert
    }
    
    func addNavigationBarImage() {
        
        // Sets navigation bar image
        let image = #imageLiteral(resourceName: "NavTitle")
        let imageView = UIImageView(image: image)
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        imageView.frame = titleView.bounds
        titleView.addSubview(imageView)
        
        navigationItem.titleView = imageView
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Makes table size = number of pageNames
        return pageNames.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Sets pageNames/images to cells
        let cell = tableView.dequeueReusableCell(withIdentifier: "moreCell", for: indexPath)
        cell.textLabel!.text = pageNames[indexPath.row]
        
        let imageName = UIImage(named: pageNames[indexPath.row])
        cell.imageView?.image = imageName
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewControllerName = pageNames[indexPath.row]
        
        // Signs user out if they select Logout option
        if pageNames[indexPath.row] == "Logout" {
            let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
            let alert = SCLAlertView(appearance: appearance)
            alert.addButton("Cancel") {
            }
            alert.addButton("Logout") {
                try! Auth.auth().signOut() // Signs the current user out from Firebase
                self.performSegue(withIdentifier: "moreToLoginSegue", sender: self) // Directs user to Home page
            }
            alert.showWarning("Confirmation", subTitle: "Are you sure you want to logout?")
        }
            
            // If user is trying to phone/text emergency contact
        else if pageNames[indexPath.row] == "Call Emergency Contact" || pageNames[indexPath.row] == "Text Emergency Contact" {
            contactEmergencyContact(indexPath: indexPath) // Contacts emergency contact via selected method
        }
        else {
            
            // Directs to another in-app page
            let viewController = storyboard?.instantiateViewController(withIdentifier: viewControllerName)
            self.navigationController?.pushViewController(viewController!, animated: true)
        }
    }
    
    func contactEmergencyContact(indexPath: IndexPath) {
        let reachability = Reachability()! // Allows internet connection to be checked
        if reachability.connection == .none { // User has no internet connection
            SCLAlertView().showError("Error", subTitle: "An internet connection is required to get your emergency contact details. Connect to the internet and try again.")
        }
        else { // User has internet connection
            
            // Gets user details, including emergency contact details
            databaseRef.child("Users").child(userID!).observeSingleEvent(of: .value, with: {
                (snapshot) in
                if let dict = snapshot.value as? [String: AnyObject] {
                    let name = dict["Full Name"] as? String
                    let ECName = dict["EC Full Name"] as? String
                    let ECNumber = dict["EC Number"] as? String
                    let ECRelation = dict["EC Relation"] as? String
                    
                    if ECNumber != nil { // User has emergency contact details
                        
                        // If user is trying to phone emergency contact
                        if self.pageNames[indexPath.row] == "Call Emergency Contact" {
                            let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
                            let alertView = SCLAlertView(appearance: appearance)
                            alertView.addButton("Proceed") {
                                guard let number = URL(string: "tel://" + ECNumber!) else { return }
                                UIApplication.shared.open(number)
                            }
                            alertView.showInfo("Info", subTitle: "The emergency contact for the current user (" + name! + ") is their " + ECRelation!.lowercased() + ", called " + ECName! + ".")
                        }
                            // If user is trying to text emergency contact
                        else if self.pageNames[indexPath.row] == "Text Emergency Contact" {
                            let controller = MFMessageComposeViewController()
                            
                            // If user can text message
                            if (MFMessageComposeViewController.canSendText()) {
                                
                                // Creates a function so it can be looped easily
                                func textEmergencyContact() {
                                    
                                    // If the message didn't load instantly, send this alert
                                    self.infoAlert.showInfo("Info", subTitle: "Attempting to retrieve location... This may take up to 15 seconds. \n")
                                    
                                    // Attempt to get location of user and write message
                                    SwiftLocation.Locator.currentPosition(accuracy: .room, timeout: .after(15), onSuccess: { location in
                                        controller.recipients = ([ECNumber] as! [String])
                                        controller.body = "SOS. Hi " + ECName! + ", there's an emergency. My location coordinates are \(location). Sent using Brian - The Brain Recovery App. From " + name! + "."
                                        controller.messageComposeDelegate = self
                                        self.present(controller, animated: true, completion: nil)
                                        
                                    }) { (error, last) -> (Void) in // If user has not allowed location services
                                        self.infoAlert.hideView() // Hides info alert
                                        
                                        // Gives user option to continue without location or try again
                                        let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
                                        let alertView = SCLAlertView(appearance: appearance)
                                        alertView.addButton("Try Again") {
                                            textEmergencyContact()
                                        }
                                        alertView.addButton("Continue") {
                                            controller.recipients = ([ECNumber] as! [String])
                                            controller.body = "SOS. Hi " + ECName! + ", there's an emergency. Call me ASAP. Sent using Brian - The Brain Recovery App. From " + name! + "."
                                            controller.messageComposeDelegate = self
                                            self.present(controller, animated: true, completion: nil)
                                        }
                                        alertView.showWarning("Warning", subTitle: "Could not retrieve location. Make sure that you have an internet connection and location services enabled. Try again or continue without your location?")
                                    }
                                }
                                textEmergencyContact()
                            }
                            else { // Can't text
                                SCLAlertView().showError("Error", subTitle: "SMS services are not available.")
                            }
                        }
                    }
                    else { // User has no emergency contact details
                        SCLAlertView().showError("Error", subTitle: "Your profile states that you are not suffering from a brain injury, therefore no emergency contact has been set. This can be changed in your profile.")
                    }
                }
            })
        }
    }
    
    override func viewDidLoad() {
        addNavigationBarImage() // Sets navigation bar image
        
        // Sets array values and configures table view
        pageNames = ["Profile", "FAQ", "Donate", "Call Emergency Contact", "Text Emergency Contact", "About", "Logout"]
        tableView.tableFooterView = UIView() // Hides empty cells
    }
}
