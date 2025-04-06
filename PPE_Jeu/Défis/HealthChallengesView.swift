import SwiftUI
import HealthKit

struct HealthChallengesView: View {
    let player: Player  // Le joueur connecté, transmis depuis votre logique d'authentification

    // Onglet sélectionné : 0 = Activité, 1 = Sommeil
    @State private var selectedTab: Int = 0

    // Données pour les défis de pas
    @State private var averageSteps: Double?
    @State private var todaySteps: Double?
    @State private var dailyProgress: Double = 0.0
    @State private var weekDaysMeetingTarget: Int = 0

    // Données pour les défis de sommeil
    @State private var averageSleep: Double?      // Moyenne de sommeil (temps au lit) du mois précédent en heures
    @State private var lastNightSleep: Double?      // Temps passé au lit la nuit dernière en heures

    @State private var isLoading: Bool = true
    @StateObject private var healthKitManager = HealthKitManager()

    // Acceptation des crédits pour défis de pas
    @State private var acceptedDaily: Bool = false
    @State private var acceptedWeekly1: Bool = false
    @State private var acceptedWeekly2: Bool = false
    @State private var acceptedWeekly3: Bool = false
    @State private var acceptedWeekly4: Bool = false

    // Acceptation des crédits pour défis de sommeil
    @State private var acceptedSleep6: Bool = false
    @State private var acceptedSleep7: Bool = false
    @State private var acceptedSleep8: Bool = false

