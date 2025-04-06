import FirebaseFirestore

// Structure représentant une inscription au matchmaking
struct MultiplayerMatch {
    let id: String          // ID du document dans "matchmaking"
    let playerId: String    // Identifiant du joueur (référence dans "player")
    let cardId: String      // Identifiant de la carte utilisée (référence dans "cards")
    let current_atk: Int    // Stat d'attaque actuelle (snapshot de card_players)
    let current_pv: Int     // Points de vie actuels (snapshot de card_players)
    let timestamp: Timestamp // Moment d'inscription (FieldValue.serverTimestamp())
}

// Structure représentant un match joué (si besoin de sauvegarder le déroulement)
struct Match {
    let id: String                // ID du document dans "matches"
    let player1Id: String         // Joueur 1
    let player2Id: String         // Joueur 2
    let player1CardId: String     // Carte du joueur 1
    let player2CardId: String     // Carte du joueur 2
    let player1Start_atk: Int     // Snapshot de current_atk pour joueur 1
    let player1Start_pv: Int      // Snapshot de current_pv pour joueur 1
    let player2Start_atk: Int     // Snapshot de current_atk pour joueur 2
    let player2Start_pv: Int      // Snapshot de current_pv pour joueur 2
    let player1Remaining_pv: Int  // PV restants du joueur 1 en fin de match
    let player2Remaining_pv: Int  // PV restants du joueur 2 en fin de match
    let player1Damage: Int        // Total des dégâts infligés par le joueur 1
    let player2Damage: Int        // Total des dégâts infligés par le joueur 2
    let result: String            // "player1" ou "player2" indiquant le gagnant
    let matchStart: Timestamp     // Début du match
    let matchEnd: Timestamp       // Fin du match
    let turns: Int                // Nombre de tours joués
}

class MultiplayerFirestoreManager {
    private let db = Firestore.firestore()
    
    // MARK: - Matchmaking
    
    /// Inscrit un joueur dans le matchmaking en enregistrant un snapshot de ses statistiques.
    func joinMatchmaking(playerId: String,
                         cardId: String,
                         current_atk: Int,
                         current_pv: Int,
                         completion: @escaping (Error?) -> Void)
    {
        let data: [String: Any] = [
            "playerId": playerId,
            "cardId": cardId,
            "current_atk": current_atk,
            "current_pv": current_pv,
            "timestamp": FieldValue.serverTimestamp()
        ]
        db.collection("matchmaking").addDocument(data: data, completion: completion)
    }
    
    /// Retire un joueur du matchmaking en supprimant toutes ses inscriptions
    func leaveMatchmaking(playerId: String, completion: @escaping (Error?) -> Void) {
        db.collection("matchmaking")
            .whereField("playerId", isEqualTo: playerId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(error)
                    return
                }
                let batch = self.db.batch()
                snapshot?.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }
                batch.commit(completion: completion)
            }
    }
    
    /// Écoute la collection "matchmaking" et détecte dès qu'au moins deux inscriptions sont présentes.
    /// - Returns: ListenerRegistration pour stopper l'écoute
    func listenForMatch(playerId: String,
                        completion: @escaping (MultiplayerMatch?, MultiplayerMatch?, Bool) -> Void)
    -> ListenerRegistration
    {
        return db.collection("matchmaking")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                let matches = docs.compactMap { doc -> MultiplayerMatch? in
                    let data = doc.data()
                    guard let pId = data["playerId"] as? String,
                          let cId = data["cardId"] as? String,
                          let atk = data["current_atk"] as? Int,
                          let pv = data["current_pv"] as? Int,
                          let ts = data["timestamp"] as? Timestamp else {
                        return nil
                    }
                    return MultiplayerMatch(id: doc.documentID,
                                            playerId: pId,
                                            cardId: cId,
                                            current_atk: atk,
                                            current_pv: pv,
                                            timestamp: ts)
                }
                
                // Si au moins deux inscriptions
                if matches.count >= 2,
                   let myMatch = matches.first(where: { $0.playerId == playerId }),
                   let oppMatch = matches.first(where: { $0.playerId != playerId }) {
                    
                    // Déterminer qui est le premier joueur (celui qui a la plus ancienne inscription)
                    let allMatches = matches.sorted(by: { $0.timestamp.seconds < $1.timestamp.seconds })
                    let firstPlayerId = allMatches.first?.playerId
                    
                    // Si je suis le premier joueur, je crée le match
                    let isFirstPlayer = (firstPlayerId == playerId)
                    
                    completion(myMatch, oppMatch, isFirstPlayer)
                } else {
                    // Pas assez de joueurs encore
                    completion(nil, nil, false)
                }
            }
    }
    
    // MARK: - Matches
    
    /// Crée un document dans la collection "matches" avec un ID spécifique
    func createMatchWithId(id: String, matchData: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("matches").document(id).setData(matchData, completion: completion)
    }
    
    /// Crée un document dans la collection "matches" (sans renvoyer l'ID)
    func createMatch(matchData: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("matches").addDocument(data: matchData, completion: completion)
    }
    
    /// Variante de createMatch qui renvoie l'ID du document créé
    func createMatch(matchData: [String: Any], completion: @escaping (String?, Error?) -> Void) {
        var ref: DocumentReference? = nil
        ref = db.collection("matches").addDocument(data: matchData) { error in
            if let error = error {
                completion(nil, error)
            } else {
                completion(ref?.documentID, nil)
            }
        }
    }
    
    /// Met à jour un document de match (ID : matchId) avec les champs passés dans `data`
    func updateMatch(matchId: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("matches")
            .document(matchId)
            .updateData(data, completion: completion)
    }
    
    // MARK: - Outils pour la gestion du tour (optionnel)
    
    /// Prépare la map pour démarrer un nouveau tour : on inverse currentTurn et on recalcule turnEndTimestamp
    func prepareNextTurnData(currentTurn: String,
                             turnDuration: Int,
                             completion: @escaping ([String: Any]) -> Void)
    {
        let newTurn = (currentTurn == "player1") ? "player2" : "player1"
        let endTime = Timestamp(date: Date().addingTimeInterval(TimeInterval(turnDuration)))
        let update: [String: Any] = [
            "currentTurn": newTurn,
            "turnEndTimestamp": endTime
        ]
        completion(update)
    }
}
