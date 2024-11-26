//
//  Uitls.swift
//  StatsBar
//
//  Created by Shashank on 26/11/24.
//

import IOKit

func getIOServices(service: String) throws -> [(name: String, next: io_object_t)] {
    var result: [(name: String, next: io_object_t)] = []

    let service = IOServiceMatching(service)!
    var iter = io_iterator_t(0);
    if IOServiceGetMatchingServices(0, service, &iter) != 0 {
        print("Error: Service not found")
        throw ServiceError.matchingServiceNotFound
    }

    while case let next = IOIteratorNext(iter), next != 0 {
        var buff = [CChar](repeating: 0, count: 128)
        if IORegistryEntryGetName(next, &buff) != 0 {
            print("Error reading entry name: \(next)")
            throw ServiceError.errorReadingIORegistry
        }

        buff.withUnsafeBufferPointer { ptr in
            let data = String(cString: ptr.baseAddress!)
            result.append((name: data, next: next))
        }
    }

    return result
}
