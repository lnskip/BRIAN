//
//  BrainTrainingViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import SCLAlertView
import Firebase
import Reachability

class BrainTrainingViewController: UIViewController, AVAudioPlayerDelegate {
    
    // Firebase
    let databaseRef = Database.database().reference()
    let userID = Auth.auth().currentUser?.uid
    
    // Variables
    var playList = [Int]()
    var currentColor = 0
    var pressCount = 0
    var colorReady = false
    var score = 0
    var highScore = 0
    
    // UI Variables
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet var buttonColors: [UIButton]!
    
    // Sounds
    var sound1Player:AVAudioPlayer!
    var sound2Player:AVAudioPlayer!
    var sound3Player:AVAudioPlayer!
    var sound4Player:AVAudioPlayer!
    
    // Shared custom colors
    let greyColor = Shared.shared.greyColor
    let pinkColor = Shared.shared.pinkColor
    let lightPinkColor = Shared.shared.lightPinkColor
    
    @IBAction func showLeaderBoard(_ sender: Any) {
        
        // Show error message if user doesn't have an internet connection
        let reachability = Reachability()!
        if reachability.connection == .none {
            SCLAlertView().showError("Error", subTitle: "An internet connection is required to view the leaderboard. Connect to the internet and try again.")
        }
            
        else { // User has an internet connection
            
            // Arrays to hold leaderboard data
            var users = [String]()
            var scores = [Int]()
            
            // Gets scores ordered by descending order
            databaseRef.child("Game Scores").queryOrdered(byChild: "Best Score").queryLimited(toLast: 10).observeSingleEvent(of: .value) { (scoreSnapshot) in
                var leaderboardString = "" // Arrays to hold leaderboard values
                var userLoopCount = 0 // Holds how many times the user firebase query loops
                
                // Gets scores and adds to array
                for child in (scoreSnapshot.children) {
                    let snap = child as! DataSnapshot
                    if let scoreDict = snap.value as? [String:AnyObject] {
                        let score = scoreDict["Best Score"] as! Int
                        let user = snap.key as String
                        
                        // Adds leaderboard data to arrays
                        scores.append(score)
                        users.append(user)
                        
                        // Gets display names of users
                        self.databaseRef.child("Users").child(user).observeSingleEvent(of: .value, with: { (userSnapshot) in
                            if let userDict = userSnapshot.value as? [String:AnyObject] {
                                let displayName = userDict["Display Name"] as! String
                                userLoopCount += 1
                                
                                // Replaces user ID's with their display names
                                users[users.index(of: user)!] = displayName
                                
                                // Allows leaderboard to only popup when all highscorers are retrieved
                                if userLoopCount == scoreSnapshot.childrenCount {
                                    
                                    // Reverses arrays so that highscores show with highest at the top
                                    users = users.reversed()
                                    scores = scores.reversed()
                                    
                                    // Creates a string to display the top scorers
                                    for user in users {
                                        
                                        var leaderboardPlace = String(users.index(of: user)!+1)
                                        if leaderboardPlace == "1" {
                                            leaderboardPlace = leaderboardPlace + "st. "
                                        }
                                        else if leaderboardPlace == "2" {
                                            leaderboardPlace = leaderboardPlace + "nd. "
                                        }
                                        else if leaderboardPlace == "3" {
                                            leaderboardPlace = leaderboardPlace + "rd. "
                                        }
                                        else {
                                            leaderboardPlace = leaderboardPlace + "th. "
                                        }
                                        
                                        
                                        if leaderboardString == "" {
                                            leaderboardString.append(leaderboardPlace + user + " (" + String(scores[users.index(of: user)!]) + ")")
                                        }
                                        else {
                                            leaderboardString.append("\n" + leaderboardPlace + user + " (" + String(scores[users.index(of: user)!]) + ")")
                                        }
                                    }
                                    
                                    // Shows leaderboard
                                    SCLAlertView().showInfo("Leaderboard", subTitle: leaderboardString)
                                }
                            }
                        })
                    }
                }
            }
        }
    }
    
