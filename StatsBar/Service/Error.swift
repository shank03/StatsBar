//
//  Error.swift
//  StatsBar
//
//  Created by Shashank on 14/11/24.
//

import Foundation

enum ServiceError: Error {
    case matchingServiceNotFound
    case errorReadingIORegistry
    case powerManagerRegistryNotFound
    case dictionaryNull(for: String)
    case valueNotFound(key: String)
    case noCpuCores
    case failedToReadPipe
    case failedDeserialization
    case unableToCheckChannels
    case noIOChannels
    case errorOwningChannels
    case failedToGetChannelSubscription
    case unexpectedError(msg: String)

    func getMessage() -> String {
        switch self {
        case .matchingServiceNotFound:
            return "Matching Service not found. Please contact developer"
        case .errorReadingIORegistry:
            return "Failed to read IO entry. Please contact developer"
        case .powerManagerRegistryNotFound:
            return "Power manager registry not found"
        case .dictionaryNull(let f):
            return "Dictionary null for '\(f)'"
        case .valueNotFound(let key):
            return "Value not found for key '\(key)'"
        case .noCpuCores:
            return "No CPU cores found"
        case .failedToReadPipe:
            return "Failed to read process pipe"
        case .failedDeserialization:
            return "Failed to deserialize pipe"
        case .noIOChannels:
            return "No channels found for IOReport"
        case .unableToCheckChannels:
            return "Failed to access list of channels"
        case .errorOwningChannels:
            return "Failed to own IO channels"
        case .failedToGetChannelSubscription:
            return "Failed to get channels subscription"
        case .unexpectedError(let msg):
            return "Something went wrong: \(msg)"
        }
    }
}
