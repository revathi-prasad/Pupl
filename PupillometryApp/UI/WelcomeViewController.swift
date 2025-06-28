//
//  ViewController.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 11/06/25.
//

//import UIKit
//
//class ViewController: UIViewController {
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        // Do any additional setup after loading the view.
//    }
//    
//
//    /*
//    // MARK: - Navigation
//
//    // In a storyboard-based application, you will often want to do a little preparation before navigation
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        // Get the new view controller using segue.destination.
//        // Pass the selected object to the new view controller.
//    }
//    */
//
//}

// WelcomeViewController.swift
import UIKit

class WelcomeViewController: UIViewController {
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var aboutButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Configure title - reduced size to prevent cutoff
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.numberOfLines = 2 // Allow wrapping if needed
        
        // Configure subtitle (if connected)
        subtitleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel?.textColor = .secondaryLabel
        
        // Configure buttons
        [startButton, aboutButton].forEach {
            $0?.layer.cornerRadius = 10
            $0?.clipsToBounds = true
        }
        
        startButton.backgroundColor = .systemBlue
        aboutButton.backgroundColor = .systemGray5
        aboutButton.setTitleColor(.darkText, for: .normal)
    }
    
    @IBAction func startButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "showDemographics", sender: self)
    }
    
    @IBAction func aboutButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "About Pupillometry Assessment",
            message: "This application uses eye tracking technology to assess pupil responses during cognitive tasks. These measurements help screen for neurological markers associated with ADHD and other CNS conditions.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Close", style: .default))
        present(alert, animated: true)
    }
}
