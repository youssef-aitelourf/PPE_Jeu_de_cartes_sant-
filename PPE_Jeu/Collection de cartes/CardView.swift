import SwiftUI

struct CardView: View {
    let card: Card
    @ObservedObject var viewModel: CardsViewModel

    // Actions pouvant déclencher une alerte de confirmation
    enum PendingAction {
        case purchase, upgradeATK, upgradePV
    }
    
    // Enum pour l'alerte active, qui peut être soit une alerte de confirmation, soit une alerte pour crédits insuffisants
    enum ActiveAlert: Identifiable {
        case confirmation(PendingAction)
        case insufficient(String)
        
        var id: Int {
            switch self {
            case .confirmation(let action):
                switch action {
                case .purchase: return 0
                case .upgradeATK: return 1
                case .upgradePV: return 2
                }
            case .insufficient:
                return 3
            }
        }
    }
    
    @State private var activeAlert: ActiveAlert?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                
                // Cadre de la carte avec image, nom, stats et description
                VStack(alignment: .center, spacing: 16) {
                    Image(card.photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300) // L'image occupe presque toute la largeur du cadre
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Nom de la carte (affiché dans le cadre)
                    Text(card.nom)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    // Statistiques : ATK (rouge) et PV (vert) en taille plus grande
                    HStack(spacing: 40) {
                        if let owned = viewModel.ownedCards[card.id] {
                            Text("ATK: \(owned.current_atk)")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("PV: \(owned.current_pv)")
                                .foregroundColor(.green)
                                .font(.title2)
                        } else {
                            Text("ATK: \(card.base_atk)")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("PV: \(card.base_pv)")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    
                    // Description en plus petit
                    Text(card.description_carte)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.footnote)
                    
                }
                .padding()
                .frame(maxWidth: 350, minHeight: 500, alignment: .center)
                // Fond et contour dynamiques suivant le mode clair/sombre
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(UIColor.separator), lineWidth: 2)
                )
                
                // Boutons d'achat ou d'upgrade avec vérification du solde
                if let owned = viewModel.ownedCards[card.id] {
                    HStack(spacing: 20) {
                        Button("Upgrade ATK (+5)") {
                            if let currency = viewModel.player?.currency, currency >= 100 {
                                activeAlert = .confirmation(.upgradeATK)
                            } else {
                                activeAlert = .insufficient("Pas assez de crédits pour upgrader l'ATK.")
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        Button("Upgrade PV (+5)") {
                            if let currency = viewModel.player?.currency, currency >= 100 {
                                activeAlert = .confirmation(.upgradePV)
                            } else {
                                activeAlert = .insufficient("Pas assez de crédits pour upgrader le PV.")
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                } else {
                    Button("Acheter pour \(card.price) crédits") {
                        if let currency = viewModel.player?.currency, currency >= card.price {
                            activeAlert = .confirmation(.purchase)
                        } else {
                            activeAlert = .insufficient("Pas assez de crédits pour acheter cette carte.")
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            // Un seul modificateur .alert pour gérer les deux types d'alerte
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .confirmation(let action):
                    switch action {
                    case .purchase:
                        return Alert(
                            title: Text("Confirmation"),
                            message: Text("Êtes-vous sûr de vouloir acheter cette carte pour \(card.price) crédits ?"),
                            primaryButton: .default(Text("Confirmer"), action: {
                                activeAlert = nil
                                viewModel.purchase(card: card) { error in
                                    if let error = error {
                                        print("Erreur achat: \(error.localizedDescription)")
                                    }
                                }
                            }),
                            secondaryButton: .cancel({
                                activeAlert = nil
                            })
                        )
                    case .upgradeATK:
                        return Alert(
                            title: Text("Confirmation"),
                            message: Text("Êtes-vous sûr de vouloir dépenser 100 crédits pour upgrader l'ATK ?"),
                            primaryButton: .default(Text("Confirmer"), action: {
                                activeAlert = nil
                                if let owned = viewModel.ownedCards[card.id] {
                                    viewModel.upgradeCard(cardPlayer: owned, type: "atk") { error in
                                        if let error = error {
                                            print("Erreur upgrade ATK: \(error.localizedDescription)")
                                        }
                                    }
                                }
                            }),
                            secondaryButton: .cancel({
                                activeAlert = nil
                            })
                        )
                    case .upgradePV:
                        return Alert(
                            title: Text("Confirmation"),
                            message: Text("Êtes-vous sûr de vouloir dépenser 100 crédits pour upgrader le PV ?"),
                            primaryButton: .default(Text("Confirmer"), action: {
                                activeAlert = nil
                                if let owned = viewModel.ownedCards[card.id] {
                                    viewModel.upgradeCard(cardPlayer: owned, type: "pv") { error in
                                        if let error = error {
                                            print("Erreur upgrade PV: \(error.localizedDescription)")
                                        }
                                    }
                                }
                            }),
                            secondaryButton: .cancel({
                                activeAlert = nil
                            })
                        )
                    }
                case .insufficient(let message):
                    return Alert(
                        title: Text("Attention"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"), action: {
                            activeAlert = nil
                        })
                    )
                }
            }
        }
        // Pas de titre dans la navigation (le nom est affiché dans le cadre)
        .navigationTitle("")
        .toolbar {
            // Affichage des crédits en haut à droite
            if let currency = viewModel.player?.currency {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("Crédits: \(currency)")
                        .font(.headline)
                }
            }
        }
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        let dummyVM = CardsViewModel(username: "test")
        NavigationView {
            CardView(
                card: Card(
                    id: "dummy",
                    nom: "Exemple",
                    base_atk: 10,
                    base_pv: 20,
                    price: 100,
                    description_carte: "Description de la carte",
                    photo: "Invocateur_des_étoiles"
                ),
                viewModel: dummyVM
            )
        }
    }
}
