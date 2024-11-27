//
//  IOReport.swift
//  StatsBar
//
//  Created by Shashank on 23/11/24.
//

import Foundation
import CoreFoundation
import IOKit

struct IOSample {
    let group: String
    let subGroup: String
    let channel: String
    let unit: String
    let delta: CFDictionary
}

private func collectIOSamples(data: CFDictionary) -> [IOSample] {
    let dict = data as! [String: Any]
    let items = dict["IOReportChannels"] as! CFArray
    let itemSize = CFArrayGetCount(items)

    var samples = [IOSample]()

    for index in 0..<itemSize {
        let dict = CFArrayGetValueAtIndex(items, index)
        let item = unsafeBitCast(dict, to: CFDictionary.self)

        let group = IOReportChannelGetGroup(item)?.takeUnretainedValue() ?? ("" as CFString)
        let subGroup = IOReportChannelGetSubGroup(item)?.takeUnretainedValue() ?? ("" as CFString)
        let channel = IOReportChannelGetChannelName(item)?.takeUnretainedValue() ?? ("" as CFString)
        let unit = IOReportChannelGetUnitLabel(item)?.takeUnretainedValue() ?? ("" as CFString)

        samples.append(IOSample(group: group as String, subGroup: subGroup as String, channel: channel as String, unit: unit as String, delta: item))
    }

    return samples
}

class IOReport {
    private let channels: CFMutableDictionary
    private let subscription: IOReportSubscriptionRef
    private var prev: (samples: CFDictionary, time: TimeInterval)?

    init() throws {
        self.channels = try getIOChannels()
        self.subscription = try getIOSubscription(chan: channels)
        self.prev = nil
    }

//    func getSample(duration: UInt64) async throws -> [IOSample] {
//        guard let sampleF = IOReportCreateSamples(self.subscription, self.channels, nil)?.takeRetainedValue() else {
//            throw ServiceError.unexpectedError(msg: "Sample empty in creation [1]")
//        }
//
//        try await Task.sleep(nanoseconds: UInt64(duration * NSEC_PER_MSEC))
//
//        guard let sampleS = IOReportCreateSamples(self.subscription, self.channels, nil)?.takeRetainedValue() else {
//            throw ServiceError.unexpectedError(msg: "Sample empty in creation [2]")
//        }
//
//        guard let delta = IOReportCreateSamplesDelta(sampleF, sampleS, nil)?.takeRetainedValue() else {
//            throw ServiceError.unexpectedError(msg: "Sample delta nil")
//        }
//
//        return collectIOSamples(data: delta)
//    }

    func getSamples(duration: Int, count: Int) async throws -> [([IOSample], TimeInterval)] {
        let step = UInt64(duration / count)
        var prev = self.prev == nil ? try self.rawSample() : self.prev!

        var samples = [([IOSample], TimeInterval)]()

        for _ in 0..<count {
            try await Task.sleep(nanoseconds: UInt64(step * NSEC_PER_MSEC))
            let next = try self.rawSample()
            guard let diff = IOReportCreateSamplesDelta(prev.samples, next.samples, nil)?.takeRetainedValue() else {
                throw ServiceError.unexpectedError(msg: "Diff null in sample delta")
            }

            let elapsed = Date(timeIntervalSince1970: next.time).timeIntervalSince(Date(timeIntervalSince1970: prev.time))
            prev = next

            samples.append((collectIOSamples(data: diff), max(elapsed, TimeInterval(1))))
        }

        self.prev = prev

        return samples
    }

    private func rawSample() throws -> (samples: CFDictionary, time: TimeInterval) {
        guard let sample = IOReportCreateSamples(self.subscription, self.channels, nil)?.takeRetainedValue() else {
            throw ServiceError.unexpectedError(msg: "RawSample - no value")
        }
        return (sample, Date().timeIntervalSince1970)
    }
}

private func getIOChannels() throws -> CFMutableDictionary {
    let channelNames = [
        ("Energy Model", nil),
        ("CPU Stats", "CPU Complex Performance States"),
        ("CPU Stats", "CPU Core Performance States"),
        ("GPU Stats", "GPU Performance States"),
    ]

    var channels = [CFDictionary]()
    for (gname, sname) in channelNames {
        let channel = IOReportCopyChannelsInGroup(gname as CFString?, sname as CFString?, 0, 0, 0)
        guard let channel = channel?.takeRetainedValue() else {
            print("Channel empty for name: \(gname): \(sname ?? "")")
            continue
        }
        channels.append(channel)
    }

    let chan = channels[0]
    for i in 1..<channels.count {
        IOReportMergeChannels(chan, channels[i], nil)
    }

    let size = CFDictionaryGetCount(chan)
    guard let channel = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, size, chan) else {
        throw ServiceError.errorOwningChannels
    }

    guard let chan = channel as? [String: Any] else {
        throw ServiceError.unableToCheckChannels
    }
    guard let _ = chan["IOReportChannels"] else {
        throw ServiceError.noIOChannels
    }

    return channel
}

private func getIOSubscription(chan: CFMutableDictionary) throws -> IOReportSubscriptionRef {
    var s: Unmanaged<CFMutableDictionary>?
    guard let subs = IOReportCreateSubscription(nil, chan, &s, 0, nil) else {
        throw ServiceError.failedToGetChannelSubscription
    }

    return subs
}
