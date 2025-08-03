////
////  DemographicsViewController.swift
////  PupillometryApp
////
////  Created by Revathi Prasad on 10/06/25.
////
//
////import UIKit
////
////class DemographicsViewController: UIViewController {
////
////    override func viewDidLoad() {
////        super.viewDidLoad()
////
////        // Do any additional setup after loading the view.
////    }
////    
////
////    /*
////    // MARK: - Navigation
////
////    // In a storyboard-based application, you will often want to do a little preparation before navigation
////    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
////        // Get the new view controller using segue.destination.
////        // Pass the selected object to the new view controller.
////    }
////    */
////
////}
//// DemographicsViewController.swift
//import UIKit
//
//class DemographicsViewController: UIViewController {
//    @IBOutlet weak var nameTextField: UITextField!
//    @IBOutlet weak var ageTextField: UITextField!
//    @IBOutlet weak var genderSegmentedControl: UISegmentedControl!
//    // Remove individual button outlets
////    @IBOutlet weak var maleButton: UIButton!
////    @IBOutlet weak var femaleButton: UIButton!
////    @IBOutlet weak var otherButton: UIButton!
//    @IBOutlet weak var previousDiagnosisTextField: UITextField!
//    @IBOutlet weak var currentMedicationsTextField: UITextField!
//    @IBOutlet weak var continueButton: UIButton!
//    
//    private var selectedGender: String?
//    private let sessionManager = PupillometryManager.shared
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupUI()
//        setupKeyboardDismissal()
//        setupTextFields()
//    }
//    
//    private func setupUI() {
//        // Configure text fields
//        [nameTextField, ageTextField, previousDiagnosisTextField, currentMedicationsTextField].forEach {
//            $0?.layer.borderWidth = 1.0
//            $0?.layer.borderColor = UIColor.lightGray.cgColor
//            $0?.layer.cornerRadius = 8.0
//        }
//        
////        // Configure gender buttons
////        [maleButton, femaleButton, otherButton].forEach {
////            $0?.layer.cornerRadius = 8.0
////            $0?.backgroundColor = .systemGray6
////            $0?.setTitleColor(.darkText, for: .normal)
////        }
//        
//        // Configure continue button
//        continueButton.layer.cornerRadius = 8.0
//        updateContinueButtonState()
//    }
//    
//    private func setupKeyboardDismissal() {
//            // Add tap gesture to dismiss keyboard when tapping outside text fields
//            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
//            tapGesture.cancelsTouchesInView = false  // Allows other UI elements to receive touches
//            view.addGestureRecognizer(tapGesture)
//        }
//        
//    @objc private func dismissKeyboard() {
//        view.endEditing(true)
//    }
//    
//    private func setupTextFields() {
//            // Set up placeholders
//            nameTextField.placeholder = "Full Name"
//            ageTextField.placeholder = "Age"
//            previousDiagnosisTextField.placeholder = "Previous Diagnosis (Optional)"
//            currentMedicationsTextField.placeholder = "Current Medications (Optional)"
//            
//            // Set keyboard types
//            ageTextField.keyboardType = .numberPad
//            nameTextField.keyboardType = .default
//            previousDiagnosisTextField.keyboardType = .default
//            currentMedicationsTextField.keyboardType = .default
//            
//            // Set return key types
//            nameTextField.returnKeyType = .next
//            ageTextField.returnKeyType = .next
//            previousDiagnosisTextField.returnKeyType = .next
//            currentMedicationsTextField.returnKeyType = .done
//            
//            // Set delegates
//            nameTextField.delegate = self
//            ageTextField.delegate = self
//            previousDiagnosisTextField.delegate = self
//            currentMedicationsTextField.delegate = self
//            
//            // Add toolbar with Done button for number pad
//            addDoneButtonToNumberPad()
//        }
//        
//    // MARK: - Done Button for Number Pad
//    private func addDoneButtonToNumberPad() {
//        let toolbar = UIToolbar()
//        toolbar.sizeToFit()
//        
//        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
//        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
//        
//        toolbar.items = [flexibleSpace, doneButton]
//        ageTextField.inputAccessoryView = toolbar
//    }
//    
//    @IBAction func genderSelectionChanged(_ sender: UISegmentedControl) {
//        let selectedIndex = sender.selectedSegmentIndex
//        switch selectedIndex {
//        case 0: selectedGender = "Male"
//        case 1: selectedGender = "Female"
//        case 2: selectedGender = "Other"
//        default: selectedGender = nil
//        }
//        
//        updateContinueButtonState()
//    }
//    
//    @IBAction func continueButtonTapped(_ sender: UIButton) {
//        guard let name = nameTextField.text, !name.isEmpty,
//              let ageText = ageTextField.text, !ageText.isEmpty,
//              let age = Int(ageText),
//              let gender = selectedGender else {
//            
//            showValidationAlert()
//            return
//        }
//        
//        // Create demographic data
//        let demographics = SessionData.DemographicData(
//            age: age,
//            gender: gender,
//            previousDiagnosis: previousDiagnosisTextField.text,
//            medications: currentMedicationsTextField.text
//        )
//        
//        // Save to session
//        sessionManager.updateDemographics(demographics)
//        
//        // Navigate to camera setup
//        performSegue(withIdentifier: "showCameraSetup", sender: self)
//    }
//    
//    private func showValidationAlert() {
//            let alert = UIAlertController(title: "Missing Information",
//                                        message: "Please fill in your name, age, and select gender to continue.",
//                                        preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .default))
//            present(alert, animated: true)
//        }
//    
//    private func updateContinueButtonState() {
//        let isNameValid = !(nameTextField.text?.isEmpty ?? true)
//        let isAgeValid = ageTextField.text?.isEmpty == false && Int(ageTextField.text ?? "") != nil
//        let isGenderSelected = selectedGender != nil
//        
//        continueButton.isEnabled = isNameValid && isAgeValid && isGenderSelected
//        continueButton.alpha = continueButton.isEnabled ? 1.0 : 0.5
//    }
//    
//    @IBAction func textFieldDidChange(_ sender: UITextField) {
//        updateContinueButtonState()
//    }
//}
//
//  DemographicsViewController.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 10/06/25.
//

