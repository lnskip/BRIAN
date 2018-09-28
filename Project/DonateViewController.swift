//
//  DonateViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import Foundation
import UIKit

class DonateTableViewController: UITableViewController {
    // Variables
    var charities = [String]()
    var descriptions = [String]()
    var identities = [String]()
    var myIndex = 0
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // Makes table size = number of charities
        return charities.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
       
        // Sets names/images to cells
        let cell = tableView.dequeueReusableCell(withIdentifier: "charitiesCell", for: indexPath)
        cell.textLabel!.text = charities[indexPath.row]
        
        let imageName = UIImage(named: charities[indexPath.row])
        cell.imageView?.image = imageName
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
       
        // Lanches selected donation page for charities within Safari
        myIndex = indexPath.row
        performSegue(withIdentifier: "websiteLauncher", sender: self)
        
        var url = URL(string: "")
        if (myIndex == 0) {
            url = URL(string: "https://www.justgiving.com/4w350m3/donation/direct/charity/185696#MessageAndAmount")
        }
        else if (myIndex == 1) {
            url = URL(string: "http://www.brainandspine.org.uk/donate-online")
        }
        else if (myIndex == 2) {
            url = URL(string: "https://www.headway.org.uk/donate/")
        }
        else if (myIndex == 3) {
            url = URL(string: "https://www.stroke.org.uk/donate/change-story?utm_source=website&utm_medium=homepage%20block&utm_campaign=Change%20the%20Story")
        }
        else if (myIndex == 4) {
            url = URL(string: "http://shop.thechildrenstrust.org.uk/donate?m=oneoff&_ga=2.53048936.1739320108.1501475372-1402739428.1501211052")
        }
        else if (myIndex == 5) {
            url = URL(string: "http://www.paulforbrainrecovery.co.uk/donate/")
        }
        UIApplication.shared.open(url! as URL, options: [:], completionHandler: nil)
        navigationController?.popViewController(animated: false)
    }
    
    override func viewDidLoad() {
        // Sets charities array values
        charities = ["The Brain Charity", "Brain & Spine Foundation",
                     "Headway", "Stroke Association", "The Children's Trust", "Paul For Brain Recovery"]
        tableView.tableFooterView = UIView()
    }
}
