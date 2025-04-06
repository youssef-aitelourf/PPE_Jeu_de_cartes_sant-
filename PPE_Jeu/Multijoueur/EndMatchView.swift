import SwiftUI

struct EndMatchView: View {
    let didWin: Bool
    let infoText: String
    
    // On reçoit la valeur (positive si gagné, négative si perdu)
    let expDelta: Int
    
    var body: some View {
        VStack(spacing: 30) {
            if didWin {
                Text("Vous avez gagné !")
                    .font(.largeTitle)
                    .foregroundColor(.green)
            } else {
                Text("Vous avez perdu...")
                    .font(.largeTitle)
                    .foregroundColor(.red)
            }
            
            Text(infoText)
                .multilineTextAlignment(.center)
            
            if expDelta > 0 {
                Text("Vous gagnez +\(expDelta) EXP.")
                    .foregroundColor(.green)
            } else if expDelta < 0 {
                // expDelta est négatif, on affiche par exemple `-10`
                Text("Vous perdez \(expDelta) EXP.")
                    .foregroundColor(.red)
            } else {
                Text("Aucun changement d'EXP.")
            }
            
            NavigationLink(destination: MainView().navigationBarBackButtonHidden(true)) {
                Text("Retour au menu principal")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
}
