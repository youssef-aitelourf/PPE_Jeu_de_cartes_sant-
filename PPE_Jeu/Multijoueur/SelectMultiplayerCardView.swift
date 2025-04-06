import SwiftUI

struct SelectMultiplayerCardView: View {
    @AppStorage("storedUsername") var storedUsername: String = ""
    @StateObject var viewModel: CardsViewModel
    @Environment(\.colorScheme) var colorScheme
    
    init() {
        let username = UserDefaults.standard.string(forKey: "storedUsername") ?? ""
        _viewModel = StateObject(wrappedValue: CardsViewModel(username: username))
    }
    
    // Grille adaptative : chaque cellule a une largeur minimale de 150
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    // On affiche uniquement les cartes que le joueur possède (débloquées)
                    ForEach(viewModel.cards.filter { viewModel.ownedCards[$0.id] != nil }) { card in
                        NavigationLink(destination: MatchmakingView(selectedCard: card, viewModel: viewModel)) {
                            VStack(spacing: 6) {
                                // Image carrée : occupe presque toute la largeur intérieure
                                Image(card.photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 134, height: 134)  // 150 - 2*8 = 134
                                    .clipped()
                                    .cornerRadius(5)
                                
                                // Nom de la carte affiché sur plusieurs lignes,
                                // en noir en mode clair, blanc en mode sombre
                                Text(card.nom)
                                    .font(.headline)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // Statistiques ATK et PV (pour les cartes débloquées, elles sont dans viewModel.ownedCards)
                                HStack(spacing: 4) {
                                    if let owned = viewModel.ownedCards[card.id] {
                                        Text("ATK: \(owned.current_atk)")
                                            .foregroundColor(.red)
                                            .font(.subheadline)
                                        Text("PV: \(owned.current_pv)")
                                            .foregroundColor(.green)
                                            .font(.subheadline)
                                    }
                                }
                                
                                // Statut affiché en bleu (car toutes ces cartes sont débloquées)
                                Text("Débloquée")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(8)
                            .frame(width: 150, height: 240)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Sélectionnez votre carte")
        }
    }
}

struct SelectMultiplayerCardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SelectMultiplayerCardView()
        }
    }
}
