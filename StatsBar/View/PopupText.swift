//
//  Hello.swift
//  StatsBar
//
//  Created by Shashank on 25/11/24.
//

import SwiftUI

struct PopupText: View {

    var metrics: Metrics?

    var body: some View {
        HStack {
            if let metric = self.metrics {
                HStack(spacing: 3) {
                    Image(systemName: "cpu")
                        .font(.system(size: 15))
                    VStack {
                        Text(String(format: "%.1f%% / %.2f GHz", arguments: metric.getECPUInfo()))
                            .font(.footnote)
                        Text(String(format: "%.1f%% / %.2f GHz", arguments: metric.getPCPUInfo()))
                            .font(.footnote)
                    }

                    Text(" | ")

                    Image(systemName: "cpu.fill")
                        .font(.system(size: 15))
                    VStack {
                        Text(String(format: "%.1f%%", arguments: [metric.getGPUUsage()]))
                            .font(.footnote)
                        Text(String(format: "%.2f GHz", arguments: [metric.getGPUFreq()]))
                            .font(.footnote)
                    }

//                    Text(" | ")
//
//                    Image(systemName: "memorychip")
//                        .font(.system(size: 15))
                }
            } else {
                Text("StatsBar")
            }
        }
    }
}

#Preview {
    PopupText(metrics: nil)
}
