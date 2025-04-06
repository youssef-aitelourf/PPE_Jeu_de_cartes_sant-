import SwiftUI
import Foundation
import FirebaseFirestore

struct PlayerRanking: Identifiable {
    let id: String       // Identifiant du document (player)
    let rank: Int        // Rang calculé (1 pour le meilleur, 2 pour le second, etc.)
    let username: String // Nom du joueur
    let exp: Int         // Points d'exp du joueur
    let nbParties: Int   // Nombre de parties jouées
}

struct RankingView: View {
    @ObservedObject var viewModel: CardsViewModel
    @State private var playerRankings: [PlayerRanking] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Classement des joueurs")
                    .font(.largeTitle)
                    .padding(.top)
                
                List(playerRankings) { ranking in
                    RankingRowView(playerRanking: ranking, currentUserId: viewModel.player?.id)
                }
            }
            .navigationBarTitle("Classement", displayMode: .inline)
            .onAppear {
                loadRankings()
            }
        }
    }
    
    func loadRankings() {
        let db = Firestore.firestore()
        db.collection("player")
            .order(by: "exp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Erreur de chargement du classement: \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                
                let tempRankings: [PlayerRanking] = docs.enumerated().compactMap { index, doc in
                    let data = doc.data()
                    guard let username = data["username"] as? String,
                          let exp = data["exp"] as? Int else { return nil }
                    let nbParties = data["nbParties"] as? Int ?? 0
                    return PlayerRanking(id: doc.documentID,
                                         rank: index + 1,
                                         username: username,
                                         exp: exp,
                                         nbParties: nbParties)
                }
                
                DispatchQueue.main.async {
                    self.playerRankings = tempRankings
                }
            }
    }
}
