//
//  ForumViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import Firebase
import UIKit
import SCLAlertView
import JGProgressHUD
import TBEmptyDataSet
import Reachability
import SwiftLocation

class ForumViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // Arrays to hold post data
    var users = [String]()
    var posts = [String]()
    var postIDs = [String]()
    var scores = [Int]()
    var timeStamps = [Double]()
    var replyCounts = [Int]()
    
    // Shared custom colors
    let greyColor = Shared.shared.greyColor
    let pinkColor = Shared.shared.pinkColor
    let lightPinkColor = Shared.shared.lightPinkColor
    
    // UI Variables
    @IBOutlet var forumView: UIView!
    @IBOutlet weak var forumTableView: UITableView!
    
    let reachability = Reachability()! // Allows internet connection to be checked
    var currentFeedSort = "Newest" // Holds the current sorting option
    let activityIndicator:UIActivityIndicatorView = UIActivityIndicatorView(); // Activity Indicator
    let loading = JGProgressHUD(style: .dark) // Loading screen
    
    // Firebase
    var databaseRef = Database.database().reference()
    let userID = Auth.auth().currentUser?.uid
    
    // Configures pull to refresh feature
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(ForumViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        refreshControl.tintColor = pinkColor // Sets refresh indicator color
        
        return refreshControl
    }()
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        // Hides refresh indicator
        refreshControl.endRefreshing()
        self.forumTableView.contentOffset = CGPoint.zero
        
        // Shows a loading screen
        loading.textLabel.text = "Reloading Posts"
        loading.show(in: self.view)
        clearFeed() // Clears news feed
        
        // Sorts feed depending on current sorting option
        if currentFeedSort == "Newest" {
            loadFeed(orderMethod: "Timestamp")
        }
        else if currentFeedSort == "Hottest" {
            loadFeed(orderMethod: "Score")
        }
    }
    
    @IBAction func sort(_ sender: Any) {
        // Displays alert message allowing the user to sort the feed
        
        let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
        let alert = SCLAlertView(appearance: appearance)
        alert.addButton("Newest") {
            
            // Only resort feed if it isn't already by newest
            if self.currentFeedSort != "Newest" {
                
                // Shows a loading screen
                self.loading.textLabel.text = "Sorting Posts"
                self.loading.show(in: self.view)
                
                self.currentFeedSort = "Newest" // Updates sorting option
                self.clearFeed() // Clears news feed
                self.loadFeed(orderMethod: "Timestamp") // Loads news feed, sorting by newest first
            }
        }
        alert.addButton("Hottest") {
            
            // Only resort feed if it isn't already by hottest
            if self.currentFeedSort != "Hottest" {
                
                // Shows a loading screen
                self.loading.textLabel.text = "Sorting Posts"
                self.loading.show(in: self.view)
                
                self.currentFeedSort = "Hottest" // Updates sorting option
                self.clearFeed() // Clears news feed
                self.loadFeed(orderMethod: "Score") // Loads news feed, sorting by highest score first
            }
        }
        alert.showEdit("Sort By", subTitle: "How would you like to sort the posts?")
        
    }
    
    func addNavigationBarImage(){
        
        // Sets navigation bar image
        let image = #imageLiteral(resourceName: "NavTitle")
        let imageView = UIImageView(image: image)
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        imageView.frame = titleView.bounds
        titleView.addSubview(imageView)
        
        navigationItem.titleView = imageView
    }
    
    func clearFeed() {
        
        // Clears news feed
        self.users.removeAll()
        self.posts.removeAll()
        self.postIDs.removeAll()
        self.scores.removeAll()
        self.timeStamps.removeAll()
        self.replyCounts.removeAll()
        self.forumTableView.reloadData()
    }
    
    
    func loadFeed(orderMethod: String) {
        
        // Gets posts ordered by Timestamp
        databaseRef.child("Posts").queryOrdered(byChild: orderMethod).queryLimited(toLast: 100).observe(.value) { (snapshot) in
            
            // Gets post data
            for child in (snapshot.children) {
                let snap = child as! DataSnapshot
                
                // Only add post data to arrays if it doesn't already exist
                if !self.postIDs.contains(snap.key) {
                    self.postIDs.append(snap.key)
                    let postLocationInArrays = self.postIDs.index(of: snap.key)!
                    if let dict = snap.value as? [String:AnyObject] {
                        
                        // Adds post users/texts/scores/reply counts/timestamps to arrays
                        self.posts.append(dict["Text"] as! String)
                        self.scores.append(dict["Score"] as! Int)
                        self.users.append(dict["User"] as! String)
                        self.replyCounts.append(dict["Reply Count"] as! Int)
                        self.timeStamps.append(dict["Timestamp"] as! Double)
                        
                        // Adds post data to table row
                        self.forumTableView.insertRows(at: [IndexPath(row: self.users.count-1-postLocationInArrays, section: 0)], with: .automatic)
                        
                        // Reloads forum table rows
                        DispatchQueue.main.async(execute: { () -> Void in
                            self.forumTableView.reloadRows(at: [IndexPath(row: self.users.count-1-postLocationInArrays, section: 0)], with: .automatic)
                            self.forumTableView.endUpdates() // Updates TBEmptyDataSet
                        })
                    }
                }
                    
                    // If post data already exists then update post data
                else {
                    let postLocationInArrays = self.postIDs.index(of: snap.key)!
                    if let dict = snap.value as? [String:AnyObject] {
                        var dataUpdated = false
                        
                        // Updates post users/texts/scores/reply counts/timestamps arrays if different
                        if  self.posts[postLocationInArrays] != dict["Text"] as! String {
                            self.posts[postLocationInArrays] = dict["Text"] as! String
                            dataUpdated = true
                        }
                        if  self.scores[postLocationInArrays] != dict["Score"] as! Int {
                            self.scores[postLocationInArrays] = dict["Score"] as! Int
                            dataUpdated = true
                        }
                        if  self.users[postLocationInArrays] != dict["User"] as! String {
                            self.users[postLocationInArrays] = dict["User"] as! String
                            dataUpdated = true
                        }
                        if  self.replyCounts[postLocationInArrays] != dict["Reply Count"] as! Int {
                            self.replyCounts[postLocationInArrays] = dict["Reply Count"] as! Int
                            dataUpdated = true
                        }
                        if  self.timeStamps[postLocationInArrays] != dict["Timestamp"] as! Double {
                            self.timeStamps[postLocationInArrays] = dict["Timestamp"] as! Double
                            dataUpdated = true
                        }
                        
                        // Reloads forum table rows if any data was updated
                        if dataUpdated == true {
                            DispatchQueue.main.async(execute: { () -> Void in
                                self.forumTableView.reloadRows(at: [IndexPath(row: (self.postIDs.count-1) - postLocationInArrays, section: 0)], with: .automatic)
                            })
                        }
                    }
                }
            }
        }
        self.loading.dismiss(afterDelay: 0.5) // Dismisses loading screen after 0.5 seconds once everything's loaded
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ForumCell = tableView.dequeueReusableCell(withIdentifier: "ForumCell", for: indexPath) as! ForumCell
        
        // Loads posts in reversed order so that newest/hottest appear at top
        let user = users[(self.users.count - 1) - indexPath.row]
        let post = posts[(self.posts.count - 1) - indexPath.row]
        let postID = postIDs[(self.postIDs.count - 1) - indexPath.row]
        let score = scores[(self.scores.count - 1) - indexPath.row]
        let timeStamp = timeStamps[(self.timeStamps.count - 1) - indexPath.row]
        let replyCount = replyCounts[(self.replyCounts.count - 1) - indexPath.row]
        
        
        cell.configure(postID: postID, postUser: user, postText: post, postScore: score, postTimeStamp: timeStamp, postReplyCount: String(replyCount))
        
        return cell
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        self.forumTableView.estimatedRowHeight = 110.0
        return UITableViewAutomaticDimension // Adjusts cell size depending on text
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            
            if reachability.connection == .wifi || reachability.connection == .cellular { // User has internet connection
                if userID == users[(self.users.count - 1) - indexPath.row] { // User is creator of post
                    
                    // Delete post from Firebase
                    let postID = postIDs[(self.postIDs.count - 1) - indexPath.row]
                    databaseRef.child("Posts").child(postID).removeValue { error, _ in
                        if error != nil {
                            SCLAlertView().showError("Error",  subTitle: (error?.localizedDescription)!)
                        }
                        else {
                            
                            // Delete post from table
                            self.users.remove(at: (self.users.count - 1) - indexPath.row)
                            self.posts.remove(at: (self.posts.count - 1) - indexPath.row)
                            self.postIDs.remove(at: (self.postIDs.count - 1) - indexPath.row)
                            self.scores.remove(at: (self.scores.count - 1) - indexPath.row)
                            self.timeStamps.remove(at: (self.timeStamps.count - 1) - indexPath.row)
                            self.replyCounts.remove(at: (self.replyCounts.count - 1) - indexPath.row)
                            self.forumTableView.reloadData()
                        }
                    }
                }
                else { // User is not creator of post
                    SCLAlertView().showError("Error",  subTitle: "You do not have permisson to delete posts that are not your own.")
                }
            }
            else { // User does not have internet connection
                SCLAlertView().showError("Error",  subTitle: "An internet connection is required to delete posts. Connect to the internet and try again.")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TBEmptyDataSet
        self.forumTableView.emptyDataSetDataSource = self as TBEmptyDataSetDataSource
        self.forumTableView.emptyDataSetDelegate = self as TBEmptyDataSetDelegate
        
        self.forumTableView.addSubview(self.refreshControl) // Adds refresh control feature
        self.forumTableView.tableFooterView = UIView() // Hides empty cells
        
        // Shows a loading screen
        loading.textLabel.text = "Retrieving Posts"
        loading.show(in: self.view)
        
        loadFeed(orderMethod: "Timestamp") // Loads news feed, sorting by newest first
        
        addNavigationBarImage() // Sets navigation bar image
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        // Resets the selectedPostID that's shared between view controllers each time view appears
        Shared.shared.selectedPostID = ""
    }
}

