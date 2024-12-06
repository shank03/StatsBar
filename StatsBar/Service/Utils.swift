//
//  Uitls.swift
//  StatsBar
//
//  Created by Shashank on 26/11/24.
//
//  Referenced: https://github.com/exelban/stats
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

public struct Units {
    public let bytes: Int64

    public init(bytes: Int64) {
        self.bytes = bytes
    }

    public var kilobytes: Double {
        return Double(bytes) / 1_024
    }
    public var megabytes: Double {
        return kilobytes / 1_024
    }
    public var gigabytes: Double {
        return megabytes / 1_024
    }
    public var terabytes: Double {
        return gigabytes / 1_024
    }

    public func getReadableString() -> String {
        switch bytes {
        case 0..<1_024:
            return "0 KB/s"
        case 1_024..<(1_024 * 1_024):
            return "\(String(format: "%.0f", kilobytes)) KB/s"
        case 1_024..<(1_024 * 1_024 * 100):
            return "\(String(format: "%.1f", megabytes)) MB/s"
        case (1_024 * 1_024 * 100)..<(1_024 * 1_024 * 1_024):
            return "\(String(format: "%.0f", megabytes)) MB/s"
        case (1_024 * 1_024 * 1_024)...Int64.max:
            return "\(String(format: "%.1f", gigabytes)) GB/s"
        default:
            return "\(String(format: "%.0f", kilobytes)) KB/s"
        }
    }
}

public struct DiskSize {
    public let value: Int64

    public init(size: Int64) {
        self.value = size
    }

    public var kilobytes: Double {
        return Double(value) / 1_000
    }
    public var megabytes: Double {
        return kilobytes / 1_000
    }
    public var gigabytes: Double {
        return megabytes / 1_000
    }
    public var terabytes: Double {
        return gigabytes / 1_000
    }

    public func getReadableMemory() -> String {
        switch value {
        case 0..<1_000:
            return "0 KB"
        case 1_000..<(1_000 * 1_000):
            return String(format: "%.0f KB", kilobytes)
        case 1_000..<(1_000 * 1_000 * 1_000):
            return String(format: "%.0f MB", megabytes)
        case 1_000..<(1_000 * 1_000 * 1_000 * 1_000):
            return String(format: "%.1f GB", gigabytes)
        case (1_000 * 1_000 * 1_000 * 1_000)...Int64.max:
            return String(format: "%.1f TB", terabytes)
        default:
            return String(format: "%.0f KB", kilobytes)
        }
    }
}
