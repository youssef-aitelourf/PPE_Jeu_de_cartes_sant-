import SwiftUI
import FirebaseFirestore
import UIKit

struct MatchmakingView: View {
    let selectedCard: Card
    @ObservedObject var viewModel: CardsViewModel

    @State private var message: String = "Recherche de match..."
    private let multiplayerManager = MultiplayerFirestoreManager()
    private let firestoreManager = FirestoreManager()
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var listenerRegistration: ListenerRegistration? = nil
    @State private var matchListenerRegistration: ListenerRegistration? = nil
    
    @State private var navigateToMatch: Bool = false
    @State private var opponentMatch: MultiplayerMatch? = nil
    @State private var myMatch: MultiplayerMatch? = nil
    @State private var createdMatchId: String = ""
    @State private var waitingForMatchCreation: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                // Conteneur de type "carte" similaire à CardView
                VStack(alignment: .center, spacing: 16) {
                    Image(selectedCard.photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300) // L'image occupe presque toute la largeur de la carte
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    Text(selectedCard.nom)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    HStack(spacing: 40) {
                        if let owned = viewModel.ownedCards[selectedCard.id] {
                            Text("ATK: \(owned.current_atk)")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("PV: \(owned.current_pv)")
                                .foregroundColor(.green)
                                .font(.title2)
                        } else {
                            Text("ATK: \(selectedCard.base_atk)")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("PV: \(selectedCard.base_pv)")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    
                    Text(selectedCard.description_carte)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.footnote)
                }
                .padding()
                .frame(maxWidth: 350, minHeight: 500, alignment: .center)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(UIColor.separator), lineWidth: 2)
                )
                
                // Affichage du message de statut de matchmaking et d'une progress view si nécessaire
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding()
                if waitingForMatchCreation {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
                
                // Bouton pour annuler le matchmaking
                Button("Annuler matchmaking") {
                    stopMatchmaking()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Navigation cachée pour passer à la vue de match lorsque c'est prêt
                NavigationLink(destination: destinationView(),
                               isActive: $navigateToMatch) {
                    EmptyView()
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("") // Suppression du titre "Matchmaking" dans la barre de navigation
        .navigationBarBackButtonHidden(true) // Le bouton retour par défaut est masqué ici.
        .onAppear {
            joinAndListen()
        }
        .onDisappear {
            listenerRegistration?.remove()
            matchListenerRegistration?.remove()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            stopMatchmaking()
        }
    }
    
    @ViewBuilder
    private func destinationView() -> some View {
        if let opponent = opponentMatch {
            MatchView(matchId: createdMatchId,
                      selectedCard: selectedCard,
                      opponentMatch: opponent,
                      viewModel: viewModel)
                .navigationBarBackButtonHidden(true)  // Masque le bouton retour standard
                .toolbar(.hidden, for: .navigationBar)  // Masque toute la barre de navigation, y compris les boutons personnalisés
        } else {
            EmptyView()
        }
    }
    
    private func joinAndListen() {
        guard let player = viewModel.player,
              let cp = viewModel.ownedCards[selectedCard.id] else {
            message = "Erreur : données manquantes."
            return
        }
        
        multiplayerManager.joinMatchmaking(
            playerId: player.id,
            cardId: selectedCard.id,
            current_atk: cp.current_atk,
            current_pv: cp.current_pv
        ) { error in
            DispatchQueue.main.async {
                if let error = error {
                    message = "Erreur lors de l'inscription : \(error.localizedDescription)"
                } else {
                    message = "En attente d'un adversaire..."
                    listenerRegistration = multiplayerManager.listenForMatch(playerId: player.id) { myMatchFound, opponent, isFirstPlayer in
                        if let myMatchFound = myMatchFound, let opponent = opponent {
                            self.myMatch = myMatchFound
                            self.opponentMatch = opponent
                            
                            if isFirstPlayer {
                                createMatch(player: player, opponent: opponent, cp: cp)
                            } else {
                                waitingForMatchCreation = true
                                message = "Match trouvé, préparation en cours..."
                                waitForMatchCreation(player: player, opponent: opponent)
                            }
                        } else {
                            message = "En attente d'un adversaire..."
                        }
                    }
                }
            }
        }
    }
    
    private func createMatch(player: Player, opponent: MultiplayerMatch, cp: CardPlayer) {
        firestoreManager.fetchPlayerById(playerId: opponent.playerId) { opponentPlayer in
            DispatchQueue.main.async {
                let firstTurnEndTime = Timestamp(date: Date().addingTimeInterval(7.0))
                let myUsername = player.username
                let opponentUsername = opponentPlayer?.username ?? "Adversaire"
                let matchUniqueId = "\(player.id)_vs_\(opponent.playerId)_\(Int(Date().timeIntervalSince1970))"
                
                let matchData: [String: Any] = [
                    "matchUniqueId": matchUniqueId,
                    "player1Id": player.id,
                    "player2Id": opponent.playerId,
                    "player1Username": myUsername,
                    "player2Username": opponentUsername,
                    "player1CardId": selectedCard.id,
                    "player2CardId": opponent.cardId,
                    "player1Start_atk": cp.current_atk,
                    "player1Start_pv": cp.current_pv,
                    "player2Start_atk": opponent.current_atk,
                    "player2Start_pv": opponent.current_pv,
                    "player1Remaining_pv": cp.current_pv,
                    "player2Remaining_pv": opponent.current_pv,
                    "player1Damage": 0,
                    "player2Damage": 0,
                    "result": "",
                    "matchStart": FieldValue.serverTimestamp(),
                    "turns": 0,
                    "currentTurnPlayerId": player.id,
                    "turnDuration": 7,
                    "turnEndTimestamp": firstTurnEndTime,
                    "lastUpdate": FieldValue.serverTimestamp(),
                    "createdBy": player.id
                ]
                
                multiplayerManager.createMatchWithId(id: matchUniqueId, matchData: matchData) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            message = "Erreur lors de la création du match : \(error.localizedDescription)"
                        } else {
                            message = "Match créé, début de la partie!"
                            createdMatchId = matchUniqueId
                            
                            multiplayerManager.leaveMatchmaking(playerId: player.id) { _ in }
                            multiplayerManager.leaveMatchmaking(playerId: opponent.playerId) { _ in }
                            
                            navigateToMatch = true
                        }
                    }
                }
            }
        }
    }
    
    private func waitForMatchCreation(player: Player, opponent: MultiplayerMatch) {
        matchListenerRegistration = Firestore.firestore().collection("matches")
            .whereField("player2Id", isEqualTo: player.id)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Erreur d'écoute match: \(error.localizedDescription)")
                    return
                }
                if let docs = snapshot?.documents, !docs.isEmpty {
                    for doc in docs {
                        let data = doc.data()
                        if data["player1Id"] as? String == opponent.playerId,
                           data["player2Id"] as? String == player.id {
                            
                            print("Match trouvé pour le second joueur! ID: \(doc.documentID)")
                            DispatchQueue.main.async {
                                message = "Match trouvé!"
                                createdMatchId = doc.documentID
                                waitingForMatchCreation = false
                                
                                multiplayerManager.leaveMatchmaking(playerId: player.id) { _ in }
                                
                                navigateToMatch = true
                            }
                            return
                        }
                    }
                }
            }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if waitingForMatchCreation {
                message = "Temps d'attente expiré. Réessayez."
                waitingForMatchCreation = false
                stopMatchmaking()
            }
        }
    }
    
    private func stopMatchmaking() {
        guard let player = viewModel.player else { return }
        
        matchListenerRegistration?.remove()
        listenerRegistration?.remove()
        
        multiplayerManager.leaveMatchmaking(playerId: player.id) { error in
            DispatchQueue.main.async {
                if let error = error {
                    message = "Erreur lors de l'arrêt : \(error.localizedDescription)"
                } else {
                    message = "Matchmaking annulé."
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