extension ForumViewController: TBEmptyDataSetDataSource, TBEmptyDataSetDelegate {
    
    // Configures TBEmptyDataSet
    func titleForEmptyDataSet(in scrollView: UIScrollView) -> NSAttributedString? {
        
        // Gives a title depending on their internet connection
        var titleString = ""
        if reachability.connection == .wifi || reachability.connection == .cellular {
            titleString = "No posts. Be the first to write a post!"
        }
        else {
            titleString = "Unable to load posts. Connect to the internet and try again."
        }
        let titleAttribute = [ NSAttributedStringKey.foregroundColor: greyColor ]
        let titleAS = NSAttributedString(string: titleString, attributes: titleAttribute)
        return titleAS
    }
    func imageForEmptyDataSet(in scrollView: UIScrollView) -> UIImage? {
        return #imageLiteral(resourceName: "EmptyMessages")
    }
    func emptyDataSetShouldDisplay(in scrollView: UIScrollView) -> Bool {
        var noPosts = false
        if forumTableView.numberOfRows(inSection: 0) == 0 {
            noPosts = true
        }
        else {
            noPosts = false
        }
        return noPosts
    }
    func emptyDataSetScrollEnabled(in scrollView: UIScrollView) -> Bool {
        return true
    }
    func emptyDataSetDidTapEmptyView(in scrollView: UIScrollView) {
        
        // Only allow user to press to add post if they have internet
        if reachability.connection == .wifi || reachability.connection == .cellular {
            let viewController = self.storyboard?.instantiateViewController(withIdentifier: "newPost")
            self.present(viewController!, animated: true, completion: nil)
        }
    }
}
