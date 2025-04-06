//
//  Player.swift
//  PPE_Jeu
//
//  Created by Youssef Ait Elourf on 03/04/2025.
//


import FirebaseFirestore

// Modèles utilisés par FirestoreManager
struct Player {
    let id: String
    let username: String
    var currency: Int
    let exp: Int
}

struct Card: Identifiable {
    let id: String
    let nom: String
    let base_atk: Int
    let base_pv: Int
    let price: Int
    let description_carte: String
    let photo: String
}

struct CardPlayer {
    let id: String          // Document ID dans "card_players"
    let id_card: String     // Référence de la carte (document ID dans "cards")
    let id_player: String   // Référence du joueur (document ID dans "player")
    var current_atk: Int
    var current_pv: Int
}

class FirestoreManager {
    private let db = Firestore.firestore()
    
    // MARK: - Cartes
    
    /// Récupère toutes les cartes de la collection "cards"
    func fetchAllCards(completion: @escaping ([Card]) -> Void) {
        db.collection("cards").getDocuments { snapshot, error in
            var cards: [Card] = []
            if let docs = snapshot?.documents {
                for doc in docs {
                    let data = doc.data()
                    let card = Card(
                        id: doc.documentID,
                        nom: data["nom"] as? String ?? "",
                        base_atk: data["base_atk"] as? Int ?? 0,
                        base_pv: data["base_pv"] as? Int ?? 0,
                        price: data["price"] as? Int ?? 0,
                        description_carte: data["description_carte"] as? String ?? "",
                        photo: data["photo"] as? String ?? ""
                    )
                    cards.append(card)
                }
            }
            completion(cards)
        }
    }


    // MARK: - Joueur
    
    /// Récupère un joueur par son username (comparaison exacte)
    func fetchPlayer(username: String, completion: @escaping (Player?) -> Void) {
        db.collection("player")
            .whereField("username", isEqualTo: username)
            .getDocuments { snapshot, error in
                if let doc = snapshot?.documents.first {
                    let data = doc.data()
                    let player = Player(
                        id: doc.documentID,
                        username: data["username"] as? String ?? "",
                        currency: data["currency"] as? Int ?? 0,
                        exp: data["exp"] as? Int ?? 0
                    )
                    completion(player)
                } else {
                    completion(nil)
                }
            }
    }
    
    /// Ajoute un nouveau joueur dans la collection "player"
    func addPlayer(username: String, currency: Int, exp: Int, completion: @escaping (Error?) -> Void) {
        let data: [String: Any] = [
            "username": username,
            "currency": currency,
            "exp": exp
        ]
        db.collection("player").addDocument(data: data) { error in
            completion(error)
        }
    }
    
