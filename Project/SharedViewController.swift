//
//  SharedViewController.swift
//  Project
//
//  Created by Leon Inskip on 16/10/2017.
//  Copyright © 2017 LeonInskip. All rights reserved.
//

import UIKit
import JTAppleCalendar

// Allows variables to be shared between view controllers
final class Shared {
    static let shared = Shared()
    var selectedPostID : String!
    var selectedDate: Date!
    var greyColor = UIColor(colorWithHexValue: 0xC7C7CD)
    var pinkColor = UIColor(colorWithHexValue: 0xFF6F6E)
    var lightPinkColor = UIColor(colorWithHexValue: 0xFF9098)
}

// Extensions
extension NSDate {
    
    // Gets the difference of an NSDate and current date and displays in string format
    func since() -> String {
        let seconds = abs(NSDate().timeIntervalSince1970 - self.timeIntervalSince1970)
        if seconds <= 120 {
            return "Just now"
        }
        let minutes = Int(floor(seconds / 60))
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }
        if hours < 48 {
            return "Yesterday"
        }
        let days = hours / 24
        if days < 30 {
            return "\(days)d ago"
        }
        if days < 14 {
            return "Last week"
        }
        let months = days / 30
        if months == 1 {
            return "Last month"
        }
        if months < 12 {
            return "\(months)mo ago"
        }
        let years = months / 12
        if years == 1 {
            return "Last year"
        }
        return "\(years)y ago"
    }
}

extension UIColor {
    
    // Allows for hex values to be used to set color
    convenience init(colorWithHexValue value: Int, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((value & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((value & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(value & 0x0000FF) / 255.0,
            alpha: alpha
        )
    }
}

extension UIImage {
    
    // Allows for images to be resized
    func resized(withPercentage percentage: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: size.width * percentage, height: size.height * percentage)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    // Allows for images to be recolored
    func tinted(with color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        color.set()
        withRenderingMode(.alwaysTemplate)
            .draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

extension UIView {
    
    // Animations
    func shakeAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.duration = 0.5
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0 ]
        layer.add(animation, forKey: "shake")
    }
    func bounceAnimation() {
        self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       usingSpringWithDamping: CGFloat(0.20),
                       initialSpringVelocity: CGFloat(4.0),
                       options: UIViewAnimationOptions.allowUserInteraction,
                       animations: {
                        self.transform = CGAffineTransform.identity
        },
                       completion: { Void in() }
        )
    }
}

extension NSMutableAttributedString {
    
    // Allows strings to be bold/normal in same label
    @discardableResult func normal(_ text: String) -> NSMutableAttributedString {
        let normal = NSAttributedString(string: text)
        append(normal)
        
        return self
    }
    @discardableResult func bold(_ text: String, withLabel label: UILabel) -> NSMutableAttributedString {
        
        //generate the bold font
        var font: UIFont = UIFont(name: label.font.fontName , size: label.font.pointSize)!
        font = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold) ?? font.fontDescriptor, size: font.pointSize)
        
        //generate attributes
        let attrs: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: font]
        let boldString = NSMutableAttributedString(string:text, attributes: attrs)
        
        //append the attributed text
        append(boldString)
        
        return self
    }
}
