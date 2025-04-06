import SwiftUI
import FirebaseFirestore
import UIKit

struct MatchView: View {
    let matchId: String
    let selectedCard: Card
    let opponentMatch: MultiplayerMatch
    @ObservedObject var viewModel: CardsViewModel
    
    // PV courants
    @State private var myPV: Int = 100
    @State private var opponentPV: Int = 100
    @State private var opponentName: String = "Inconnu"
    
    // IDs Firestore
    @State private var matchPlayer1Id: String = ""
    @State private var matchPlayer2Id: String = ""
    
    // PV initiaux (pour les règles de gain/perte)
    @State private var myStartHP: Int = 100
    @State private var oppStartHP: Int = 100
    
    // ATK de ma carte
    @State private var myAttack: Int = 5
    
    // Listener Firestore
    @State private var matchListener: ListenerRegistration? = nil
    
    // Navigation vers EndMatchView
    @State private var navigateToEndView = false
    @State private var didWin: Bool = false
    
    // Texte résumé pour la fin du match
    @State private var endInfoText: String = ""
    
    // Montant d'EXP gagné ou perdu
    @State private var expDelta: Int = 0
    
    // Nouvelles variables pour la barre de randomize
    @State private var randomizeValue: CGFloat = 0.0
    @State private var isRandomizing: Bool = false
    @State private var randomizeDirection: Bool = true // true = augmente, false = diminue
    @State private var randomizeSpeed: Double = 0.01
    @State private var attackMultiplier: CGFloat = 0.0
    @State private var showAttackResult: Bool = false
    @State private var attackResultText: String = ""
    @State private var attackButtonDisabled: Bool = false
    
    // Timer pour l'animation de la barre
    @State private var randomizeTimer: Timer? = nil
    
    @Environment(\.presentationMode) var presentationMode
    
    // Managers
    private let firestoreManager = FirestoreManager()
    private let multiplayerManager = MultiplayerFirestoreManager()
    
