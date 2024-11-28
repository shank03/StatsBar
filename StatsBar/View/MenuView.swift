//
//  MenuView.swift
//  StatsBar
//
//  Created by Shashank on 25/11/24.
//

import SwiftUI
import Charts
import Collections

struct UsagePoint: Identifiable {
    let id: UInt64
    let eCpuUsage: Double
    let pCpuUsage: Double
    let gpuUsage: Double
    let memUsage: Double
    let swapUsage: Double

    init(id: UInt64, eCPUUsage: Double, pCPUUsage: Double, gpuUsage: Double, memUsage: Double, swapUsage: Double) {
        self.id = id
        self.eCpuUsage = eCPUUsage
        self.pCpuUsage = pCPUUsage
        self.gpuUsage = gpuUsage
        self.memUsage = memUsage
        self.swapUsage = swapUsage
    }

    static func mockData() -> Deque<UsagePoint> {
        var res: Deque<UsagePoint> = []
        for _ in 0...32 {
            res.append(UsagePoint(id: res.last?.id.advanced(by: 1) ?? 1, eCPUUsage: 0, pCPUUsage: 0, gpuUsage: 0, memUsage: 0, swapUsage: 0))
        }
        return res
    }
}

struct MenuView: View {

    @State private var isRunning: Bool = false
    @State private var sampler: Sampler?
    @State private var metrics: Metrics?
    @State var updateMenu: (Metrics) -> Void

    @State private var usageGraph: Deque<UsagePoint> = UsagePoint.mockData()
    @State private var graphShape = RoundedRectangle(cornerRadius: 12)

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    if isRunning {
                        isRunning = false
                        return
                    }

