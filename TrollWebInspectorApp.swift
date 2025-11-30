import UIKit
import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 1. Create the window matching the screen bounds
        let window = UIWindow(frame: UIScreen.main.bounds)
        
        // 2. Initialize the SwiftUI View
        let contentView = ContentView()
        
        // 3. Set the Root View Controller
        window.rootViewController = UIHostingController(rootView: contentView)
        
        // 4. Show the Window (Crucial step!)
        self.window = window
        window.makeKeyAndVisible()
        
        return true
    }
}