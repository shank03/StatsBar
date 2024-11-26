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
    let id: UInt64 = UInt64(Date().timeIntervalSince1970.magnitude)
    let eCPUUsage: Double
    let pCPUUsage: Double
    let gpuUsage: Double
    let memUsage: Double
    let swapUsage: Double
}

struct MenuView: View {

    @State private var isRunning: Bool = false
    @State private var sampler: Sampler?
    @State private var metrics: Metrics?
    @State var delegate: AppDelegate

    @State private var usageGraph: Deque<UsagePoint> = []

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

                                        self.usageGraph.append(UsagePoint(eCPUUsage: metrics.getECPUInfo()[0], pCPUUsage: metrics.getPCPUInfo()[0], gpuUsage: metrics.getGPUUsage(), memUsage: metrics.getMemUsage(), swapUsage: metrics.getSwapUsage()))
                                        while self.usageGraph.count > 32 {
                                            let _ = self.usageGraph.popFirst()
                                        }

                                        if let menuButton = self.delegate.statusItem?.button {
                                            let iconView = NSHostingView(rootView: PopupText(metrics: self.metrics))
                                            iconView.frame = NSRect(x: 0, y: 0, width: 132, height: 22)

                                            menuButton.subviews[0] = iconView
                                            menuButton.frame = iconView.frame
                                        }
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
                    Label("Quit App", systemImage: "power.circle.fill")
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

                    Chart(self.usageGraph) {
                        AreaMark(
                            x: .value("X", $0.id),
                            y: .value("Y", $0.gpuUsage),
                            series: .value("", "Ga")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Gradient(colors: [Color.orange, Color.orange.opacity(0.1)]))

                        AreaMark(
                            x: .value("X", $0.id),
                            y: .value("Y", $0.pCPUUsage),
                            series: .value("", "Pa")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Gradient(colors: [Color.green, Color.green.opacity(0.1)]))

                        AreaMark(
                            x: .value("X", $0.id),
                            y: .value("Y", $0.eCPUUsage),
                            series: .value("", "Ea")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.1)]))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                    .frame(height: 96)
                    .padding(.vertical, 2)

                    HStack {
                        Text("E-Cores")
                        RoundedRectangle(cornerSize: CGSize(width: 12, height: 12)).foregroundStyle(Color.accentColor).frame(width: 12, height: 12)
                        Spacer()
                        Text(String(format: "%.2f%%", arguments: [metrics.getECPUInfo()[0]]))
                        Text(String(format: "%.2f GHz", arguments: [metrics.getECPUInfo()[1]]))
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Text("P-Cores")
                        RoundedRectangle(cornerSize: CGSize(width: 12, height: 12)).foregroundStyle(Color.green).frame(width: 12, height: 12)
                        Spacer()
                        Text(String(format: "%.2f%%", arguments: [metrics.getPCPUInfo()[0]]))
                        Text(String(format: "%.2f GHz", arguments: [metrics.getPCPUInfo()[1]]))
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Text("GPU")
                        RoundedRectangle(cornerSize: CGSize(width: 12, height: 12)).foregroundStyle(Color.orange).frame(width: 12, height: 12)
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

                    Chart(self.usageGraph) {
                        AreaMark(
                            x: .value("X", $0.id),
                            y: .value("Y", $0.memUsage),
                            series: .value("", "M")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Gradient(colors: [Color.red, Color.red.opacity(0.1)]))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartXScale(domain: [self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0])
                    .chartYScale(domain: [0, 100])
                    .frame(height: 96)
                    .padding(.vertical, 2)

                    HStack {
                        Text("MEM")
                        RoundedRectangle(cornerSize: CGSize(width: 12, height: 12)).foregroundStyle(Color.red).frame(width: 12, height: 12)
                        Spacer()
                        Text(String(format: "%.2f%%", arguments: [metrics.getMemUsage()]))
                        Text(String(format: "%.2f / %d GB", arguments: [metrics.getMemUsed(), metrics.getTotalMemory()]))
                    }
                    .padding(.vertical, 2)

                    HStack {
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
                        Text(String(format: "%.2f W", arguments: [metrics.allPower / 1000.0]))
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