import UIKit

class DemographicsViewController: UIViewController {
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var ageTextField: UITextField!
    @IBOutlet weak var genderSegmentedControl: UISegmentedControl!
    @IBOutlet weak var previousDiagnosisTextField: UITextField!
    @IBOutlet weak var currentMedicationsTextField: UITextField!
    @IBOutlet weak var continueButton: UIButton!
    
    private var selectedGender: String?
    private let sessionManager = PupillometryManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📱 DemographicsViewController: viewDidLoad started")
        
        // Add safety checks for all outlets
        guard nameTextField != nil else {
            print("❌ nameTextField outlet not connected!")
            return
        }
        guard ageTextField != nil else {
            print("❌ ageTextField outlet not connected!")
            return
        }
        guard continueButton != nil else {
            print("❌ continueButton outlet not connected!")
            return
        }
        
        print("✅ All outlets connected successfully")
        
        setupUI()
        setupKeyboardDismissal()
        setupTextFields()
        
        print("📱 DemographicsViewController: viewDidLoad completed")
    }
    
    private func setupUI() {
        // Configure text fields
        [nameTextField, ageTextField, previousDiagnosisTextField, currentMedicationsTextField].forEach {
            $0?.layer.borderWidth = 1.0
            $0?.layer.borderColor = UIColor.lightGray.cgColor
            $0?.layer.cornerRadius = 8.0
            $0?.backgroundColor = UIColor.darkGray
            $0?.textColor = UIColor.white
        }
        
        // Set placeholder text with proper visibility
        nameTextField?.attributedPlaceholder = NSAttributedString(
            string: "Enter your name",
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        ageTextField?.attributedPlaceholder = NSAttributedString(
            string: "Enter your age",
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        previousDiagnosisTextField?.attributedPlaceholder = NSAttributedString(
            string: "Previous diagnosis (optional)",
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        currentMedicationsTextField?.attributedPlaceholder = NSAttributedString(
            string: "Current medications (optional)",
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        
        // Configure gender segmented control for dark theme
        genderSegmentedControl?.backgroundColor = UIColor.darkGray
        genderSegmentedControl?.selectedSegmentTintColor = UIColor.systemBlue
        genderSegmentedControl?.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        genderSegmentedControl?.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        
        // Configure continue button
        continueButton.layer.cornerRadius = 8.0
        updateContinueButtonState()
    }
    
    // MARK: - Keyboard Dismissal Setup
    private func setupKeyboardDismissal() {
        // Add tap gesture to dismiss keyboard when tapping outside text fields
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false  // Allows other UI elements to receive touches
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Text Fields Setup
    private func setupTextFields() {
        // Set up placeholders
        nameTextField.placeholder = "Full Name"
        ageTextField.placeholder = "Age"
        previousDiagnosisTextField.placeholder = "Previous Diagnosis (Optional)"
        currentMedicationsTextField.placeholder = "Current Medications (Optional)"
        
        // Set keyboard types
        ageTextField.keyboardType = .numberPad
        nameTextField.keyboardType = .default
        previousDiagnosisTextField.keyboardType = .default
        currentMedicationsTextField.keyboardType = .default
        
        // Set return key types
        nameTextField.returnKeyType = .next
        ageTextField.returnKeyType = .next
        previousDiagnosisTextField.returnKeyType = .next
        currentMedicationsTextField.returnKeyType = .done
        
        // Set delegates
        nameTextField.delegate = self
        ageTextField.delegate = self
        previousDiagnosisTextField.delegate = self
        currentMedicationsTextField.delegate = self
        
        // Add toolbar with Done button for number pad
        addDoneButtonToNumberPad()
    }
    
    // MARK: - Done Button for Number Pad
    private func addDoneButtonToNumberPad() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        
        toolbar.items = [flexibleSpace, doneButton]
        ageTextField.inputAccessoryView = toolbar
    }
    
    @IBAction func genderSelectionChanged(_ sender: UISegmentedControl) {
        let selectedIndex = sender.selectedSegmentIndex
        switch selectedIndex {
        case 0: selectedGender = "Male"
        case 1: selectedGender = "Female"
        case 2: selectedGender = "Other"
        default: selectedGender = nil
        }
        
        updateContinueButtonState()
    }
    
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        guard let name = nameTextField.text, !name.isEmpty,
              let ageText = ageTextField.text, !ageText.isEmpty,
              let age = Int(ageText),
              let gender = selectedGender else {
            
            // Show validation alert
            showValidationAlert()
            return
        }
        
        // Create demographic data
        let demographics = SessionData.DemographicData(
            age: age,
            gender: gender,
            previousDiagnosis: previousDiagnosisTextField.text,
            medications: currentMedicationsTextField.text
        )
        
        // Save to session
        sessionManager.updateDemographics(demographics)
        
        // Navigate to camera setup
        performSegue(withIdentifier: "showCameraSetup", sender: self)
    }
    
    private func showValidationAlert() {
        let alert = UIAlertController(title: "Missing Information",
                                    message: "Please fill in your name, age, and select gender to continue.",
                                    preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateContinueButtonState() {
        let isNameValid = !(nameTextField.text?.isEmpty ?? true)
        let isAgeValid = ageTextField.text?.isEmpty == false && Int(ageTextField.text ?? "") != nil
        let isGenderSelected = selectedGender != nil
        
        continueButton.isEnabled = isNameValid && isAgeValid && isGenderSelected
        continueButton.alpha = continueButton.isEnabled ? 1.0 : 0.5
    }
    
    @IBAction func textFieldDidChange(_ sender: UITextField) {
        // Add debug logging and safety checks
        print("🔤 DemographicsViewController: Text field changed - \(sender.placeholder ?? "unknown")")
        
        // Defensive programming - ensure we don't crash
        DispatchQueue.main.async { [weak self] in
            self?.updateContinueButtonState()
        }
    }
}

// MARK: - UITextFieldDelegate
extension DemographicsViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Add safety checks for outlets
        guard nameTextField != nil, ageTextField != nil, 
              previousDiagnosisTextField != nil, currentMedicationsTextField != nil else {
            print("⚠️ DemographicsViewController: Text field outlets not connected properly")
            textField.resignFirstResponder()
            return true
        }
        
        switch textField {
        case nameTextField:
            ageTextField.becomeFirstResponder()
        case ageTextField:
            previousDiagnosisTextField.becomeFirstResponder()
        case previousDiagnosisTextField:
            currentMedicationsTextField.becomeFirstResponder()
        case currentMedicationsTextField:
            textField.resignFirstResponder()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Optional: Add border highlight when editing
        textField.layer.borderColor = UIColor.systemBlue.cgColor
        textField.layer.borderWidth = 2.0
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Reset border when done editing
        textField.layer.borderColor = UIColor.lightGray.cgColor
        textField.layer.borderWidth = 1.0
        
        // Update continue button state
        updateContinueButtonState()
    }
    
    // Limit age input to reasonable numbers
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Add safety checks to prevent crashes
        guard let currentText = textField.text else { return true }
        guard range.location + range.length <= currentText.count else { return false }
        
        if textField == ageTextField {
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            
            // Only allow numbers
            if !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            
            // Limit age to reasonable range (1-150)
            if let range = Range(range, in: currentText) {
                let updatedText = currentText.replacingCharacters(in: range, with: string)
                if let age = Int(updatedText), age > 150 {
                    return false
                }
            }
        }
        
        return true
    }
}
