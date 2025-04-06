import SwiftUI
import FirebaseFirestore

// Nouvel objet PlayerRanking

// Vue qui affiche une ligne de classement
struct RankingRowView: View {
    let playerRanking: PlayerRanking
    let currentUserId: String?
    
    var body: some View {
        HStack {
            Text("\(playerRanking.rank)")
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(playerRanking.username)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text("\(playerRanking.exp) EXP")
                    Text("•")
                    Text("\(playerRanking.nbParties) parties")
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(8)
        .background(
            Group {
                if currentUserId == playerRanking.id {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 2)
                } else {
                    Color.clear
                }
            }
        )
    }
}

// Vue principale du classement (classement mondial)
struct ClassementMondialView: View {
    // Ici, on passe le viewModel pour connaître l'utilisateur courant.
    @ObservedObject var viewModel: CardsViewModel
    @State private var playerRankings: [PlayerRanking] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Classement mondial")
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
    
    // Fonction pour charger les joueurs depuis Firestore et les trier par EXP décroissant
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
                
                // Créer un tableau de PlayerRanking en utilisant l'indice pour le rang
                let tempRankings: [PlayerRanking] = docs.enumerated().compactMap { (index, doc) in
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

struct ClassementMondialView_Previews: PreviewProvider {
    static var previews: some View {
        // Pour la prévisualisation, on passe un viewModel factice.
        ClassementMondialView(viewModel: CardsViewModel(username: "TestUser"))
    }
}
