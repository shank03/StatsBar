//
//  NetworkView.swift
//  StatsBar
//
//  Created by Shashank Verma on 09/07/25.
//

import SwiftUI
import Charts
import Collections

struct NetworkView: View {
    @Environment(\.self) var environment

    @Binding var sampler: Sampler?
    var metrics: Metrics
    @Binding var usageGraph: Deque<UsagePoint>

    init(sampler: Binding<Sampler?>, metrics: Metrics, usageGraph: Binding<Deque<UsagePoint>>) {
        self._sampler = sampler
        self.metrics = metrics
        self._usageGraph = usageGraph
    }

    @State private var networkSelection: UInt64? = nil

    private var graphShape = RoundedRectangle(cornerRadius: 12)

    private func getNetworkGraphDomain() -> [Int64] {
        let maxUsage = self.usageGraph.reduce(Int64(0)) { max($0, max(abs($1.networkUsage[0].value), abs($1.networkUsage[1].value))) }
        return [maxUsage * -1, maxUsage]
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Network")
                .font(.callout)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Chart {
                ForEach(self.usageGraph, id: \.id) { usageInfo in
                    ForEach(usageInfo.networkUsage, id: \.type) { networkUsage in
                        AreaMark(
                            x: .value("X", usageInfo.id),
                            y: .value("Y", networkUsage.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("Bytes type", networkUsage.type))
                    }
                }

                if let networkSelection {
                    if let usage = (self.usageGraph.first { $0.id == networkSelection }) {
                        RuleMark(x: .value("X", networkSelection), yStart: 0)
                            .foregroundStyle(
                                LinearGradient(
                                    stops: [
                                        Gradient.Stop(color: .purple, location: 0.0),
                                        Gradient.Stop(color: .purple, location: 0.5),
                                        Gradient.Stop(color: .indigo, location: 0.50001),
                                        Gradient.Stop(color: .indigo, location: 1.0),
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                ZStack {
                                    Text(Units(bytes: usage.networkUsage[1].value).getReadableString())
                                        .font(.callout)
                                        .foregroundStyle(Color.indigo.adaptedTextColor(self.environment))
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .foregroundStyle(Color.indigo)
                                }
                            }
                            .annotation(position: .bottom, overflowResolution: .init(x: .fit, y: .fit)) {
                                ZStack {
                                    Text(Units(bytes: abs(usage.networkUsage[0].value)).getReadableString())
                                        .font(.callout)
                                        .foregroundStyle(Color.purple.adaptedTextColor(self.environment))
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .foregroundStyle(Color.purple)
                                }
                            }
                    }
                }
            }
            .chartLegend(.hidden)
            .chartForegroundStyleScale([
                NetworkUsageType.download: Color.indigo,
                NetworkUsageType.upload: Color.purple,
            ])
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
            .chartYScale(domain: getNetworkGraphDomain())
            .chartXSelection(value: $networkSelection)
            .clipShape(self.graphShape)
            .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
            .frame(height: 124)
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)).foregroundStyle(Color.indigo).frame(width: 10, height: 10, alignment: .center)
                Text("Download")
                    .font(.callout)
                Spacer()
                Text(Units(bytes: metrics.networkUsage.download).getReadableString())
                    .font(.callout)
            }
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.purple)
                    .frame(width: 10, height: 10, alignment: .center)
                Text("Upload")
                    .font(.callout)
                Spacer()
                Text(Units(bytes: metrics.networkUsage.upload).getReadableString())
                    .font(.callout)
            }
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                Image(systemName: (sampler?.network.getConnType() ?? .other).getSystemIcon())
                    .frame(width: 8, height: 8, alignment: .center)
                    .padding(.leading, 2)
                Text("Local IP")
                    .font(.callout)
                Spacer()
                Text(sampler?.network.getLocalIP() ?? "--")
                    .font(.callout)
            }
            .padding(.vertical, 2)

            Spacer()
        }
    }
}