    // Alerte pour l'objectif de pas (explication)
    @State private var showObjectiveInfo: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                Picker("Challenges", selection: $selectedTab) {
                    Text("Activité").tag(0)
                    Text("Sommeil").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                ScrollView {
                    if selectedTab == 0 {
                        stepsChallengesSection
                    } else {
                        sleepChallengesSection
                    }
                }
            }
            .navigationTitle("")
            .onAppear {
                loadAcceptedChallenges(for: player)
                healthKitManager.requestAuthorization { success, error in
                    if success {
                        fetchStepsData()
                        fetchSleepData()
                    } else {
                        DispatchQueue.main.async {
                            self.isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Steps Challenges Section

    var stepsChallengesSection: some View {
        VStack(spacing: 20) {
            if let avg = averageSteps {
                let objective = min(max(avg * 1.15, 5000), 12000)
                Button(action: {
                    showObjectiveInfo = true
                }) {
                    VStack {
                        Text("Objectif de pas")
                            .font(.headline)
                        Text("\(Int(objective)) pas")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .underline()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .alert(isPresented: $showObjectiveInfo) {
                    Alert(
                        title: Text("Comment est calculé l'objectif ?"),
                        message: Text("L'objectif est calculé en prenant la moyenne des pas du mois précédent et en la multipliant par 1,15.\n\nMoyenne du mois précédent : \(Int(avg)) pas\nObjectif : \(Int(objective)) pas\n\nLe minimum recommandé est de 5000 pas et l'objectif est plafonné à 12000 pas."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            } else if isLoading {
                ProgressView("Chargement de l'objectif…")
            } else {
                Text("Erreur lors de la récupération de l'objectif.")
            }
            
            if let avg = averageSteps, let today = todaySteps {
                let objective = min(max(avg * 1.15, 5000), 12000)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Défi Quotidien")
                        .font(.headline)
                    Text("Dépasser \(Int(objective)) pas aujourd'hui")
                        .font(.subheadline)
                    ProgressView(value: dailyProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("Aujourd'hui : \(Int(today)) pas")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if today >= objective && !acceptedDaily {
                        Button("Accepter 50 crédits") {
                            acceptChallenge(challenge: "daily")
                        }
                        .font(.caption)
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(10)
            }
            
            if let _ = averageSteps {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Défis Hebdomadaires")
                        .font(.headline)
                    
                    WeeklyChallengeResultView(requiredDays: 1, achievedDays: weekDaysMeetingTarget, accepted: acceptedWeekly1) {
                        acceptChallenge(challenge: "weekly1")
                    }
                    WeeklyChallengeResultView(requiredDays: 2, achievedDays: weekDaysMeetingTarget, accepted: acceptedWeekly2) {
                        acceptChallenge(challenge: "weekly2")
                    }
                    WeeklyChallengeResultView(requiredDays: 3, achievedDays: weekDaysMeetingTarget, accepted: acceptedWeekly3) {
                        acceptChallenge(challenge: "weekly3")
                    }
                    WeeklyChallengeResultView(requiredDays: 4, achievedDays: weekDaysMeetingTarget, accepted: acceptedWeekly4) {
                        acceptChallenge(challenge: "weekly4")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            
            Text("Les défis hebdomadaires se réinitialisent chaque lundi à 00:00")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 10)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Sleep Challenges Section

    var sleepChallengesSection: some View {
        VStack(spacing: 20) {
            if let avgSleep = averageSleep {
                VStack {
                    Text("Moyenne de sommeil du mois précédent")
                        .font(.headline)
                    Text("\(String(format: "%.1f", avgSleep)) heures")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            } else if isLoading {
                ProgressView("Chargement de l'objectif de sommeil…")
            } else {
                Text("Erreur lors de la récupération de l'objectif de sommeil.")
            }
            
            if let lastNight = lastNightSleep {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Défi Sommeil Quotidien")
                        .font(.headline)
                    
                    SleepChallengeResultView(threshold: 6, achieved: lastNight >= 6, accepted: acceptedSleep6) {
                        acceptSleepChallenge(challenge: "sleep6")
                    }
                    SleepChallengeResultView(threshold: 7, achieved: lastNight >= 7, accepted: acceptedSleep7) {
                        acceptSleepChallenge(challenge: "sleep7")
                    }
                    SleepChallengeResultView(threshold: 8, achieved: lastNight >= 8, accepted: acceptedSleep8) {
                        acceptSleepChallenge(challenge: "sleep8")
                    }
                    
                    Text("Les défis de sommeil se réinitialisent chaque lundi à 00:00")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Data Retrieval for Steps

    func fetchStepsData() {
        fetchTargetSteps()
        fetchTodaySteps()
        fetchWeeklySteps()
    }
    
    func fetchTargetSteps() {
        let calendar = Calendar.current
        let now = Date()
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            self.isLoading = false
            return
        }
        guard let previousMonthEnd = calendar.date(byAdding: .day, value: -1, to: currentMonthStart) else {
            self.isLoading = false
            return
        }
        let previousMonthComponents = calendar.dateComponents([.year, .month], from: previousMonthEnd)
        guard let previousMonthStart = calendar.date(from: previousMonthComponents) else {
            self.isLoading = false
            return
        }
        
        print("Récupération des pas du \(previousMonthStart) au \(previousMonthEnd) pour l'objectif")
        healthKitManager.fetchAverageSteps(from: previousMonthStart, to: previousMonthEnd) { average, error in
            DispatchQueue.main.async {
                if let average = average {
                    self.averageSteps = average
                    fetchTodaySteps()
                    fetchWeeklySteps()
                }
                self.isLoading = false
            }
        }
    }
    
    func fetchTodaySteps() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayEnd = Date()
        healthKitManager.fetchSteps(from: todayStart, to: todayEnd) { steps, error in
            DispatchQueue.main.async {
                self.todaySteps = steps
                if let target = self.averageSteps, let today = self.todaySteps, target > 0 {
                    self.dailyProgress = min(today / target, 1.0)
                }
            }
        }
    }
    
    func fetchWeeklySteps() {
        guard let target = averageSteps else { return }
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekday + 5) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: now) else { return }
        
        var count = 0
        let group = DispatchGroup()
        for i in 0..<7 {
            if let dayStart = calendar.date(byAdding: .day, value: i, to: weekStart),
               let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) {
                group.enter()
                healthKitManager.fetchSteps(from: dayStart, to: dayEnd) { steps, error in
                    if let steps = steps, steps >= target {
                        count += 1
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            self.weekDaysMeetingTarget = count
        }
    }
    
    // MARK: - Data Retrieval for Sleep

    func fetchSleepData() {
        fetchAverageSleep()
        fetchLastNightSleep()
    }
    
    func fetchAverageSleep() {
        let calendar = Calendar.current
        let now = Date()
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return }
        guard let previousMonthEnd = calendar.date(byAdding: .day, value: -1, to: currentMonthStart) else { return }
        let previousMonthComponents = calendar.dateComponents([.year, .month], from: previousMonthEnd)
        guard let previousMonthStart = calendar.date(from: previousMonthComponents) else { return }
        
        print("Récupération du sommeil (temps au lit) du \(previousMonthStart) au \(previousMonthEnd) pour l'objectif de sommeil")
        healthKitManager.fetchAverageSleep(from: previousMonthStart, to: previousMonthEnd) { average, error in
            DispatchQueue.main.async {
                if let average = average {
                    self.averageSleep = average
                }
            }
        }
    }
    
    func fetchLastNightSleep() {
        let calendar = Calendar.current
        // Période de "temps au lit" supposée de 22:00 hier à 07:00 aujourd'hui
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return }
        var components = calendar.dateComponents([.year, .month, .day], from: yesterday)
        components.hour = 22
        let sleepStart = calendar.date(from: components) ?? yesterday
        components.hour = 7
        let sleepEnd = calendar.date(from: components) ?? Date()
        
        healthKitManager.fetchSleep(from: sleepStart, to: sleepEnd) { sleepHours, error in
            DispatchQueue.main.async {
                if let sleepHours = sleepHours {
                    self.lastNightSleep = sleepHours
                }
            }
        }
    }
    
    // MARK: - Challenge Acceptance for Steps
    
    func acceptChallenge(challenge: String) {
        FirestoreManager().addCredits(for: player, amount: 50) { error in
            DispatchQueue.main.async {
                if error == nil {
                    switch challenge {
                    case "daily":
                        acceptedDaily = true
                        saveAcceptedChallenge(challenge: "daily", for: player)
                    case "weekly1":
                        acceptedWeekly1 = true
                        saveAcceptedChallenge(challenge: "weekly1", for: player)
                    case "weekly2":
                        acceptedWeekly2 = true
                        saveAcceptedChallenge(challenge: "weekly2", for: player)
                    case "weekly3":
                        acceptedWeekly3 = true
                        saveAcceptedChallenge(challenge: "weekly3", for: player)
                    case "weekly4":
                        acceptedWeekly4 = true
                        saveAcceptedChallenge(challenge: "weekly4", for: player)
                    default:
                        break
                    }
                    print("50 crédits ajoutés pour le défi \(challenge)")
                } else {
                    print("Erreur lors de l'ajout de crédits : \(error!.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Challenge Acceptance for Sleep
    
    func acceptSleepChallenge(challenge: String) {
        FirestoreManager().addCredits(for: player, amount: 50) { error in
            DispatchQueue.main.async {
                if error == nil {
                    switch challenge {
                    case "sleep6":
                        acceptedSleep6 = true
                        saveAcceptedChallenge(challenge: "sleep6", for: player)
                    case "sleep7":
                        acceptedSleep7 = true
                        saveAcceptedChallenge(challenge: "sleep7", for: player)
                    case "sleep8":
                        acceptedSleep8 = true
                        saveAcceptedChallenge(challenge: "sleep8", for: player)
                    default:
                        break
                    }
                    print("50 crédits ajoutés pour le défi \(challenge)")
                } else {
                    print("Erreur lors de l'ajout de crédits pour le sommeil : \(error!.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Persistence for Challenge Acceptance
    
    func loadAcceptedChallenges(for player: Player) {
        let defaults = UserDefaults.standard
        acceptedDaily = defaults.bool(forKey: "acceptedDaily_\(player.id)")
        
        let calendar = Calendar.current
        let now = Date()
        let weekComponents = calendar.dateComponents([.year, .weekOfYear], from: now)
        let weekKey = "acceptedWeekly_\(player.id)_\(weekComponents.year ?? 0)_\(weekComponents.weekOfYear ?? 0)"
        acceptedWeekly1 = defaults.bool(forKey: "\(weekKey)_1")
        acceptedWeekly2 = defaults.bool(forKey: "\(weekKey)_2")
        acceptedWeekly3 = defaults.bool(forKey: "\(weekKey)_3")
        acceptedWeekly4 = defaults.bool(forKey: "\(weekKey)_4")
        
        acceptedSleep6 = defaults.bool(forKey: "\(weekKey)_sleep6")
        acceptedSleep7 = defaults.bool(forKey: "\(weekKey)_sleep7")
        acceptedSleep8 = defaults.bool(forKey: "\(weekKey)_sleep8")
    }
    
    func saveAcceptedChallenge(challenge: String, for player: Player) {
        let defaults = UserDefaults.standard
        if challenge == "daily" {
            defaults.set(true, forKey: "acceptedDaily_\(player.id)")
        } else {
            let calendar = Calendar.current
            let now = Date()
            let weekComponents = calendar.dateComponents([.year, .weekOfYear], from: now)
            let weekKey = "acceptedWeekly_\(player.id)_\(weekComponents.year ?? 0)_\(weekComponents.weekOfYear ?? 0)"
            switch challenge {
            case "weekly1":
                defaults.set(true, forKey: "\(weekKey)_1")
            case "weekly2":
                defaults.set(true, forKey: "\(weekKey)_2")
            case "weekly3":
                defaults.set(true, forKey: "\(weekKey)_3")
            case "weekly4":
                defaults.set(true, forKey: "\(weekKey)_4")
            case "sleep6":
                defaults.set(true, forKey: "\(weekKey)_sleep6")
            case "sleep7":
                defaults.set(true, forKey: "\(weekKey)_sleep7")
            case "sleep8":
                defaults.set(true, forKey: "\(weekKey)_sleep8")
            default:
                break
            }
        }
    }
}

struct WeeklyChallengeResultView: View {
    let requiredDays: Int
    let achievedDays: Int
    let accepted: Bool
    let onAccept: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Dépasser l'objectif \(requiredDays) jour(s) durant la semaine :")
                    .font(.subheadline)
                Spacer()
                Text(achievedDays >= requiredDays ? "Oui" : "Non")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(achievedDays >= requiredDays ? .green : .red)
            }
            if achievedDays >= requiredDays && !accepted {
                Button("Accepter 50 crédits") {
                    onAccept()
                }
                .font(.caption)
                .padding(6)
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SleepChallengeResultView: View {
    let threshold: Int  // en heures
    let achieved: Bool
    let accepted: Bool
    let onAccept: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Dormir au moins \(threshold) heures par nuit :")
                    .font(.subheadline)
                Spacer()
                Text(achieved ? "Oui" : "Non")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(achieved ? .green : .red)
            }
            if achieved && !accepted {
                Button("Accepter 50 crédits") {
                    onAccept()
                }
                .font(.caption)
                .padding(6)
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}