                    isRunning = true
                    DispatchQueue.global(qos: .background).async {
                        Task {
                            do {
                                let sampler = try Sampler()
                                DispatchQueue.main.async {
                                    self.sampler = sampler
                                }

                                while await isRunning {
                                    try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
                                    let metrics = try await sampler.getMetrics(duration: 500)
                                    DispatchQueue.main.async {
                                        self.metrics = metrics

                                        self.usageGraph.append(
                                            UsagePoint(
                                                id: self.usageGraph.last?.id.advanced(by: 1) ?? UInt64(Date().timeIntervalSince1970.magnitude),
                                                eCPUUsage: metrics.getECPUInfo()[0],
                                                pCPUUsage: metrics.getPCPUInfo()[0],
                                                gpuUsage: metrics.getGPUUsage(),
                                                memUsage: metrics.getMemUsage(),
                                                swapUsage: metrics.getSwapUsage()
                                            )
                                        )
                                        while self.usageGraph.count > 32 {
                                            let _ = self.usageGraph.popFirst()
                                        }

                                        self.updateMenu(metrics)
                                    }
                                }
                            } catch {
                                print(error)
                            }
                        }
                    }
                }) {
                    Label(self.isRunning ? "Stop" : "Start", systemImage: self.isRunning ? "stop" : "play")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 8, height: 8)))

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit App", systemImage: "power")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 8, height: 8)))
            }
            .padding(.horizontal, 8)

            if let metrics = self.metrics {
                Divider()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)

                VStack(spacing: 8) {
                    Text("\(self.sampler?.socInfo.chipName ?? "") (\(self.sampler?.socInfo.eCores ?? 0)E + \(self.sampler?.socInfo.pCores ?? 0)P + \(self.sampler?.socInfo.gpuCores ?? 0)GPU)")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 4) {

                        VStack(spacing: 4) {
                            Chart(self.usageGraph) {
                                AreaMark(
                                    x: .value("X", $0.id),
                                    y: .value("Y", $0.eCpuUsage)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.accentColor)
                                .mask { RectangleMark() }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                            .chartYScale(domain: [0, 100])
                            .clipShape(self.graphShape)
                            .overlay(self.graphShape.stroke(.gray, lineWidth: 1))

                            Spacer()

                            Chart(self.usageGraph) {
                                AreaMark(
                                    x: .value("X", $0.id),
                                    y: .value("Y", $0.pCpuUsage)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.green)
                                .mask { RectangleMark() }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                            .chartYScale(domain: [0, 100])
                            .clipShape(self.graphShape)
                            .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
                        }

                        Spacer()

                        Chart(self.usageGraph) {
                            AreaMark(
                                x: .value("X", $0.id),
                                y: .value("Y", $0.gpuUsage)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.orange)
                            .mask { RectangleMark() }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                        .chartYScale(domain: [0, 100])
                        .clipShape(self.graphShape)
                        .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
                    }
                    .frame(height: 116)
                    .padding(.vertical, 2)

                    HStack(alignment: .center) {
                        RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 10, height: 10, alignment: .center)
                        Text("E-CPU")
                        Spacer()
                        Text(String(format: "%.2f%%", arguments: [metrics.getECPUInfo()[0]]))
                        Text(String(format: "%.2f GHz", arguments: [metrics.getECPUInfo()[1]]))
                    }
                    .padding(.vertical, 2)

                    HStack(alignment: .center) {
                        RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                            .foregroundStyle(Color.green)
                            .frame(width: 10, height: 10, alignment: .center)
                        Text("P-CPU")
                        Spacer()
                        Text(String(format: "%.2f%%", arguments: [metrics.getPCPUInfo()[0]]))
                        Text(String(format: "%.2f GHz", arguments: [metrics.getPCPUInfo()[1]]))
                    }
                    .padding(.vertical, 2)

                    HStack(alignment: .center) {
                        RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                            .foregroundStyle(Color.orange)
                            .frame(width: 10, height: 10, alignment: .center)
                        Text("GPU")
                        Spacer()
                        Text(String(format: "%.2f%%", arguments: [metrics.getGPUUsage()]))
                        Text(String(format: "%.2f GHz", arguments: [metrics.getGPUFreq()]))
                    }
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, 8)

                Divider()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)

                VStack(spacing: 8) {
                    Text("Memory")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 4) {
                        Chart(self.usageGraph) {
                            AreaMark(
                                x: .value("X", $0.id),
                                y: .value("Y", $0.memUsage)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.red)
                            .mask { RectangleMark() }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                        .chartYScale(domain: [0, 100])
                        .clipShape(self.graphShape)
                        .overlay(self.graphShape.stroke(.gray, lineWidth: 1))

                        Spacer()

                        Chart(self.usageGraph) {
                            AreaMark(
                                x: .value("X", $0.id),
                                y: .value("Y", $0.swapUsage)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.yellow)
                            .mask { RectangleMark() }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                        .chartYScale(domain: [0, 100])
                        .clipShape(self.graphShape)
                        .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
                    }
                    .frame(height: 96)
                    .padding(.vertical, 2)

                    HStack(alignment: .center) {
                        RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)).foregroundStyle(Color.red).frame(width: 10, height: 10, alignment: .center)
                        Text("MEM")
                        Spacer()
                        Text(String(format: "%.2f%%", arguments: [metrics.getMemUsage()]))
                        Text(String(format: "%.2f / %d GB", arguments: [metrics.getMemUsed(), metrics.getTotalMemory()]))
                    }
                    .padding(.vertical, 2)

                    HStack(alignment: .center) {
                        RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                            .foregroundStyle(Color.yellow)
                            .frame(width: 10, height: 10, alignment: .center)
                        Text("Swap")
                        Spacer()
                        Text(String(format: "%.2f%%", arguments: [metrics.getSwapUsage()]))
                        Text(String(format: "%.2f / %d GB", arguments: [metrics.getSwapUsed(), metrics.getTotalSwap()]))
                    }
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, 8)

                Divider()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)

                VStack(spacing: 8) {
                    HStack {
                        Text("Power")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()
                        Text(String(format: "%.2f W", arguments: [metrics.sysPower]))
                    }

                    HStack {
                        Text("CPU")
                        Spacer()
                        Text(String(format: "%.2f W", arguments: [metrics.cpuPower / 1000.0]))
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Text("GPU")
                        Spacer()
                        Text(String(format: "%.2f W", arguments: [metrics.gpuPower / 1000.0]))
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Text("ANE")
                        Spacer()
                        Text(String(format: "%.2f W", arguments: [metrics.anePower / 1000.0]))
                    }
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(4)
    }
}

//#Preview {
//    MenuView()
//}
