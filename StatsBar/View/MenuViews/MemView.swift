//
//  MemView.swift
//  StatsBar
//
//  Created by Shashank Verma on 09/07/25.
//

import SwiftUI
import Charts
import Collections

struct MemView: View {
    @Environment(\.self) var environment

    var metrics: Metrics
    @Binding var usageGraph: Deque<UsagePoint>

    init(metrics: Metrics, usageGraph: Binding<Deque<UsagePoint>>) {
        self.metrics = metrics
        self._usageGraph = usageGraph
    }

    @State private var phyMemSelection: UInt64? = nil
    @State private var swapMemSelection: UInt64? = nil

    private var graphShape = RoundedRectangle(cornerRadius: 12)

    var body: some View {
        VStack(spacing: 8) {
            Text("Memory")
                .font(.callout)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Chart(self.usageGraph) {
                    AreaMark(
                        x: .value("X", $0.id),
                        y: .value("Y", $0.memUsage[0])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.red)

                    if let phyMemSelection {
                        RuleMark(x: .value("X", phyMemSelection))
                            .foregroundStyle(Color.red)
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                ZStack {
                                    if let usage = (self.usageGraph.first { $0.id == phyMemSelection }) {
                                        Text(String(format: "%.2f%%  %.2f GB", arguments: usage.memUsage))
                                            .font(.callout)
                                            .foregroundStyle(Color.red.adaptedTextColor(self.environment))
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .foregroundStyle(Color.red)
                                }
                            }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                .chartYScale(domain: [0, 100])
                .chartXSelection(value: $phyMemSelection)
                .clipShape(self.graphShape)
                .overlay(self.graphShape.stroke(.gray, lineWidth: 1))

                Spacer()

                Chart(self.usageGraph) {
                    AreaMark(
                        x: .value("X", $0.id),
                        y: .value("Y", $0.swapUsage[0])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.yellow)

                    if let swapMemSelection {
                        RuleMark(x: .value("X", swapMemSelection))
                            .foregroundStyle(Color.yellow)
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                ZStack {
                                    if let usage = (self.usageGraph.first { $0.id == swapMemSelection }) {
                                        Text(String(format: "%.2f%%  %.2f GB", arguments: usage.swapUsage))
                                            .font(.callout)
                                            .foregroundStyle(Color.yellow.adaptedTextColor(self.environment))
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .foregroundStyle(Color.yellow)
                                }
                            }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                .chartYScale(domain: [0, 100])
                .chartXSelection(value: $swapMemSelection)
                .clipShape(self.graphShape)
                .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
            }
            .frame(height: 124)
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)).foregroundStyle(Color.red).frame(width: 10, height: 10, alignment: .center)
                Text("Physical")
                    .font(.callout)
                Spacer()
                Text(String(format: "%.2f%%", arguments: [metrics.getMemUsage()]))
                    .font(.callout)
                Text(String(format: "%.2f / %d GB", arguments: [metrics.getMemUsed(), metrics.getTotalMemory()]))
                    .font(.callout)
            }
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.yellow)
                    .frame(width: 10, height: 10, alignment: .center)
                Text("Swap")
                    .font(.callout)
                Spacer()
                Text(String(format: "%.2f%%", arguments: [metrics.getSwapUsage()]))
                    .font(.callout)
                Text(String(format: "%.2f / %d GB", arguments: [metrics.getSwapUsed(), metrics.getTotalSwap()]))
                    .font(.callout)
            }
            .padding(.vertical, 2)

            Spacer()
        }
    }
}
