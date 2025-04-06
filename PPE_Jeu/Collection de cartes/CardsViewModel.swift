//
//  CardsViewModel.swift
//  PPE_Jeu
//
//  Created by Youssef Ait Elourf on 03/04/2025.
//


import Foundation
import Combine

class CardsViewModel: ObservableObject {
    @Published var cards: [Card] = []
    @Published var ownedCards: [String: CardPlayer] = [:] // clé = id_card
    @Published var player: Player?
    
    private let firestoreManager = FirestoreManager()
    let username: String
    
    init(username: String) {
        self.username = username
        loadData()
    }
    
    func loadData() {
        firestoreManager.fetchPlayer(username: username) { [weak self] player in
            DispatchQueue.main.async {
                self?.player = player
            }
            if let player = player {
                self?.firestoreManager.fetchPlayerCards(playerId: player.id) { cardPlayers in
                    DispatchQueue.main.async {
                        self?.ownedCards = Dictionary(uniqueKeysWithValues: cardPlayers.map { ($0.id_card, $0) })
                    }
                }
            }
        }
        firestoreManager.fetchAllCards { [weak self] cards in
            DispatchQueue.main.async {
                self?.cards = cards
            }
        }
    }
    
    func purchase(card: Card, completion: @escaping (Error?) -> Void) {
        guard let player = player, player.currency >= card.price else {
            completion(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Pas assez de crédits"]))
            return
        }
        firestoreManager.purchaseCard(for: player, card: card) { [weak self] updatedPlayer, cardPlayer, error in
            DispatchQueue.main.async {
                if let updatedPlayer = updatedPlayer, let cardPlayer = cardPlayer {
                    self?.player = updatedPlayer
                    self?.ownedCards[card.id] = cardPlayer
                }
                completion(error)
            }
        }
    }
    
    func upgradeCard(cardPlayer: CardPlayer, type: String, completion: @escaping (Error?) -> Void) {
        guard let player = player, player.currency >= 100 else {
            completion(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Pas assez de crédits"]))
            return
        }
        firestoreManager.upgradeCard(cardPlayer: cardPlayer, type: type) { [weak self] updatedPlayer, updatedCardPlayer, error in
            DispatchQueue.main.async {
                if let updatedPlayer = updatedPlayer, let updatedCardPlayer = updatedCardPlayer {
                    self?.player = updatedPlayer
                    self?.ownedCards[cardPlayer.id_card] = updatedCardPlayer
                }
                completion(error)
            }
        }
    }
}
