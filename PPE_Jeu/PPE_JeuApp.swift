//
//  AppDelegate.swift
//  PPE_Jeu
//
//  Created by Youssef Ait Elourf on 03/04/2025.
//


import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct PPE_JeuApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  
  var body: some Scene {
    WindowGroup {
      NavigationView {
        LoginView()
      }
    }
  }
}