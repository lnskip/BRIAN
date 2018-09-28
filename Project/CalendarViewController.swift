//
//  CalendarViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import UIKit
import JTAppleCalendar
import Firebase
import SwiftRichString
import TBEmptyDataSet
import Reachability
import SCLAlertView

class CalendarViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // Firebase
    let databaseRef = Database.database().reference()
    let userID = Auth.auth().currentUser?.uid
    
    // Variables
    var event = [String]()
    var eventIDs = [String]()
    var selectedDate = Date()
    var orderedEvent = [String]()
    var selectedDateString = "0"
    var hideCell = true
    var dateOnlyFromSelectedDate = ""
    var dateOnlyFromEvent = ""
    var showPlaceholder = true
    
    // Shared custom colors
    let greyColor = Shared.shared.greyColor
    let pinkColor = Shared.shared.pinkColor
    let lightPinkColor = Shared.shared.lightPinkColor
    
    // UI Variables
    @IBOutlet weak var calendarView: JTAppleCalendarView!
    @IBOutlet weak var monthAndYear: UILabel!
    @IBOutlet weak var eventTable: UITableView!
    
    let reachability = Reachability()! // Allows internet connection to be checked
    let formatter = DateFormatter() // Allows dates to be formatted
    
    @IBAction func keyBarButtonPressed(_ sender: Any) {
        if userID != nil {
            let alert = SCLAlertView()
            alert.addTextField("User Key").insertText(String(userID!))
            alert.showInfo("User Key", subTitle: "Sharing this (case-sensitive) key with a user will allow them to send you events: ")
        }
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
    
    // Sets up size of table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return event.count
    }
    
    // Displays events within table cells
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: nil)
        
        // Configure cell view for events
        cell.textLabel?.font =  UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.regular) // Sets text size
        cell.backgroundColor = UIColor.white // Sets background color of cell
        cell.textLabel?.numberOfLines = 0 // Allows cells to contain more than 1 line
        cell.textLabel?.lineBreakMode = .byWordWrapping // Puts remaining string on another line if needed
        
        // Gets the first 10 characters, which is exclusively the date in string format: dd MM yyyy
        dateOnlyFromEvent = String(describing: event[indexPath.row].prefix(10))
        
        // Sorts array in order to display times in ascending order
        orderedEvent = event.sorted { $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedAscending }
        event = orderedEvent
        
        // Gets the rest of the text (minus the first 10 characters) as date is not needed in event description
        let timeAndTextOnlyFromEvent = String(describing: event[indexPath.row].dropFirst(13))
        
        
        // If the event array contains the selected date in dd MM yyyy
        if dateOnlyFromEvent == dateOnlyFromSelectedDate
        {
            // Sets bold style
            let boldStyle = Style.default {
                $0.font = FontAttribute.bold(size: 16)
            }
            // Turns "\nEvent: " and "\nNotes: " bold
            let eventAndNotesAttributedString = timeAndTextOnlyFromEvent.set(styles: boldStyle, pattern: "\n([A-Z])([a-z])([a-z])([a-z])([a-z]): ", options: .caseInsensitive)
            
            // Turns "Time: " text bold
            let timeLabel = "Time: "
            let eventAttributedString = timeLabel.set(styles: boldStyle, pattern: "Time: ", options: .caseInsensitive)
            
            cell.textLabel?.attributedText = eventAttributedString + eventAndNotesAttributedString
            hideCell = false
        }
        else
        {
            hideCell = true
        }
        return cell
    }
    
    // Congigures row heights in order to hide rows if they do not match selected date
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var heightForRow:CGFloat = 0.0
        tableView.estimatedRowHeight = 50.0
        
        if hideCell == true
        {
            heightForRow = 0.0
            return heightForRow
        }
        else
        {
            return UITableViewAutomaticDimension // Adjusts cell size depending on text
        }
    }
    
    // Allows events to be deleted
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if reachability.connection == .wifi || reachability.connection == .cellular { // User has internet connection
            if editingStyle == UITableViewCellEditingStyle.delete {
                
                // Removes the event from Firebase (database)
                databaseRef.child("Events").child(userID!).child(eventIDs[indexPath.row]).removeValue { error, _ in
                    if error != nil {
                        SCLAlertView().showError("Error",  subTitle: (error?.localizedDescription)!)
                    }
                }
                
                // Removes from arrays
                event.remove(at: indexPath.row)
                eventIDs.remove(at: indexPath.row)
                
                // Reloads calendar/table views
                eventTable.reloadData()
                calendarView.reloadData()
            }
        }
        else { // User does not have internet connection
            SCLAlertView().showError("Error",  subTitle: "An internet connection is required to delete events. Connect to the internet and try again.")
        }
    }
    
    public func configureCellView(view: JTAppleCell?, cellState: CellState) {
        guard let validCell = view as? CalendarCell else { return }
        
        // Sets text colors for cells within calendar
        let inMonthColor = UIColor.black
        let outMonthColor = UIColor(colorWithHexValue: 0xb1b1b1)
        let dateWithEventColor = UIColor(colorWithHexValue: 0xff9095)
        
        // Configures font
        validCell.dateLabel.font = UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.light)
        
        // Highlights selected date if it's within selected month
        if cellState.isSelected == true
        {
            validCell.bounceAnimation() // Animates selected cell
            validCell.selectedCell.isHidden = false // Hightlights cell by giving it a colored background
            validCell.dateLabel.textColor = inMonthColor // Sets selected month color
            
            selectedDate = cellState.date // Sets selectedDate to selected date for use in creating an event
            Shared.shared.selectedDate = selectedDate // Shares selectedDate
            formatter.dateFormat = "dd MM yyyy @ HH:mm" // Formats date
            selectedDateString = formatter.string(from: selectedDate) // Converts date to string
            dateOnlyFromSelectedDate = String(describing: selectedDateString.prefix(10)) // Gets only date from selected date
            
        }
            // Configures cells when they are not selected
        else if cellState.isSelected == false
        {
            validCell.selectedCell.isHidden = true // Removes cell background
            
            if cellState.dateBelongsTo == .thisMonth // Date cells within the selected month
            {
                validCell.dateLabel.textColor = inMonthColor // Sets selected month color
            }
                
            else if cellState.dateBelongsTo != .thisMonth // Date cells not within the selected month
            {
                validCell.dateLabel.textColor = outMonthColor // Sets outside selected month color
            }
        }
        // Configures cells which date's have an event
        formatter.dateFormat = "dd MM yyyy"
        let dateFromCells = formatter.string(from: cellState.date)
        for eachEvent in event
        {
            let dateOnlyFromEvent = String(describing: eachEvent.prefix(10))
            if dateOnlyFromEvent == dateFromCells
            {
                if cellState.isSelected == false
                {
                    if cellState.dateBelongsTo == .thisMonth
                    {
                        validCell.dateLabel.textColor = dateWithEventColor
                    }
                    else {
                        validCell.dateLabel.textColor = outMonthColor
                    }
                }
                else
                {
                    validCell.dateLabel.textColor = inMonthColor
                }
                validCell.dateLabel.font = UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.bold)
            }
        }
    }
    
    func configureCalendarView() {
        
        // Pre-selects todays date
        calendarView.selectDates([Date.init()])
        
        // Opens calendar on the current month
        calendarView.scrollToDate(Date.init(), animateScroll: true)
        
        // Sets calendar spacing
        calendarView.minimumLineSpacing = 0
        calendarView.minimumInteritemSpacing = 0
        
        // Displays month and year
        calendarView.visibleDates { (visibleDates) in
            self.configureViewsOfCalendar(from: visibleDates)
        }
    }
    
    func configureViewsOfCalendar(from visibleDates: DateSegmentInfo){
        // Sets up year/month labels
        let date = visibleDates.monthDates.first!.date
        self.formatter.dateFormat = "MMMM yyyy"
        self.monthAndYear.text = self.formatter.string(from: date)
    }
    
    func loadEvents(){
        
        // Loads events from database
        databaseRef.child("Events").child(userID!).observe(.value) { (snapshot) in
            for snap in snapshot.children {
                let eventSnap = snap as! DataSnapshot
                if let dict = eventSnap.value as? [String:AnyObject] {
                    if let eventDetails = dict["Event"] as? String {
                        
                        // Only adds new event to the event array if a duplicate isn't in there
                        if self.event.contains(eventDetails) == false {
                            self.event.append(eventDetails) // Adds events from firebase to event array
                            self.eventIDs.append(eventSnap.key) // Adds event parent ID to eventIDs
                        }
                    }
                }
            }
            
            // Reloads calendar/table views
            self.calendarView.reloadData()
            self.eventTable.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Clears event arrays to remove possibility of users getting previous user's data
        event.removeAll()
        eventIDs.removeAll()
        
        addNavigationBarImage() // Sets navigation bar image
        
        // TBEmptyDataSet
        self.eventTable.emptyDataSetDataSource = self as TBEmptyDataSetDataSource
        self.eventTable.emptyDataSetDelegate = self as TBEmptyDataSetDelegate
        
        event.removeAll() // Clears the array on load to prevent users getting previous user's data
        configureCalendarView() // Configures calendar/table views
        eventTable.tableFooterView = UIView() // Hides empty cells
        
        // Sets selected date as current date
        formatter.dateFormat = "dd MM yyyy" // Formats date
        selectedDateString = formatter.string(from: Date.init()) // Converts date to string
        dateOnlyFromSelectedDate = String(describing: selectedDateString) // Gets only date from selected date
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Refreshes table when it is back in view
        loadEvents() // Fills the event array with Firebase (database) event data
    }
}

