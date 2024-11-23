//
//  Metrics.swift
//  StatsBar
//
//  Created by Shashank on 14/11/24.
//

import Foundation
import CoreFoundation
import IOKit

struct Metrics {

    func test() throws {
        let socInfo = try SOCInfo()

        print("\(socInfo)")
    }
}
