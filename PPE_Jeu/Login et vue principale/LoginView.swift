//
//  LoginView.swift
//  PPE_Jeu
//
//  Created by Youssef Ait Elourf on 03/04/2025.
//


import SwiftUI

struct LoginView: View {
    @AppStorage("storedUsername") private var storedUsername: String = ""
    @State private var username: String = ""
    @State private var errorMessage: String?
    @State private var isLoggedIn: Bool = false
    
    @ObservedObject var connectivity = ConnectivityManager()
    private let firestoreManager = FirestoreManager()
    
    var body: some View {
        if !connectivity.isConnected {
            VStack {
                Text("Pas de connexion Internet")
                    .font(.title)
                    .padding()
                Text("Veuillez vous connecter pour utiliser l'application.")
                    .multilineTextAlignment(.center)
            }
        } else if isLoggedIn || !storedUsername.isEmpty {
            MainView()
        } else {
            VStack(spacing: 20) {
                Text("Entrez votre nom d'utilisateur")
                    .font(.headline)
                TextField("Nom d'utilisateur", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                Button("Continuer") {
                    loginUser()
                }
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
    }
    
    func loginUser() {
        // On normalise le username pour que la comparaison soit insensible à la casse
        let normalizedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
        
        firestoreManager.fetchPlayer(username: normalizedUsername) { player in
            if let player = player {
                print("Utilisateur trouvé: \(player.username)")
                storedUsername = player.username
                isLoggedIn = true
            } else {
                firestoreManager.addPlayer(username: normalizedUsername, currency: 800, exp: 0) { error in
                    if let error = error {
                        errorMessage = "Erreur: \(error.localizedDescription)"
                    } else {
                        print("Nouvel utilisateur créé")
                        storedUsername = normalizedUsername
                        isLoggedIn = true
                    }
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}