//
//  IOReport.swift
//  StatsBar
//
//  Created by Shashank on 23/11/24.
//

import Foundation
import CoreFoundation
import IOKit

struct IOReport {

    let channels: CFMutableDictionary
    let subscription: IOReportSubscriptionRef

    init() throws {
        self.channels = try getIOChannels()
        self.subscription = try getIOSubscription(chan: channels)
    }
}

func getIOChannels() throws -> CFMutableDictionary {
    let channelNames = [
        ("Energy Model", nil),
        ("CPU Stats", "CPU Complex Performance States"),
        ("CPU Stats", "CPU Core Performance States"),
        ("GPU Stats", "GPU Performance States"),
    ]

    var channels: [CFDictionary] = []
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

func getIOSubscription(chan: CFMutableDictionary) throws -> IOReportSubscriptionRef {
    var s: Unmanaged<CFMutableDictionary>?
    guard let subs = IOReportCreateSubscription(nil, chan, &s, 0, nil) else {
        throw ServiceError.failedToGetChannelSubscription
    }

    return subs
}
