//
//  HealthKitManager.swift
//  PPE_Jeu
//
//  Created by Youssef Ait Elourf on 06/04/2025.
//


import HealthKit
import SwiftUI

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "HealthKit non disponible"]))
            return
        }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(false, NSError(domain: "HealthKit", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Type de données indisponible"]))
            return
        }
        let readTypes: Set<HKObjectType> = [stepType, sleepType]
        healthStore.requestAuthorization(toShare: nil, read: readTypes, completion: completion)
    }
    
    func fetchAverageSteps(from startDate: Date, to endDate: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion(nil, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Type de pas indisponible"]))
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
            guard let statistics = statistics, error == nil else {
                completion(nil, error)
                return
            }
            let totalSteps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            let days = max(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1, 1)
            let average = totalSteps / Double(days)
            completion(average, nil)
        }
        healthStore.execute(query)
    }
    
    func fetchSteps(from startDate: Date, to endDate: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion(nil, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Type de pas indisponible"]))
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
            guard let statistics = statistics, error == nil else {
                completion(nil, error)
                return
            }
            let steps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            completion(steps, nil)
        }
        healthStore.execute(query)
    }
    
    // Retourne le joueur actuel.
    // Remplacez cette logique par la récupération réelle du joueur connecté.
    var currentPlayer: Player? {
        // Par exemple, renvoyez un objet Player déjà présent dans votre projet.
        return nil
    }
}


extension HealthKitManager {
    func fetchAverageSleep(from startDate: Date, to endDate: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil, NSError(domain: "HealthKit", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Type de sommeil indisponible"]))
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, results, error in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let samples = results as? [HKCategorySample] else {
                completion(nil, nil)
                return
            }
            var totalInBed: Double = 0
            for sample in samples {
                // Utilisez 'inBed' pour le temps passé au lit
                if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                    totalInBed += sample.endDate.timeIntervalSince(sample.startDate)
                }
            }
            let totalHours = totalInBed / 3600
            let days = max(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1, 1)
            let averageInBed = totalHours / Double(days)
            completion(averageInBed, nil)
        }
        healthStore.execute(query)
    }
    
    func fetchSleep(from startDate: Date, to endDate: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil, NSError(domain: "HealthKit", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Type de sommeil indisponible"]))
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, results, error in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let samples = results as? [HKCategorySample] else {
                completion(nil, nil)
                return
            }
            var totalInBed: Double = 0
            for sample in samples {
                if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                    totalInBed += sample.endDate.timeIntervalSince(sample.startDate)
                }
            }
            let hours = totalInBed / 3600
            completion(hours, nil)
        }
        healthStore.execute(query)
    }
}
