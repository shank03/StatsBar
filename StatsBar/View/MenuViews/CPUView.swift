//
//  CPUView.swift
//  StatsBar
//
//  Created by Shashank Verma on 09/07/25.
//

import SwiftUI
import Charts
import Collections

struct CPUView: View {
    @Environment(\.self) var environment

    @Binding var sampler: Sampler?
    var metrics: Metrics
    @Binding var usageGraph: Deque<UsagePoint>

    init(sampler: Binding<Sampler?>, metrics: Metrics, usageGraph: Binding<Deque<UsagePoint>>) {
        self._sampler = sampler
        self.metrics = metrics
        self._usageGraph = usageGraph
    }

    @State private var eCpuSelection: UInt64? = nil
    @State private var pCpuSelection: UInt64? = nil
    @State private var gpuSelection: UInt64? = nil

    private var graphShape = RoundedRectangle(cornerRadius: 12)

    var body: some View {
        VStack(spacing: 8) {
            Text("\(self.sampler?.socInfo.chipName ?? "") (\(self.sampler?.socInfo.eCores ?? 0)E + \(self.sampler?.socInfo.pCores ?? 0)P + \(self.sampler?.socInfo.gpuCores ?? 0)GPU)")
                .font(.callout)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                VStack(spacing: 4) {
                    Chart(self.usageGraph) {
                        AreaMark(
                            x: .value("X", $0.id),
                            y: .value("Y", $0.eCpuUsage[0])
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.blue)

                        if let eCpuSelection {
                            RuleMark(x: .value("X", eCpuSelection))
                                .foregroundStyle(Color.blue)
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                    ZStack {
                                        if let usage = (self.usageGraph.first { $0.id == eCpuSelection }) {
                                            Text(String(format: "%.2f%%  %.2f GHz", arguments: usage.eCpuUsage))
                                                .font(.callout)
                                                .foregroundStyle(Color.blue.adaptedTextColor(self.environment))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background {
                                        RoundedRectangle(cornerRadius: 10)
                                            .foregroundStyle(Color.blue)
                                    }
                                }
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                    .chartYScale(domain: [0, 100])
                    .chartXSelection(value: $eCpuSelection)
                    .clipShape(self.graphShape)
                    .overlay(self.graphShape.stroke(.gray, lineWidth: 1))

                    Spacer()

                    Chart(self.usageGraph) {
                        AreaMark(
                            x: .value("X", $0.id),
                            y: .value("Y", $0.pCpuUsage[0])
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.green)

                        if let pCpuSelection {
                            RuleMark(x: .value("X", pCpuSelection))
                                .foregroundStyle(Color.green)
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                    ZStack {
                                        if let usage = (self.usageGraph.first { $0.id == pCpuSelection }) {
                                            Text(String(format: "%.2f%%  %.2f GHz", arguments: usage.pCpuUsage))
                                                .font(.callout)
                                                .foregroundStyle(Color.green.adaptedTextColor(self.environment))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background {
                                        RoundedRectangle(cornerRadius: 10)
                                            .foregroundStyle(Color.green)
                                    }
                                }
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                    .chartYScale(domain: [0, 100])
                    .chartXSelection(value: $pCpuSelection)
                    .clipShape(self.graphShape)
                    .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
                }

                Spacer()

                Chart(self.usageGraph) {
                    AreaMark(
                        x: .value("X", $0.id),
                        y: .value("Y", $0.gpuUsage[0])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.orange)

                    if let gpuSelection {
                        RuleMark(x: .value("X", gpuSelection))
                            .foregroundStyle(Color.orange)
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                ZStack {
                                    if let usage = (self.usageGraph.first { $0.id == gpuSelection }) {
                                        Text(String(format: "%.2f%%  %.2f GHz", arguments: usage.gpuUsage))
                                            .font(.callout)
                                            .foregroundStyle(Color.orange.adaptedTextColor(self.environment))
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .foregroundStyle(Color.orange)
                                }
                            }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                .chartYScale(domain: [0, 100])
                .chartXSelection(value: $gpuSelection)
                .clipShape(self.graphShape)
                .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
            }
            .frame(height: 124)
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.blue)
                    .frame(width: 10, height: 10, alignment: .center)
                Text("E-CPU")
                    .font(.callout)
                Spacer()
                Text(String(format: "%.2f%%  %.2f GHz", arguments: metrics.getECPUInfo()))
                    .font(.callout)
            }
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.green)
                    .frame(width: 10, height: 10, alignment: .center)
                Text("P-CPU")
                    .font(.callout)
                Spacer()
                Text(String(format: "%.2f%%  %.2f GHz", arguments: metrics.getPCPUInfo()))
                    .font(.callout)
            }
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.orange)
                    .frame(width: 10, height: 10, alignment: .center)
                Text("GPU")
                    .font(.callout)
                Spacer()
                Text(String(format: "%.2f%%  %.2f GHz", arguments: [metrics.getGPUUsage(), metrics.getGPUFreq()]))
                    .font(.callout)
            }
            .padding(.vertical, 2)

            Spacer()
        }
    }
}
