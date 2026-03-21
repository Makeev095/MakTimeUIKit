import UIKit

final class SplashViewController: UIViewController {
    private let logoLabel: UILabel = {
        let l = UILabel()
        l.text = "Makke"
        l.font = Theme.fontDisplay
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .medium)
        a.color = Theme.accent
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        
        view.addSubview(logoLabel)
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            activityIndicator.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 20),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        activityIndicator.startAnimating()
        logoLabel.textColor = Theme.accent
    }
}
