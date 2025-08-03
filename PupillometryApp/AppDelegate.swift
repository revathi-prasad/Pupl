////
////  AppDelegate.swift
////  PupillometryApp
////
////  Created by Revathi Prasad on 29/05/25.
////
//
//import UIKit
//import CoreData
//import Firebase
//
//@main
//class AppDelegate: UIResponder, UIApplicationDelegate {
//
//
//
////    private func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
////        // Override point for customization after application launch.
////        return true
////    }
//    internal func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//            // Initialize Firebase
//            FirebaseApp.configure()
//            return true
//        }
//
//    // MARK: UISceneSession Lifecycle
//
//    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
//        // Called when a new scene session is being created.
//        // Use this method to select a configuration to create the new scene with.
//        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
//    }
//
//    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
//        // Called when the user discards a scene session.
//        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
//        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
//    }
//    
//    
//
//    // MARK: - Core Data stack
//
//    lazy var persistentContainer: NSPersistentContainer = {
//        /*
//         The persistent container for the application. This implementation
//         creates and returns a container, having loaded the store for the
//         application to it. This property is optional since there are legitimate
//         error conditions that could cause the creation of the store to fail.
//        */
//        let container = NSPersistentContainer(name: "PupillometryApp")
//        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
//            if let error = error as NSError? {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                 
//                /*
//                 Typical reasons for an error here include:
//                 * The parent directory does not exist, cannot be created, or disallows writing.
//                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
//                 * The device is out of space.
//                 * The store could not be migrated to the current model version.
//                 Check the error message to determine what the actual problem was.
//                 */
//                fatalError("Unresolved error \(error), \(error.userInfo)")
//            }
//        })
//        return container
//    }()
//
//    // MARK: - Core Data Saving support
//
//    func saveContext () {
//        let context = persistentContainer.viewContext
//        if context.hasChanges {
//            do {
//                try context.save()
//            } catch {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                let nserror = error as NSError
//                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
//            }
//        }
//    }
//
//}
//
import UIKit
import CoreData
import Firebase

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Crash Logging for Non-Debug Mode
    private let crashLogger = CrashLogger()
    private let memoryMonitor = MemoryPressureMonitor()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // CRITICAL: Setup crash logging FIRST before anything else
        setupCrashHandling()
        
        // Check if app was previously crashed and log details
        crashLogger.checkForPreviousCrash()
        
        // Initialize Firebase on main thread (required for UIApplication.delegate access)
        FirebaseApp.configure()
        
        // Start memory pressure monitoring
        memoryMonitor.startMonitoring()
        
        // Force dark mode app-wide for black background
        if #available(iOS 13.0, *) {
            UIApplication.shared.windows.forEach { window in
                window.overrideUserInterfaceStyle = .dark
            }
        }
        
        // Test MediaPipe integration - moved to background to prevent blocking
        DispatchQueue.global(qos: .utility).async {
            SimpleMediaPipeTest.runTest()
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
    
    // MARK: - Memory Warning Handling
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("⚠️ AppDelegate: Memory warning received - app may be terminated soon")
        crashLogger.logMemoryWarning()
        
        // Emergency cleanup
        PupillometryManager.shared.emergencyMemoryCleanup()
        
        // Force garbage collection
        autoreleasepool {
            // Let ARC clean up temporary objects
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        print("🛑 AppDelegate: App will terminate - logging final state")
        crashLogger.logAppTermination()
        saveContext()
    }
    
    // MARK: - Crash Handling Setup
    private func setupCrashHandling() {
        // Setup uncaught exception handler
        NSSetUncaughtExceptionHandler { exception in
            print("💥 UNCAUGHT EXCEPTION: \(exception.name.rawValue)")
            print("💥 Reason: \(exception.reason ?? "Unknown")")
            print("💥 Stack trace: \(exception.callStackSymbols)")
            
            // Log to persistent storage
            CrashLogger.logCrash(type: "Exception", details: [
                "name": exception.name.rawValue,
                "reason": exception.reason ?? "Unknown",
                "stack": exception.callStackSymbols.joined(separator: "\n")
            ])
        }
        
        // Setup signal handler for EXC_BAD_ACCESS, SIGSEGV, etc.
        signal(SIGABRT) { signal in
            print("💥 SIGNAL ABORT (\(signal)) - App crashed")
            CrashLogger.logCrash(type: "Signal", details: ["signal": "\(signal)", "type": "SIGABRT"])
        }
        
        signal(SIGSEGV) { signal in
            print("💥 SEGMENTATION FAULT (\(signal)) - Memory access violation")
            CrashLogger.logCrash(type: "Signal", details: ["signal": "\(signal)", "type": "SIGSEGV"])
        }
        
        signal(SIGBUS) { signal in
            print("💥 BUS ERROR (\(signal)) - Hardware memory error")
            CrashLogger.logCrash(type: "Signal", details: ["signal": "\(signal)", "type": "SIGBUS"])
        }
    }

    // MARK: - Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "PupillometryApp")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("❌ Core Data error: \(error), \(error.userInfo)")
                // Continue without Core Data rather than crashing
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("❌ Core Data save error: \(nserror), \(nserror.userInfo)")
                // Continue without saving rather than crashing
            }
        }
    }
}