    @IBAction func buttonColorsPressed(_ sender: Any) {
        
        // Plays sound for button pressed
        if colorReady == true && pressCount < playList.count {
            let button = sender as! UIButton
            switch button.tag {
            case 1: // Red Button
                sound1Player.play()
                checkColorPressed(colorPressed: 1)
                break
            case 2: // Yellow Button
                sound2Player.play()
                checkColorPressed(colorPressed: 2)
                break
            case 3: // Blue Button
                sound3Player.play()
                checkColorPressed(colorPressed: 3)
                break
            case 4: // Green Button
                sound4Player.play()
                checkColorPressed(colorPressed: 4)
                break
            default:
                break
            }
        }
    }
    
    @IBAction func play(_ sender: Any) {
        scoreLabel.text = "Score: 0" // Resets score label text
        playButton.isHidden = true // Hides play button whilst playing
        infoLabel.isHidden = true // Hides info label whilst playing
        disableColors() // Disables user interactions whilst color is highlighting
        resetColors() // Removes the grey off of the images
        
        // Plays random color after gives user short delay to prepare
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(450)) {
            let randomColor = Int(arc4random_uniform(4) + 1)
            self.playList.append(randomColor)
            self.playNextColor()
        }
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
    
    func checkColorPressed(colorPressed: Int) {
        
        // Checks the order the colors were pressed against order they were played
        if colorReady == true {
            if colorPressed == playList[pressCount] { // If user pressed correct color
                if pressCount == playList.count - 1 { // End of playlist
                    
                    // Gives user short delay between highlights
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(450)) {
                        self.nextRound()
                    }
                }
                pressCount += 1 // Adds 1 to press count
            }
            else { // User pressed incorrect color - game over
                
                // Updates highscore in Firebase if score > highscore
                if score > highScore {
                    updateHighScore()
                }
                else {
                    scoreLabel.text = "Highscore: " + String(highScore) // Resets score label
                }
                restartGame() // Restarts the game
            }
        }
    }
    
    func getHighScore() {
        
        // Get user's high score for the brain training game
        databaseRef.child("Game Scores").child(userID!).observeSingleEvent(of: .value, with: {
            (snapshot) in
            if let dict = snapshot.value as? [String: AnyObject] {
                if dict["Best Score"] != nil {
                    self.highScore = dict["Best Score"] as! Int
                    self.scoreLabel.text = "Highscore: " + String(self.highScore)
                }
                else {
                    self.highScore = 0
                    self.scoreLabel.text = "Highscore: N/A"
                }
            }
            else {
                self.highScore = 0
                self.scoreLabel.text = "Highscore: N/A"
            }
        })
    }
    
    func updateHighScore() {
        
        // Updates highscore in Firebase
        self.databaseRef.child("Game Scores").child(userID!).updateChildValues(["Best Score": score], withCompletionBlock: { (error, ref) in
            if error != nil {
                SCLAlertView().showError("Error", subTitle: (error?.localizedDescription)!)
            }
        })
        
        // Updates highscore text in app
        highScore = score
        if highScore != 0 {
            scoreLabel.text = "New Highscore: " + String(highScore)
        }
        else {
            // Sets score label with highscore
            scoreLabel.text = "Highscore: N/A"
        }
    }
    
    func restartGame() {
        
        // Resets game
        infoLabel.text = "Game over. You scored " + String(score) + ", play again?"
        score = 0
        pressCount = 0
        currentColor = 0
        playList = []
        infoLabel.isHidden = false
        playButton.isHidden = false
        disableColors()
        greyOutColors()
    }
    
    func nextRound() {
        
        // Sets up next round
        score += 1
        scoreLabel.text = "Score: " + String(score)
        pressCount = 0
        currentColor = 0
        disableColors()
        
        // Random number to select random color
        var randomColor = Int(arc4random_uniform(4) + 1)
        
        // If randomColor is same as previous color then change it so there is no repeated colors
        if randomColor == playList[playList.count-1] {
            if playList[playList.count-1] == 1 || playList[playList.count-1] == 2 {
                randomColor += 1
            }
            else {
                randomColor -= 1
            }
        }
        playList.append(randomColor)
        playNextColor()
    }
    
    func audioSetup() {
        
        // Sets up audio files
        let soundFilePath1 = Bundle.main.path(forResource: "1", ofType: "wav")
        let soundFileURL1 = URL(fileURLWithPath: soundFilePath1!)
        
        let soundFilePath2 = Bundle.main.path(forResource: "2", ofType: "wav")
        let soundFileURL2 = URL(fileURLWithPath: soundFilePath2!)
        
        let soundFilePath3 = Bundle.main.path(forResource: "3", ofType: "wav")
        let soundFileURL3 = URL(fileURLWithPath: soundFilePath3!)
        
        let soundFilePath4 = Bundle.main.path(forResource: "4", ofType: "wav")
        let soundFileURL4 = URL(fileURLWithPath: soundFilePath4!)
        
        do {
            try sound1Player = AVAudioPlayer(contentsOf: soundFileURL1)
            try sound2Player = AVAudioPlayer(contentsOf: soundFileURL2)
            try sound3Player = AVAudioPlayer(contentsOf: soundFileURL3)
            try sound4Player = AVAudioPlayer(contentsOf: soundFileURL4)
        }
        catch {
            SCLAlertView().showError("Error", subTitle: "Audio files could not be set up correctly.")
        }
        
        sound1Player.delegate = self
        sound2Player.delegate = self
        sound3Player.delegate = self
        sound4Player.delegate = self
        
        sound1Player.numberOfLoops = 0
        sound2Player.numberOfLoops = 0
        sound3Player.numberOfLoops = 0
        sound4Player.numberOfLoops = 0
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if currentColor <= playList.count - 1 {
            playNextColor()
        }
        else {
            if playButton.isHidden == true { // User is playing game
                enableColors()
                resetColors()
            }
            else { // User is not playing/has just lost
                greyOutColors()
            }
        }
    }
    
    func playNextColor() {
        
        // Plays the next color
        let selectedColor = playList[currentColor]
        switch selectedColor {
        case 1: // Red Button
            sound1Player.play()
            highlightColor(tag: 1)
            break
        case 2: // Yellow Button
            sound2Player.play()
            highlightColor(tag: 2)
            break
        case 3: // Blue Button
            sound3Player.play()
            highlightColor(tag: 3)
            break
        case 4: // Green Button
            sound4Player.play()
            highlightColor(tag: 4)
            break
        default:
            break
        }
        
        currentColor += 1
    }
    
    func highlightColor(tag: Int) {
        
        // Highlights the pressed color
        switch tag {
        case 1:
            resetColors()
            buttonColors[tag - 1].setImage(#imageLiteral(resourceName: "RedPressed"), for: .normal)
        case 2:
            resetColors()
            buttonColors[tag - 1].setImage(#imageLiteral(resourceName: "YellowPressed"), for: .normal)
        case 3:
            resetColors()
            buttonColors[tag - 1].setImage(#imageLiteral(resourceName: "BluePressed"), for: .normal)
        case 4:
            resetColors()
            buttonColors[tag - 1].setImage(#imageLiteral(resourceName: "GreenPressed"), for: .normal)
        default:
            break
        }
    }
    
    func resetColors() {
        
        // Resets the buttons to their original images (without the highlight)
        buttonColors[0].setImage(#imageLiteral(resourceName: "Red"), for: .normal)
        buttonColors[1].setImage(#imageLiteral(resourceName: "Yellow"), for: .normal)
        buttonColors[2].setImage(#imageLiteral(resourceName: "Blue"), for: .normal)
        buttonColors[3].setImage(#imageLiteral(resourceName: "Green"), for: .normal)
    }
    
    func enableColors() {
        
        // Enables color buttons
        colorReady = true
        for color in buttonColors {
            color.isUserInteractionEnabled = true
        }
    }
    
    func disableColors() {
        
        // Disables color buttons
        colorReady = false
        for color in buttonColors {
            color.isUserInteractionEnabled = false
        }
    }
    
    func greyOutColors() {
        
        // Grey out colors
        buttonColors[0].setImage(#imageLiteral(resourceName: "Red").tinted(with: self.greyColor), for: .normal)
        buttonColors[1].setImage(#imageLiteral(resourceName: "Yellow").tinted(with: self.greyColor), for: .normal)
        buttonColors[2].setImage(#imageLiteral(resourceName: "Blue").tinted(with: self.greyColor), for: .normal)
        buttonColors[3].setImage(#imageLiteral(resourceName: "Green").tinted(with: self.greyColor), for: .normal)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        greyOutColors() // Greys out colors
        disableColors() // Disables colors until game starts
        audioSetup() // Sets up audio files
        addNavigationBarImage() // Sets navigation bar image
        getHighScore() // Gets highscore
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        infoLabel.text = "Press the play button to begin!" // Sets the info label text
    }
}
