//
//  ReplyToForumPostViewController.swift
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

class ReplyToForumPostViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // Firebase
    var databaseRef = Database.database().reference()
    let userID = Auth.auth().currentUser?.uid
    
    // Arrays to hold post data
    var users = [String]()
    var posts = [String]()
    var postIDs = [String]()
    var scores = [Int]()
    var timeStamps = [Double]()
    
    // Shared custom colors
    let greyColor = Shared.shared.greyColor
    let pinkColor = Shared.shared.pinkColor
    let lightPinkColor = Shared.shared.lightPinkColor
    
    // UI Variables
    @IBOutlet var replyToForumPostView: UIView!
    @IBOutlet weak var replyToForumPostTableView: UITableView!
    @IBOutlet weak var replyUserProfilePicture: UIImageView!
    
    let reachability = Reachability()! // Allows internet connection to be checked
    var currentFeedSort = "Newest" // Holds the current sorting option
    let activityIndicator:UIActivityIndicatorView = UIActivityIndicatorView(); // Activity Indicator
    let loading = JGProgressHUD(style: .dark) // Loading screen
    
    // Configures pull to refresh feature
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(ReplyToForumPostViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        refreshControl.tintColor = pinkColor // Sets refresh indicator color
        
        return refreshControl
    }()
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        // Hides refresh indicator
        refreshControl.endRefreshing()
        self.replyToForumPostTableView.contentOffset = CGPoint.zero
        
        // Shows a loading screen
        loading.textLabel.text = "Updating Replies"
        loading.show(in: self.view)
        clearFeed() // Clears news feed
        
        // Sorts feed by timestamp
        loadFeed(orderMethod: "Timestamp")
    }
    
    func clearFeed() {
        
        // Clears news feed
        self.users.removeAll()
        self.posts.removeAll()
        self.postIDs.removeAll()
        self.scores.removeAll()
        self.timeStamps.removeAll()
        self.replyToForumPostTableView.reloadData()
    }
    
    func tableViewScrollToBottom(animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
            let numberOfSections = self.replyToForumPostTableView.numberOfSections
            let numberOfRows = self.replyToForumPostTableView.numberOfRows(inSection: numberOfSections-1)
            
            if numberOfRows > 0 {
                let indexPath = IndexPath(row: numberOfRows-1, section: (numberOfSections-1))
                self.replyToForumPostTableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
            }
        }
    }
    
    func loadFeed(orderMethod: String) {
        
        // Gets parent post of post
        if let parentPostID = Shared.shared.selectedPostID {
            
            // Gets posts ordered by order method (timestamp/newest or score/hottest)
            databaseRef.child("Posts").child(parentPostID).child("Replies").queryOrdered(byChild: orderMethod).observe(.value) { (snapshot) in
                
                // Gets post data
                for child in (snapshot.children) {
                    let snap = child as! DataSnapshot
                    
                    // Only add post data to arrays if it doesn't already exist
                    if !self.postIDs.contains(snap.key) {
                        self.postIDs.append(snap.key)
                        let postLocationInArrays = self.postIDs.index(of: snap.key)
                        if let dict = snap.value as? [String:AnyObject] {
                            
                            
                            // Adds post users/texts/scores/timestamps to arrays
                            self.posts.append(dict["Text"] as! String)
                            self.scores.append(dict["Score"] as! Int)
                            self.users.append(dict["User"] as! String)
                            self.timeStamps.append(dict["Timestamp"] as! Double)
                            
                            // Adds post data to table row
                            self.replyToForumPostTableView.insertRows(at: [IndexPath(row: postLocationInArrays!, section: 0)], with: UITableViewRowAnimation.automatic)
                            
                            // Reloads forum table rows
                            DispatchQueue.main.async(execute: { () -> Void in
                                self.replyToForumPostTableView.reloadRows(at: [IndexPath(row: postLocationInArrays!, section: 0)], with: .automatic)
                                self.replyToForumPostTableView.endUpdates() // Updates TBEmptyDataSet
                            })
                        }
                    }
                        
                        // If post data already exists then update post data
                    else {
                        let postLocationInArrays = self.postIDs.index(of: snap.key)
                        if let dict = snap.value as? [String:AnyObject] {
                            var dataUpdated = false
                            
                            // Updates post users/texts/scores/timestamps arrays if different
                            if  self.posts[postLocationInArrays!] != dict["Text"] as! String {
                                self.posts[postLocationInArrays!] = dict["Text"] as! String
                                dataUpdated = true
                            }
                            if  self.scores[postLocationInArrays!] != dict["Score"] as! Int {
                                self.scores[postLocationInArrays!] = dict["Score"] as! Int
                                dataUpdated = true
                            }
                            if  self.users[postLocationInArrays!] != dict["User"] as! String {
                                self.users[postLocationInArrays!] = dict["User"] as! String
                                dataUpdated = true
                            }
                            if  self.timeStamps[postLocationInArrays!] != dict["Timestamp"] as! Double {
                                self.timeStamps[postLocationInArrays!] = dict["Timestamp"] as! Double
                                dataUpdated = true
                            }
                            
                            // Reloads forum table rows if any data was updated
                            if dataUpdated == true {
                                DispatchQueue.main.async(execute: { () -> Void in
                                    self.replyToForumPostTableView.reloadRows(at: [IndexPath(row: postLocationInArrays!, section: 0)], with: .automatic)
                                })
                            }
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
        let user = users[indexPath.row]
        let post = posts[indexPath.row]
        let postID = postIDs[indexPath.row]
        let score = scores[indexPath.row]
        let timeStamp = timeStamps[indexPath.row]
        
        cell.configure(postID: postID, postUser: user, postText: post, postScore: score, postTimeStamp: timeStamp, postReplyCount: "")
        return cell
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        self.replyToForumPostTableView.estimatedRowHeight = 110.0
        return UITableViewAutomaticDimension // Adjusts cell size depending on text
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            
            if reachability.connection == .wifi || reachability.connection == .cellular { // User has internet connection
                
                // Gets parent post
                if let parentPostID = Shared.shared.selectedPostID {
                    
                    if userID == users[indexPath.row] { // User is creator of post
                        
                        // Delete post from Firebase
                        let postID = postIDs[indexPath.row]
                        databaseRef.child("Posts").child(parentPostID).child("Replies").child(postID).removeValue { error, _ in
                            if error != nil {
                                SCLAlertView().showError("Error",  subTitle: (error?.localizedDescription)!)
                            }
                            else {
                                
                                // Delete post from table
                                self.users.remove(at: indexPath.row)
                                self.posts.remove(at: indexPath.row)
                                self.postIDs.remove(at: indexPath.row)
                                self.scores.remove(at: indexPath.row)
                                self.timeStamps.remove(at: indexPath.row)
                                self.replyToForumPostTableView.reloadData()
                                
                                // Updates reply count of parent post
                                let replyCountDatabaseRef = self.databaseRef.child("Posts").child(parentPostID).child("Reply Count")
                                replyCountDatabaseRef.observeSingleEvent(of: .value, with: {
                                    (snapshot) in
                                    var value = snapshot.value as! Int
                                    value -= 1
                                    replyCountDatabaseRef.setValue(value)
                                })
                            }
                        }
                    }
                    else { // User is not creator of post
                        SCLAlertView().showError("Error",  subTitle: "You do not have permisson to delete posts that are not your own.")
                    }
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
        self.replyToForumPostTableView.emptyDataSetDataSource = self as TBEmptyDataSetDataSource
        self.replyToForumPostTableView.emptyDataSetDelegate = self as TBEmptyDataSetDelegate
        
        self.replyToForumPostTableView.addSubview(self.refreshControl) // Adds refresh control feature
        self.replyToForumPostTableView.tableFooterView = UIView() // Hides empty cells
        
        // Shows a loading screen
        loading.textLabel.text = "Retrieving Replies"
        loading.show(in: self.view)
        
        loadFeed(orderMethod: "Timestamp") // Loads news feed, sorting by newest first
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        tableViewScrollToBottom(animated: true) // Scrolls to bottom of table
        
        // Gets users profile picture from Firebase
        self.databaseRef.child("Users").child(userID!).observe(.value) { (snapshot) in
            if let dict = snapshot.value as? [String: AnyObject] {
                let usersProfilePictureURL = dict["Profile Picture"] as? String
                
                // If user has a profile picture then use this instead of default profile picture image in cell
                if usersProfilePictureURL != nil {
                    let url = URL(string: usersProfilePictureURL!)
                    self.replyUserProfilePicture.kf.setImage(with: url) // Displays profile picture and also caches it for effeciency
                    
                    // Makes profile picture a circle
                    self.replyUserProfilePicture.layer.cornerRadius = self.replyUserProfilePicture.frame.size.width/2
                    self.replyUserProfilePicture.clipsToBounds = true
                }
            }
        }
    }
}

extension ReplyToForumPostViewController: TBEmptyDataSetDataSource, TBEmptyDataSetDelegate {
    
    // Configures TBEmptyDataSet
    func titleForEmptyDataSet(in scrollView: UIScrollView) -> NSAttributedString? {
        
        // Gives a title depending on their internet connection
        var titleString = ""
        if reachability.connection == .wifi || reachability.connection == .cellular {
            titleString = "No replies. Be the first to write a reply!"
        }
        else {
            titleString = "Unable to load replies. Connect to the internet and try again."
        }
        let titleAttribute = [ NSAttributedStringKey.foregroundColor: greyColor ]
        let titleAS = NSAttributedString(string: titleString, attributes: titleAttribute)
        return titleAS
    }
    func imageForEmptyDataSet(in scrollView: UIScrollView) -> UIImage? {
        return #imageLiteral(resourceName: "EmptyMessages")
    }
    func emptyDataSetShouldDisplay(in scrollView: UIScrollView) -> Bool {
        var noReplies = false
        if replyToForumPostTableView.numberOfRows(inSection: 0) == 0 {
            noReplies = true
        }
        else {
            noReplies = false
        }
        return noReplies
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

