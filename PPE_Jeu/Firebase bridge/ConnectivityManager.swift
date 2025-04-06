//
//  ConnectivityManager.swift
//  PPE_Jeu
//
//  Created by Youssef Ait Elourf on 03/04/2025.
//


import Network
import Combine

class ConnectivityManager: ObservableObject {
    @Published var isConnected: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitor")
    
    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = (path.status == .satisfied)
                if !self.isConnected {
                    print("Aucune connexion Internet")
                }
            }
        }
        monitor.start(queue: queue)
    }
}