extension CalendarViewController: JTAppleCalendarViewDataSource {
    func configureCalendar(_ calendar: JTAppleCalendarView) -> ConfigurationParameters {
        // Sets up the calendar
        formatter.dateFormat = "yyyy MM dd"
        formatter.timeZone = Calendar.current.timeZone
        formatter.locale = Calendar.current.locale
        
        let startDate = formatter.date(from: "2018 01 01")!
        let endDate = formatter.date(from: "2038 12 31")!
        
        let parameters = ConfigurationParameters(startDate: startDate, endDate: endDate)
        return parameters
    }
    
    func calendar(_ calendar: JTAppleCalendarView, willDisplay cell: JTAppleCell, forItemAt date: Date, cellState: CellState, indexPath: IndexPath) {
        let cell = calendar.dequeueReusableJTAppleCell(withReuseIdentifier: "calendarCell", for: indexPath) as! CalendarCell
        cell.dateLabel.text = cellState.text
    }
}

extension CalendarViewController: JTAppleCalendarViewDelegate {
    
    // Displays the cells
    func calendar(_ calendar: JTAppleCalendarView, cellForItemAt date: Date, cellState: CellState, indexPath: IndexPath) -> JTAppleCell {
        let cell = calendar.dequeueReusableJTAppleCell(withReuseIdentifier: "calendarCell", for: indexPath) as! CalendarCell
        configureCellView(view: cell, cellState: cellState)
        
        cell.dateLabel.text = cellState.text
        return cell
    }
    func calendar(_ calendar: JTAppleCalendarView, didSelectDate date: Date, cell: JTAppleCell?, cellState: CellState) {
        configureCellView(view: cell, cellState: cellState)
        calendarView.reloadData()
        showPlaceholder = true
        eventTable.reloadData()
        
    }
    func calendar(_ calendar: JTAppleCalendarView, didDeselectDate date: Date, cell: JTAppleCell?, cellState: CellState) {
        configureCellView(view: cell, cellState: cellState)
    }
    func calendar(_ calendar: JTAppleCalendarView, didScrollToDateSegmentWith visibleDates: DateSegmentInfo) {
        configureViewsOfCalendar(from: visibleDates)
    }
}