    // Suis-je player1 ?
    var isPlayer1: Bool {
        return viewModel.player?.id == matchPlayer1Id
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Container de la carte adverse (en haut)
                VStack(alignment: .center, spacing: 8) {
                    // Utilise opponentCardPhoto() pour récupérer le nom de l'image de la carte adverse
                    Image(opponentCardPhoto())
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 180) // Réduit de 220 à 180
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Nom de la carte adverse
                    Text(opponentCardName())
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    // Statistiques de l'adversaire
                    HStack(spacing: 20) {
                        Text("ATK: \(opponentMatch.current_atk)")
                            .foregroundColor(.red)
                            .font(.subheadline)
                        Text("PV: \(opponentPV)")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                }
                .padding(8)
                .frame(maxWidth: 180, minHeight: 260) // Réduit de 220/300 à 180/260
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
                
                // Container de votre carte et barre d'attaque côte à côte
                HStack(alignment: .top, spacing: 16) {
                    // Votre carte (à gauche)
                    VStack(alignment: .center, spacing: 8) {
                        Image(selectedCard.photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 180) // Réduit de 220 à 180
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        Text(selectedCard.nom)
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        
                        HStack(spacing: 20) {
                            if let owned = viewModel.ownedCards[selectedCard.id] {
                                Text("ATK: \(owned.current_atk)")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                                Text("PV: \(myPV)")
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                            } else {
                                Text("ATK: \(selectedCard.base_atk)")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                                Text("PV: \(myPV)")
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: 180, minHeight: 260)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(UIColor.separator), lineWidth: 1)
                    )
                    
                    // Barre de randomize (à droite)
                    if isRandomizing {
                        VStack(spacing: 10) {
                            Text("Force d'attaque")
                                .font(.headline)
                            
                            // Barre de progression verticale
                            ZStack(alignment: .bottom) {
                                // Fond de la barre
                                Rectangle()
                                    .frame(width: 30, height: 200)
                                    .foregroundColor(Color.gray.opacity(0.3))
                                    .cornerRadius(8)
                                
                                // Barre de progression
                                Rectangle()
                                    .frame(width: 30, height: randomizeValue * 200)
                                    .foregroundColor(randomizeBarColor())
                                    .cornerRadius(8)
                            }
                            .frame(height: 200)
                            
                            // Pourcentage affiché
                            Text("\(Int(randomizeValue * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
                
                // Affichage du résultat de l'attaque
                if showAttackResult {
                    Text(attackResultText)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                // Boutons : Attaquer et Abandonner en bas
                HStack(spacing: 12) {
                    Button(action: {
                        if isRandomizing {
                            // Stopper la barre et lancer l'attaque avec le multiplicateur actuel
                            stopRandomizeAndAttack()
                        } else {
                            // Démarrer l'animation de la barre de randomize
                            startRandomize()
                        }
                    }) {
                        HStack {
                            Image(systemName: isRandomizing ? "hand.tap" : "burst.fill")
                            Text(isRandomizing ? "Stop!" : "Attaquer")
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(attackButtonDisabled)
                    
                    Button(action: {
                        abandon()
                    }) {
                        Text("Abandonner")
                            .fontWeight(.medium)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // NavigationLink caché vers EndMatchView
                NavigationLink(
                    destination: EndMatchView(didWin: didWin, infoText: endInfoText, expDelta: expDelta),
                    isActive: $navigateToEndView
                ) {
                    EmptyView()
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            setupInitialValues()
            startMatchListener()
        }
        .onDisappear {
            cleanupTimers()
            matchListener?.remove()
        }
    }
    
    // Fonction d'aide pour récupérer le nom de la carte adverse
    func opponentCardName() -> String {
        if let opponentCard = viewModel.cards.first(where: { $0.id == opponentMatch.cardId }) {
            return opponentCard.nom
        }
        return opponentMatch.cardId
    }
    
    // Fonction d'aide pour récupérer le nom de l'image de la carte adverse
    func opponentCardPhoto() -> String {
        if let opponentCard = viewModel.cards.first(where: { $0.id == opponentMatch.cardId }) {
            return opponentCard.photo
        }
        return "defaultEnemy"
    }
    
    // Fonction pour déterminer la couleur de la barre en fonction de sa valeur
    func randomizeBarColor() -> Color {
        if randomizeValue < 0.3 {
            return Color.red
        } else if randomizeValue < 0.7 {
            return Color.yellow
        } else {
            return Color.green
        }
    }
    
    // MARK: - Setup, Listener and Actions
    
    func setupInitialValues() {
        if let cp = viewModel.ownedCards[selectedCard.id] {
            myPV = cp.current_pv
            myAttack = cp.current_atk
        } else {
            myPV = selectedCard.base_pv
            myAttack = selectedCard.base_atk
        }
        myStartHP = myPV
        
        opponentPV = opponentMatch.current_pv
        oppStartHP = opponentMatch.current_pv
        
        firestoreManager.fetchPlayerById(playerId: opponentMatch.playerId) { player in
            DispatchQueue.main.async {
                if let player = player {
                    opponentName = player.username
                }
            }
        }
    }
    
    func startMatchListener() {
        let docRef = Firestore.firestore().collection("matches").document(matchId)
        
        matchListener = docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                print("Erreur de listener: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data() else {
                print("Snapshot vide ou pas de données")
                return
            }
            
            let p1Id = data["player1Id"] as? String ?? ""
            let p2Id = data["player2Id"] as? String ?? ""
            let p1Remaining = data["player1Remaining_pv"] as? Int ?? 100
            let p2Remaining = data["player2Remaining_pv"] as? Int ?? 100
            let matchResult = data["result"] as? String ?? ""
            
            DispatchQueue.main.async {
                matchPlayer1Id = p1Id
                matchPlayer2Id = p2Id
                
                if isPlayer1 {
                    myPV = p1Remaining
                    opponentPV = p2Remaining
                } else {
                    myPV = p2Remaining
                    opponentPV = p1Remaining
                }
                
                if !matchResult.isEmpty && !navigateToEndView {
                    if matchResult == "player1" {
                        if isPlayer1 {
                            didWin = true
                            endInfoText = "Votre adversaire avait \(oppStartHP) PV avant le match."
                        } else {
                            didWin = false
                            endInfoText = "Vous aviez \(myStartHP) PV avant le match."
                        }
                    } else if matchResult == "player2" {
                        if !isPlayer1 {
                            didWin = true
                            endInfoText = "Votre adversaire avait \(oppStartHP) PV avant le match."
                        } else {
                            didWin = false
                            endInfoText = "Vous aviez \(myStartHP) PV avant le match."
                        }
                    }
                    navigateToEndView = true
                }
            }
        }
    }
    
    // Fonctions pour la barre de randomize
    func startRandomize() {
        isRandomizing = true
        randomizeValue = 0.0
        randomizeDirection = true
        
        // Créer un timer qui met à jour la valeur de la barre
        randomizeTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            withAnimation {
                // Mise à jour de la valeur de randomize selon la direction
                if randomizeDirection {
                    randomizeValue += CGFloat(randomizeSpeed)
                    if randomizeValue >= 1.0 {
                        randomizeValue = 1.0
                        randomizeDirection = false
                    }
                } else {
                    randomizeValue -= CGFloat(randomizeSpeed)
                    if randomizeValue <= 0.0 {
                        randomizeValue = 0.0
                        randomizeDirection = true
                    }
                }
            }
        }
    }
    
    func stopRandomizeAndAttack() {
        // Arrêter le timer
        randomizeTimer?.invalidate()
        randomizeTimer = nil
        
        isRandomizing = false
        attackMultiplier = randomizeValue // Sauvegarder le multiplicateur d'attaque
        
        // Afficher le résultat de l'attaque
        let effectiveAttack = Int(Double(myAttack) * Double(attackMultiplier))
        attackResultText = "Attaque à \(Int(attackMultiplier * 100))% de puissance: \(effectiveAttack) points de dégâts!"
        showAttackResult = true
        attackButtonDisabled = true
        
        // Attendre un peu pour montrer le résultat et ensuite attaquer
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showAttackResult = false
            attackButtonDisabled = false
            attack(withMultiplier: attackMultiplier)
        }
    }
    
    func cleanupTimers() {
        randomizeTimer?.invalidate()
        randomizeTimer = nil
    }
    
    func attack(withMultiplier multiplier: CGFloat) {
        // Calculer les dégâts en fonction du multiplicateur
        let effectiveAttack = Int(Double(myAttack) * Double(multiplier))
        let damageAmount = max(1, effectiveAttack) // Au moins 1 point de dégât
        let newOppPV = max(opponentPV - damageAmount, 0)
        
        opponentPV = newOppPV
        updateHP(myHp: myPV, oppHp: newOppPV)
        
        if newOppPV == 0 {
            didWin = true
            endInfoText = "Votre adversaire avait \(oppStartHP) PV avant le match."
            expDelta = oppStartHP
            
            if let me = viewModel.player {
                firestoreManager.updatePlayerExpClampedToZero(playerId: me.id, delta: expDelta) { error in
                    if let error = error {
                        print("Erreur update EXP: \(error.localizedDescription)")
                    }
                }
            }
            navigateToEndView = true
            let winner = isPlayer1 ? "player1" : "player2"
            endMatch(result: winner)
        }
    }
    
    func abandon() {
        didWin = false
        endInfoText = "Vous aviez \(myStartHP) PV avant le match."
        expDelta = -myStartHP
        
        if let me = viewModel.player {
            firestoreManager.updatePlayerExpClampedToZero(playerId: me.id, delta: expDelta) { error in
                if let error = error {
                    print("Erreur update EXP (loser): \(error.localizedDescription)")
                }
            }
        }
        
        navigateToEndView = true
        let winner = isPlayer1 ? "player2" : "player1"
        endMatch(result: winner)
    }
    
    func updateHP(myHp: Int, oppHp: Int) {
        let db = Firestore.firestore()
        var updateData: [String: Any] = [:]
        
        if isPlayer1 {
            updateData["player1Remaining_pv"] = myHp
            updateData["player2Remaining_pv"] = oppHp
        } else {
            updateData["player2Remaining_pv"] = myHp
            updateData["player1Remaining_pv"] = oppHp
        }
        
        updateData["lastUpdate"] = FieldValue.serverTimestamp()
        
        db.collection("matches").document(matchId).updateData(updateData) { error in
            if let error = error {
                print("Erreur updateHP: \(error.localizedDescription)")
            } else {
                print("PV mis à jour dans Firestore.")
            }
        }
    }
    
    func endMatch(result: String) {
        matchListener?.remove()
        
        let db = Firestore.firestore()
        let matchRef = db.collection("matches").document(matchId)
        
        let endData: [String: Any] = [
            "result": result,
            "matchEnd": FieldValue.serverTimestamp()
        ]
        
        matchRef.updateData(endData) { error in
            if let error = error {
                print("Erreur endMatch: \(error.localizedDescription)")
                return
            }
            
            matchRef.getDocument { snapshot, error in
                if let error = error {
                    print("Erreur getDocument: \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data() else { return }
                
                let finishedRef = db.collection("finishedMatches").document(matchId)
                finishedRef.setData(data) { err in
                    if let err = err {
                        print("Erreur setData finishedMatches: \(err.localizedDescription)")
                    } else {
                        matchRef.delete { delError in
                            if let delError = delError {
                                print("Erreur suppression match: \(delError.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
}