    /// Récupère un joueur par son document ID
    func fetchPlayerById(playerId: String, completion: @escaping (Player?) -> Void) {
        db.collection("player").document(playerId).getDocument { snapshot, error in
            if let snapshot = snapshot, snapshot.exists, let data = snapshot.data() {
                let player = Player(
                    id: snapshot.documentID,
                    username: data["username"] as? String ?? "",
                    currency: data["currency"] as? Int ?? 0,
                    exp: data["exp"] as? Int ?? 0
                )
                completion(player)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - Cartes du joueur
    
    /// Récupère les cartes possédées par un joueur depuis "card_players"
    func fetchPlayerCards(playerId: String, completion: @escaping ([CardPlayer]) -> Void) {
        db.collection("card_players")
            .whereField("id_player", isEqualTo: playerId)
            .getDocuments { snapshot, error in
                var cardPlayers: [CardPlayer] = []
                if let docs = snapshot?.documents {
                    for doc in docs {
                        let data = doc.data()
                        let cp = CardPlayer(
                            id: doc.documentID,
                            id_card: data["id_card"] as? String ?? "",
                            id_player: data["id_player"] as? String ?? "",
                            current_atk: data["current_atk"] as? Int ?? 0,
                            current_pv: data["current_pv"] as? Int ?? 0
                        )
                        cardPlayers.append(cp)
                    }
                }
                completion(cardPlayers)
            }
    }
    
    // MARK: - Achat de carte
    
    func purchaseCard(for player: Player, card: Card, completion: @escaping (Player?, CardPlayer?, Error?) -> Void) {
        let newCurrency = player.currency - card.price
        let playerRef = db.collection("player").document(player.id)
        playerRef.updateData(["currency": newCurrency]) { error in
            if let error = error {
                completion(nil, nil, error)
                return
            }
            let data: [String: Any] = [
                "id_card": card.id,
                "id_player": player.id,
                "current_atk": card.base_atk,
                "current_pv": card.base_pv
            ]
            let cardPlayersCollection = self.db.collection("card_players")
            var docRef: DocumentReference?
            docRef = cardPlayersCollection.addDocument(data: data) { error in
                if let error = error {
                    completion(nil, nil, error)
                } else if let docRef = docRef {
                    let cp = CardPlayer(id: docRef.documentID, id_card: card.id, id_player: player.id, current_atk: card.base_atk, current_pv: card.base_pv)
                    let updatedPlayer = Player(id: player.id, username: player.username, currency: newCurrency, exp: player.exp)
                    completion(updatedPlayer, cp, nil)
                }
            }
        }
    }   
    func updatePlayerExp(playerId: String, delta: Int, completion: @escaping (Error?) -> Void) {
        let playerRef = db.collection("players").document(playerId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let snapshot = try transaction.getDocument(playerRef)
                let oldExp = snapshot.data()?["exp"] as? Int ?? 0
                let newExp = oldExp + delta
                transaction.updateData(["exp": newExp], forDocument: playerRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            return nil
        }) { (object, error) in
            completion(error)
        }
    }
    
    func updatePlayerExpClampedToZero(playerId: String, delta: Int, completion: @escaping (Error?) -> Void) {
        let playerRef = db.collection("player").document(playerId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let snapshot = try transaction.getDocument(playerRef)
                let oldExp = snapshot.data()?["exp"] as? Int ?? 0
                let candidateExp = oldExp + delta
                let newExp = max(0, candidateExp) // on borne à 0
                
                transaction.updateData(["exp": newExp], forDocument: playerRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            return nil
        }) { (_, error) in
            completion(error)
        }
    }
    // MARK: - Upgrade de carte
    
    /// Upgrade d'une carte (ATK ou PV) : déduction de 100 crédits et augmentation de +5 de la stat choisie
    func upgradeCard(cardPlayer: CardPlayer, type: String, completion: @escaping (Player?, CardPlayer?, Error?) -> Void) {
        let playerRef = db.collection("player").document(cardPlayer.id_player)
        playerRef.getDocument { snapshot, error in
            guard let snapshot = snapshot, snapshot.exists,
                  let data = snapshot.data(),
                  let currentCurrency = data["currency"] as? Int else {
                completion(nil, nil, error)
                return
            }
            if currentCurrency < 100 {
                completion(nil, nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Pas assez de crédits"]))
                return
            }
            let newCurrency = currentCurrency - 100
            playerRef.updateData(["currency": newCurrency]) { error in
                if let error = error {
                    completion(nil, nil, error)
                    return
                }
                let cpRef = self.db.collection("card_players").document(cardPlayer.id)
                if type == "atk" {
                    let newAtk = cardPlayer.current_atk + 5
                    cpRef.updateData(["current_atk": newAtk]) { error in
                        if let error = error {
                            completion(nil, nil, error)
                        } else {
                            let updatedCP = CardPlayer(id: cardPlayer.id, id_card: cardPlayer.id_card, id_player: cardPlayer.id_player, current_atk: newAtk, current_pv: cardPlayer.current_pv)
                            self.fetchPlayerById(playerId: cardPlayer.id_player) { updatedPlayer in
                                completion(updatedPlayer, updatedCP, nil)
                            }
                        }
                    }
                } else if type == "pv" {
                    let newPv = cardPlayer.current_pv + 5
                    cpRef.updateData(["current_pv": newPv]) { error in
                        if let error = error {
                            completion(nil, nil, error)
                        } else {
                            let updatedCP = CardPlayer(id: cardPlayer.id, id_card: cardPlayer.id_card, id_player: cardPlayer.id_player, current_atk: cardPlayer.current_atk, current_pv: newPv)
                            self.fetchPlayerById(playerId: cardPlayer.id_player) { updatedPlayer in
                                completion(updatedPlayer, updatedCP, nil)
                            }
                        }
                    }
                }
            }
        }
    }
}
extension FirestoreManager {
    func addCredits(for player: Player, amount: Int, completion: @escaping (Error?) -> Void) {
        // Supposez que votre collection de joueurs s'appelle "player" et que le champ "currency" contient la balance.
        let playerRef = Firestore.firestore().collection("player").document(player.id)
        // Utilisation d'un incrément atomique
        playerRef.updateData(["currency": FieldValue.increment(Int64(amount))]) { error in
            completion(error)
        }
    }
}
