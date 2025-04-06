import SwiftUI

struct CardsCollectionView: View {
    @AppStorage("storedUsername") var storedUsername: String = ""
    @StateObject var viewModel: CardsViewModel
    @Environment(\.colorScheme) var colorScheme

    init() {
        let username = UserDefaults.standard.string(forKey: "storedUsername") ?? ""
        _viewModel = StateObject(wrappedValue: CardsViewModel(username: username))
    }
    
    // Grille adaptative avec une largeur minimale de 150 pour chaque cellule
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.cards) { card in
                        NavigationLink(destination: CardView(card: card, viewModel: viewModel)) {
                            VStack(spacing: 6) {
                                // Image carrée : 134x134 (150 - 8*2)
                                Image(card.photo)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 134, height: 134)
                                    .cornerRadius(5)
                                
                                // Nom de la carte (plusieurs lignes)
                                Text(card.nom)
                                    .font(.headline)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // Statistiques ATK et PV
                                HStack(spacing: 4) {
                                    if let owned = viewModel.ownedCards[card.id] {
                                        Text("ATK: \(owned.current_atk)")
                                            .foregroundColor(.red)
                                            .font(.subheadline)
                                        Text("PV: \(owned.current_pv)")
                                            .foregroundColor(.green)
                                            .font(.subheadline)
                                    } else {
                                        Text("ATK: \(card.base_atk)")
                                            .foregroundColor(.red)
                                            .font(.subheadline)
                                        Text("PV: \(card.base_pv)")
                                            .foregroundColor(.green)
                                            .font(.subheadline)
                                    }
                                }
                                
                                // Statut de la carte
                                Text(viewModel.ownedCards[card.id] != nil ? "Débloquée" : "À acheter")
                                    .font(.caption)
                                    .foregroundColor(
                                        viewModel.ownedCards[card.id] != nil
                                        ? .blue
                                        : Color(red: 0.8, green: 0.7, blue: 0.0)
                                    )
                            }
                            // Écart identique sur tous les côtés
                            .padding(8)
                            // Taille globale de la « carte »
                            .frame(width: 150, height: 240)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Collection de Cartes")
            .toolbar {
                if let currency = viewModel.player?.currency {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("Crédits: \(currency)")
                            .font(.headline)
                    }
                }
            }
        }
    }
}

struct CardsCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CardsCollectionView()
        }
    }
} 
