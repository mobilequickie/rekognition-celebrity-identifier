//
//  AppDelegate.swift
//  Celebrity
//
//  Created by Hills, Dennis on 5/6/19.
//  Copyright © 2019 Hills, Dennis. All rights reserved.
//
import UIKit
import AWSCore

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize Identity Provider (Cognito Identity Pool)
        // This is required to call Amazon Rekognition directly
        let credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: .USWest2,
            identityPoolId: "us-west-2:<YOUR-COGNITO-IDENTITY-ID>")
        let configuration = AWSServiceConfiguration(
            region: .USWest2,
            credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}
}