extension CalendarViewController: TBEmptyDataSetDataSource, TBEmptyDataSetDelegate {
    
    // Configures TBEmptyDataSet
    func titleForEmptyDataSet(in scrollView: UIScrollView) -> NSAttributedString? {
        
        // Gives a title depending on their internet connection
        var titleString = ""
        if reachability.connection == .wifi || reachability.connection == .cellular {
            titleString = "No events. Add an event! \n\n"
        }
        else {
            titleString = "Unable to load events. Connect to the internet and try again."
        }
        let titleAttribute = [ NSAttributedStringKey.foregroundColor: greyColor ]
        let titleAS = NSAttributedString(string: titleString, attributes: titleAttribute)
        return titleAS
    }
    func imageForEmptyDataSet(in scrollView: UIScrollView) -> UIImage? {
        return #imageLiteral(resourceName: "EmptyEvents")
    }
    func emptyDataSetShouldDisplay(in scrollView: UIScrollView) -> Bool {
        for eachEvent in event {
            if eachEvent.prefix(10) == dateOnlyFromSelectedDate {
                showPlaceholder = false
            }
        }
        return showPlaceholder
    }
    func emptyDataSetScrollEnabled(in scrollView: UIScrollView) -> Bool {
        return true
    }
    func emptyDataSetDidTapEmptyView(in scrollView: UIScrollView) {
        
        // Only allow user to press to add event if they have internet
        if reachability.connection == .wifi || reachability.connection == .cellular {
            let viewController = self.storyboard?.instantiateViewController(withIdentifier: "newEvent")
            self.present(viewController!, animated: true, completion: nil)
        }
    }
}



