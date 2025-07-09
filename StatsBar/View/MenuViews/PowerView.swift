//
//  PowerView.swift
//  StatsBar
//
//  Created by Shashank Verma on 09/07/25.
//

import SwiftUI

struct PowerView: View {

    var metrics: Metrics

    var body: some View {
        HStack(alignment: .center) {
            HStack {
                Text("Power")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text(String(format: "%.2f W", arguments: [metrics.sysPower]))
                    .font(.callout)
            }

            Divider()

            HStack {
                Text("CPU")
                    .font(.callout)
                Spacer()
                Text(String(format: "%.2f W", arguments: [metrics.cpuPower / 1000.0]))
                    .font(.callout)
            }

            Divider()

            HStack {
                Text("GPU")
                    .font(.callout)
                Spacer()
                Text(String(format: "%.2f W", arguments: [metrics.gpuPower / 1000.0]))
                    .font(.callout)
            }

            Divider()

            HStack {
                Text("ANE")
                    .font(.callout)
                Spacer()
                Text(String(format: "%.2f W", arguments: [metrics.anePower / 1000.0]))
                    .font(.callout)
            }
        }
    }
}
