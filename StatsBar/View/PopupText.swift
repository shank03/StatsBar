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
                HStack(spacing: 8) {
                    //                    Image(systemName: "cpu")
                    //                        .font(.system(size: 15))
                    VStack {
                        Text("CPU").font(.system(size: 8))
                        //                        Text(String(format: "%.2f / %.2f GHz", arguments: metric.getCPUFreqs()))
                        //                            .font(.footnote)
                        Text(String(format: "%.1f%%", arguments: [metric.getCPUUsage()]))
                            .font(.callout)
                    }

                    //                    Image(systemName: "cpu.fill")
                    //                        .font(.system(size: 15))
                    VStack {
                        Text("GPU").font(.system(size: 8))
                        Text(String(format: "%.1f%%", arguments: [metric.getGPUUsage()]))
                            .font(.callout)
                        //                        Text(String(format: "%.2f GHz", arguments: [metric.getGPUFreq()]))
                        //                            .font(.footnote)
                    }

                    //                    Text(" | ")
                    //                    Image(systemName: "memorychip")
                    //                        .font(.system(size: 10))

                    VStack {
                        Text("MEM").font(.system(size: 8))
                        Text(String(format: "%.1f GB", arguments: [metric.getMemUsed()]))
                            .font(.callout)
                        //                        Text(String(format: "%.2f GHz", arguments: [metric.getGPUFreq()]))
                        //                            .font(.footnote)
                    }
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
