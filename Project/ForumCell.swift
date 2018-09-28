//
//  ForumCell.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import UIKit
import Kingfisher
import SCLAlertView
import Firebase
import Reachability

public class ForumCell: UITableViewCell {
    
    // Firebase
    let userID = Auth.auth().currentUser?.uid
    let databaseRef = Database.database().reference()
    
    var postID = "" // Holds post ID of cell
    
    // Shared custom colors
    let greyColor = Shared.shared.greyColor
    let pinkColor = Shared.shared.pinkColor
    let lightPinkColor = Shared.shared.lightPinkColor
    
    // UI Variables
    @IBOutlet weak var profilePicture: UIImageView!
    @IBOutlet weak var displayName: UILabel!
    @IBOutlet weak var postText: UITextView!
    @IBOutlet weak var postScore: UITextField!
    @IBOutlet weak var likePostButton: UIButton!
    @IBOutlet weak var dislikePostButton: UIButton!
    @IBOutlet weak var timeStamp: UITextField!
    @IBOutlet weak var replyCount: UITextField!
    
    // Updates post scores in Firebase
    @IBAction func likePost(_ sender: Any) {
        if self.likePostButton.image(for: .normal) == #imageLiteral(resourceName: "ThumbsUp2") {
            scorePost(score: 1)
        }
        else {
            scorePost(score: 1, unscore: true)
        }
        likePostButton.bounceAnimation()
    }
    @IBAction func dislikePost(_ sender: Any) {
        if self.dislikePostButton.image(for: .normal) == #imageLiteral(resourceName: "ThumbsDown2") {
            scorePost(score: -1)
        }
        else {
            scorePost(score: -1, unscore: true)
        }
        dislikePostButton.bounceAnimation()
    }
    
    func scorePost(score: Int?, unscore: Bool = false) {
        
        let reachability = Reachability()! // Allows internet connection to be checked
        
        // Only allow user to score posts if they have an internet connection
        if reachability.connection == .none {
            SCLAlertView().showError("Error", subTitle: "An internet connection is required to score posts. Connect to the internet and try again.")
        }
        else {
            
            if replyCount.isHidden == false { // On main forum page
                
                // Checks if user has already liked/disliked post
                databaseRef.child("Posts").child(postID).child("User Scorings").observeSingleEvent(of: .value, with: {
                    (snapshot) in
                    
                    // Gets the current users current score of post
                    var usersCurrentScoreOfPost: Int? = nil
                    if let dict = snapshot.value as? [String: AnyObject]
                    {
                        usersCurrentScoreOfPost = dict[self.userID!] as? Int
                    }
                    
                    // Updates score by -1 or +1 in firebase
                    let scoreDatabaseRef = self.databaseRef.child("Posts").child(self.postID).child("Score")
                    scoreDatabaseRef.observeSingleEvent(of: .value, with: {
                        (snapshot) in
                        var value = snapshot.value as! Int
                        
                        // If the user's new score is different to their current score OR if user hasn't already scored the post
                        if usersCurrentScoreOfPost != score {
                            
                            // Sets value + 1 or -1 depending on whether like or dislike is selected
                            if usersCurrentScoreOfPost == 0 || usersCurrentScoreOfPost == nil {
                                value += 1 * score!
                            }
                            else {
                                value += 1 * (score! * 2)
                            }
                        }
                            
                            // Removes value given, i.e unscoring the post if unscore == true
                        else {
                            if unscore == true {
                                value -= 1 * score!
                            }
                        }
                        scoreDatabaseRef.setValue(value)
                    })
                    
                    // Makes a record of the score given (Like = 1, dislike = -1) for each post the user has rated
                    var recordScore: [String : Any]
                    if unscore == false {
                        recordScore = [self.userID!: score!]
                    }
                    else { // Sets the record of score given to 0, i.e. unliking the post
                        recordScore = [self.userID!: 0]
                    }
                    
                    // Saves a record of user liking the post in Firebase
                    self.databaseRef.child("Posts").child(self.postID).child("User Scorings").updateChildValues(recordScore, withCompletionBlock: { (error, ref) in
                        if error != nil {
                            SCLAlertView().showSuccess("Error", subTitle: (error?.localizedDescription)!)
                        }
                    })
                })
            }
                
            else { // On reply to forum post page
                if let selectedPostID = Shared.shared.selectedPostID { // Gets selectedPostID (parent post ID)
                    
                    // Checks if user has already liked/disliked post
                    databaseRef.child("Posts").child(selectedPostID).child("Replies").child(postID).child("User Scorings").observeSingleEvent(of: .value, with: {
                        (snapshot) in
                        
                        // Gets the current users current score of post
                        var usersCurrentScoreOfPost: Int? = nil
                        if let dict = snapshot.value as? [String: AnyObject]
                        {
                            usersCurrentScoreOfPost = dict[self.userID!] as? Int
                        }
                        
                        // Updates score by -1 or +1 in firebase
                        let scoreDatabaseRef = self.databaseRef.child("Posts").child(selectedPostID).child("Replies").child(self.postID).child("Score")
                        scoreDatabaseRef.observeSingleEvent(of: .value, with: {
                            (snapshot) in
                            var value = snapshot.value as! Int
                            
                            // If the user's new score is different to their current score OR if user hasn't already scored the post
                            if usersCurrentScoreOfPost != score {
                                
                                // Sets value + 1 or -1 depending on whether like or dislike is selected
                                if usersCurrentScoreOfPost == 0 || usersCurrentScoreOfPost == nil {
                                    value += 1 * score!
                                }
                                else {
                                    value += 1 * (score! * 2)
                                }
                            }
                                
                                // Removes value given, i.e unscoring the post if unscore == true
                            else {
                                if unscore == true {
                                    value -= 1 * score!
                                }
                            }
                            scoreDatabaseRef.setValue(value)
                        })
                        
                        // Makes a record of the score given (Like = 1, dislike = -1) for each post the user has rated
                        var recordScore: [String : Any]
                        if unscore == false {
                            recordScore = [self.userID!: score!]
                        }
                        else { // Sets the record of score given to 0, i.e. unliking the post
                            recordScore = [self.userID!: 0]
                        }
                        
                        // Saves a record of user liking the post in Firebase
                        self.databaseRef.child("Posts").child(selectedPostID).child("Replies").child(self.postID).child("User Scorings").updateChildValues(recordScore, withCompletionBlock: { (error, ref) in
                            if error != nil {
                                SCLAlertView().showSuccess("Error", subTitle: (error?.localizedDescription)!)
                            }
                        })
                    })
                }
            }
        }
    }
    
    func highlightPostScoreButtons() {
        
        // Updates current like/dislike button on post
        var scoreDatabaseRef = databaseRef
        if replyCount.isHidden == false { // On main forum page
            scoreDatabaseRef = databaseRef.child("Posts").child(postID).child("User Scorings")
        }
        else { // On reply to forum post page
            if let selectedPostID = Shared.shared.selectedPostID { // Gets selectedPostID (parent post ID)
                scoreDatabaseRef = databaseRef.child("Posts").child(selectedPostID).child("Replies").child(self.postID).child("User Scorings")
            }
        }
        scoreDatabaseRef.observeSingleEvent(of: .value) { (snapshot) in
            if let dict = snapshot.value as? [String: AnyObject]
            {
                let usersCurrentScoreOfPost = dict[self.userID!] as? Int
                if usersCurrentScoreOfPost == 0 || usersCurrentScoreOfPost == nil {
                    self.likePostButton.setImage(#imageLiteral(resourceName: "ThumbsUp2"), for: .normal)
                    self.dislikePostButton.setImage(#imageLiteral(resourceName: "ThumbsDown2"), for: .normal)
                }
                if usersCurrentScoreOfPost == 1 {
                    self.likePostButton.setImage(#imageLiteral(resourceName: "ThumbsUp").tinted(with: self.lightPinkColor), for: .normal)
                    self.dislikePostButton.setImage(#imageLiteral(resourceName: "ThumbsDown2"), for: .normal)
                }
                if usersCurrentScoreOfPost == -1 {
                    self.likePostButton.setImage(#imageLiteral(resourceName: "ThumbsUp2"), for: .normal)
                    self.dislikePostButton.setImage(#imageLiteral(resourceName: "ThumbsDown").tinted(with: self.lightPinkColor), for: .normal)
                }
            }
            else {
                self.likePostButton.setImage(#imageLiteral(resourceName: "ThumbsUp2"), for: .normal)
                self.dislikePostButton.setImage(#imageLiteral(resourceName: "ThumbsDown2"), for: .normal)
            }
        }
    }
    
    public func configure(postID:String, postUser:String, postText:String, postScore:Int, postTimeStamp:Double, postReplyCount:String) {
        
        // Gets default profile picture from Firebase (preventing re-used cell profile picture bug)
        var url = URL(string: "https://firebasestorage.googleapis.com/v0/b/brain-recovery-app.appspot.com/o/profile_pictures%2Fassets%2Fdefault_profile_pic.png?alt=media&token=820de109-8d88-49a2-9ce7-e607253e35fd")
        
        // Gets user data from post
        self.databaseRef.child("Users").child(postUser).observe(.value) { (snapshot) in
            if let dict = snapshot.value as? [String: AnyObject] {
                
                self.displayName.text = dict["Display Name"] as? String // Sets display name
                self.displayName.textColor = self.pinkColor
                
                // If user has a profile picture then display this instead
                if dict["Profile Picture"] as? String != nil {
                    url = URL(string: dict["Profile Picture"] as! String) // Gets profile picture URL
                }
                
            }
            else { // If there is no user data then user deleted account
                self.displayName.text = "(User Deleted)" // Sets display name
                self.displayName.textColor = UIColor.lightGray
            }
            self.profilePicture.kf.setImage(with: url) // Displays profile picture and also caches it for effeciency
        }
        
        // Turns timestamp into string describing difference between date from Firebase and current date (e.g. "1m ago") to array
        var timeStampDate = NSDate()
        timeStampDate = NSDate(timeIntervalSince1970: postTimeStamp)
        let timeStampText = timeStampDate.since()
        
        // Configures remaining cell variables
        self.postID = postID
        self.postText.text = postText
        self.postScore.text = String(postScore)
        self.timeStamp.text = timeStampText
        self.replyCount.text = postReplyCount + " Replies"
        
        // Updates current like/dislike button on post
        highlightPostScoreButtons()
    }
    
    // Shares selected post ID
    @IBAction func selectedPost(_ sender: Any) {
        Shared.shared.selectedPostID = self.postID
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        // Turns profile picture into a circle
        let radius = profilePicture.frame.width / 2
        profilePicture.layer.cornerRadius = radius
        profilePicture.layer.masksToBounds = true
    }
    
    override public func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
