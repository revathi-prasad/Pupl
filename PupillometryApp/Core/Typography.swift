//
//  Typography.swift
//  PupillometryApp
//
//  Modern typography system matching clinical UI design
//

import UIKit

extension UIFont {
    
    // MARK: - App Typography System
    
    // Headers and Titles
    static let appTitle = UIFont.systemFont(ofSize: 28, weight: .bold)
    static let sectionTitle = UIFont.systemFont(ofSize: 22, weight: .semibold)
    static let cardTitle = UIFont.systemFont(ofSize: 18, weight: .semibold)
    
    // Body Text
    static let bodyLarge = UIFont.systemFont(ofSize: 17, weight: .regular)
    static let bodyMedium = UIFont.systemFont(ofSize: 15, weight: .regular)
    static let bodySmall = UIFont.systemFont(ofSize: 13, weight: .regular)
    
    // Interactive Elements
    static let buttonPrimary = UIFont.systemFont(ofSize: 17, weight: .semibold)
    static let buttonSecondary = UIFont.systemFont(ofSize: 15, weight: .medium)
    static let buttonSmall = UIFont.systemFont(ofSize: 13, weight: .medium)
    
    // Data and Metrics
    static let dataLarge = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .medium)
    static let dataMedium = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
    static let dataSmall = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    
    // Captions and Labels
    static let caption = UIFont.systemFont(ofSize: 12, weight: .medium)
    static let footnote = UIFont.systemFont(ofSize: 11, weight: .regular)
    
    // Clinical/Medical specific
    static let clinicalTitle = UIFont.systemFont(ofSize: 20, weight: .semibold)
    static let clinicalBody = UIFont.systemFont(ofSize: 16, weight: .regular)
    static let clinicalCaption = UIFont.systemFont(ofSize: 12, weight: .medium)
}

extension UIColor {
    
    // MARK: - App Color System
    
    // Primary Colors (matching screenshot design)
    static let appBlue = UIColor.systemBlue
    static let appNavy = UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0)
    
    // Background Colors
    static let appBackground = UIColor.black
    static let cardBackground = UIColor.darkGray
    static let lightCardBackground = UIColor(white: 0.15, alpha: 1.0)
    
    // Text Colors
    static let primaryText = UIColor.white
    static let secondaryText = UIColor.lightGray
    static let tertiaryText = UIColor.gray
    
    // Accent Colors
    static let successGreen = UIColor.systemGreen
    static let warningOrange = UIColor.systemOrange
    static let errorRed = UIColor.systemRed
    static let infoBlue = UIColor.systemBlue
}

// MARK: - UI Component Extensions

extension UIButton {
    
    @objc func styleAsPrimary() {
        backgroundColor = .appBlue
        setTitleColor(.white, for: .normal)
        titleLabel?.font = .buttonPrimary
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
    }
    
    @objc func styleAsSecondary() {
        backgroundColor = .clear
        setTitleColor(.appBlue, for: .normal)
        titleLabel?.font = .buttonSecondary
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.appBlue.cgColor
    }
    
    @objc func styleAsCardButton() {
        backgroundColor = .cardBackground
        setTitleColor(.primaryText, for: .normal)
        titleLabel?.font = .buttonSecondary
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.lightGray.cgColor
    }
}

extension UILabel {
    
    @objc func styleAsTitle() {
        font = .appTitle
        textColor = .primaryText
        textAlignment = .center
    }
    
    @objc func styleAsSectionTitle() {
        font = .sectionTitle
        textColor = .primaryText
        textAlignment = .left
    }
    
    @objc func styleAsCardTitle() {
        font = .cardTitle
        textColor = .primaryText
        textAlignment = .left
    }
    
    @objc func styleAsBody() {
        font = .bodyMedium
        textColor = .primaryText
        textAlignment = .left
        numberOfLines = 0
    }
    
    @objc func styleAsCaption() {
        font = .caption
        textColor = .secondaryText
        textAlignment = .left
    }
    
    @objc func styleAsClinicalTitle() {
        font = .clinicalTitle
        textColor = .primaryText
        textAlignment = .center
    }
    
    @objc func styleAsClinicalBody() {
        font = .clinicalBody
        textColor = .primaryText
        textAlignment = .left
        numberOfLines = 0
    }
}

extension UIView {
    
    @objc func styleAsCard() {
        backgroundColor = .cardBackground
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.lightGray.cgColor
    }
    
    @objc func styleAsLightCard() {
        backgroundColor = .lightCardBackground
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.darkGray.cgColor
    }
}