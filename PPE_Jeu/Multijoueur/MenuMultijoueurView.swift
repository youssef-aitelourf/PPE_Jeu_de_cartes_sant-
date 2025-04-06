import SwiftUI

struct MenuMultijoueurView: View {
    var body: some View {
        VStack(spacing: 40) {
            Text("Menu Multijoueur")
                .font(.largeTitle)
                .padding(.top, 40)
            
            NavigationLink(destination: SelectMultiplayerCardView()) {
                Text("Jouer en ligne")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            NavigationLink(destination: ClassementMondialView(viewModel: CardsViewModel(username: UserDefaults.standard.string(forKey: "storedUsername") ?? ""))) {
                Text("Classement mondial")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .navigationTitle("Multijoueur")
    }
}

struct MenuMultijoueurView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MenuMultijoueurView()
        }
    }
}
