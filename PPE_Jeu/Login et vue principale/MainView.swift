import SwiftUI

struct MainView: View {
    @AppStorage("storedUsername") var storedUsername: String = ""
    @State private var currentPlayer: Player? = nil
    @State private var isLoadingPlayer: Bool = true
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if isLoadingPlayer {
                    ProgressView("Chargement du joueur…")
                } else if let player = currentPlayer {
                    NavigationLink(destination: MenuMultijoueurView()) {
                        Text("Multijoueur")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    NavigationLink(destination: CardsCollectionView()) {
                        Text("Collection")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    NavigationLink(destination: HealthChallengesView(player: player)) {
                        Text("Défis")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                } else {
                    Text("Erreur lors du chargement du joueur.")
                }
            }
            .onAppear {
                loadCurrentPlayer()
                // Demande d'autorisation HealthKit dès le premier lancement
                if !UserDefaults.standard.bool(forKey: "HealthKitAuthorized") {
                    healthKitManager.requestAuthorization { success, error in
                        if success {
                            UserDefaults.standard.set(true, forKey: "HealthKitAuthorized")
                        } else {
                            print("Erreur d'autorisation HealthKit : \(error?.localizedDescription ?? "inconnue")")
                        }
                    }
                }
            }
        }
    }
    
    func loadCurrentPlayer() {
        FirestoreManager().fetchPlayer(username: storedUsername) { player in
            DispatchQueue.main.async {
                self.currentPlayer = player
                self.isLoadingPlayer = false
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
