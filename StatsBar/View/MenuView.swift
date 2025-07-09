//
//  MenuView.swift
//  StatsBar
//
//  Created by Shashank on 25/11/24.
//

import SwiftUI
import Charts
import Collections
import LaunchAtLogin
import AppKit

extension Color {
    func adaptedTextColor(_ env: EnvironmentValues) -> Color {
        let components = self.resolve(in: env)
        let luminance = 0.2126 * Double(components.red) + 0.7152 * Double(components.green) + 0.0722 * Double(components.blue)

        return luminance > 0.5 ? Color.black : Color.white
    }
}

enum NetworkUsageType: String, Plottable {
    case upload = "upload"
    case download = "download"
}

enum DiskUsageType: String, Plottable {
    case read = "read"
    case write = "write"
}

struct DiskUsagePoint: Identifiable {
    let id: UInt64
    let name: String
    let usage: [(value: Int64, type: DiskUsageType)]

    init(id: UInt64, name: String, usage: (read: Int64, write: Int64)) {
        self.id = id
        self.name = name
        self.usage = [(usage.read, .read), (max(0, usage.write) * -1, .write)]
    }

    static func mockData(sId: UInt64? = nil) -> Deque<DiskUsagePoint> {
        var res: Deque<DiskUsagePoint> = []
        for _ in 0...32 {
            res.append(DiskUsagePoint(id: res.last?.id.advanced(by: 1) ?? sId ?? 1, name: "", usage: (0, 0)))
        }
        return res
    }
}

struct UsagePoint: Identifiable {
    let id: UInt64
    let eCpuUsage: [Double]
    let pCpuUsage: [Double]
    let gpuUsage: [Double]
    let memUsage: [Double]
    let swapUsage: [Double]
    let networkUsage: [(value: Int64, type: NetworkUsageType)]

    init(id: UInt64, eCPUUsage: [Double], pCPUUsage: [Double], gpuUsage: [Double], memUsage: [Double], swapUsage: [Double], networkUsage: (upload: Int64, download: Int64)) {
        self.id = id
        self.eCpuUsage = eCPUUsage
        self.pCpuUsage = pCPUUsage
        self.gpuUsage = gpuUsage
        self.memUsage = memUsage
        self.swapUsage = swapUsage
        self.networkUsage = [(networkUsage.upload * -1, .upload), (networkUsage.download, .download)]
    }

    static func mockData() -> Deque<UsagePoint> {
        var res: Deque<UsagePoint> = []
        for _ in 0...32 {
            res.append(UsagePoint(id: res.last?.id.advanced(by: 1) ?? 1, eCPUUsage: [0, 0], pCPUUsage: [0, 0], gpuUsage: [0, 0], memUsage: [0, 0], swapUsage: [0, 0], networkUsage: (0, 0)))
        }
        return res
    }
}

struct MenuView: View {
    @Environment(\.self) var environment

    @State private var sampler: Sampler?
    @State private var metrics: Metrics?
    @State var updateMenu: (Metrics) -> Void
    @State private var disks: OrderedDictionary<String, Drive> = [:]

    @State private var usageGraph: Deque<UsagePoint> = UsagePoint.mockData()
    @State private var diskUsageGraph: OrderedDictionary<String, Deque<DiskUsagePoint>> = [:]

    @State private var errorMessage: String = ""

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    if self.sampler != nil {
                        self.sampler = nil
                        return
                    }

                    do {
                        self.sampler = try Sampler()
                    } catch {
                        self.errorMessage = "\(error)"
                        self.sampler = nil
                    }

                    DispatchQueue.global(qos: .background).async {
                        Task {
                            do {
                                while let sampler = await self.sampler {
                                    try await updateSamples(sampler)
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    self.errorMessage = "\(error)"
                                    self.sampler = nil
                                }
                            }
                        }
                    }
                }) {
                    Label(
                        self.sampler != nil ? "Stop" : "Start",
                        systemImage: self.sampler != nil ? "stop" : "play"
                    )
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

                Spacer()

                LaunchAtLogin.Toggle("Launch at login")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)

            if !self.errorMessage.isEmpty {
                Text(self.errorMessage)
            }

            if let metrics = self.metrics {
                Divider()
                    .padding(.bottom, 4)
                    .padding(.horizontal, 12)

                // CPU and RAM
                HStack {
                    CPUView(
                        sampler: $sampler,
                        metrics: metrics,
                        usageGraph: $usageGraph
                    )
                    .padding(.horizontal, 12)

                    Divider()
                        .padding(.vertical, 6)

                    MemView(metrics: metrics, usageGraph: $usageGraph)
                        .padding(.horizontal, 12)
                }
                .frame(maxHeight: .infinity)

                Divider()
                    .padding(.vertical, 3)
                    .padding(.horizontal, 12)

                // Power
                PowerView(metrics: metrics)
                    .padding(.horizontal, 12)

                Divider()
                    .padding(.vertical, 3)
                    .padding(.horizontal, 12)

                // Network and Disk
                HStack {
                    NetworkView(
                        sampler: $sampler,
                        metrics: metrics,
                        usageGraph: $usageGraph
                    )
                    .padding(.horizontal, 12)

                    Divider()
                        .padding(.vertical, 6)

                    DiskView(
                        metrics: metrics,
                        disks: $disks,
                        diskUsageGraph: $diskUsageGraph
                    )
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    func updateSamples(_ sampler: Sampler) async throws {
        // interval of 1 sec
        try await Task.sleep(for: .milliseconds(500), tolerance: .zero) // 500 ms
        let metrics = try await sampler.getMetrics()    // 500 ms

        DispatchQueue.main.sync {
            self.disks = sampler.disk.getDisks()
            self.metrics = metrics

            while self.usageGraph.count > 32 {
                let _ = self.usageGraph.popFirst()
            }
            for (key, var usage) in self.diskUsageGraph {
                if self.disks[key] == nil {
                    self.diskUsageGraph.removeValue(forKey: key)
                } else {
                    while usage.count > 32 {
                        let _ = usage.popFirst()
                    }
                    self.diskUsageGraph[key] = usage
                }
            }

            let id = self.usageGraph.last?.id.advanced(by: 1) ?? UInt64(Date().timeIntervalSince1970.magnitude)
            self.usageGraph.append(
                UsagePoint(
                    id: id,
                    eCPUUsage: metrics.getECPUInfo(),
                    pCPUUsage: metrics.getPCPUInfo(),
                    gpuUsage: [metrics.getGPUUsage(), metrics.getGPUFreq()],
                    memUsage: [metrics.getMemUsage(), metrics.getMemUsed()],
                    swapUsage: [metrics.getSwapUsage(), metrics.getSwapUsed()],
                    networkUsage: metrics.networkUsage
                )
            )
            for (key, drive) in self.disks {
                if let usage = metrics.diskUsage[key] {
                    if var q = self.diskUsageGraph[key] {
                        q.append(DiskUsagePoint(id: id, name: drive.mediaName, usage: usage))
                        self.diskUsageGraph[key] = q
                    } else {
                        var points = DiskUsagePoint.mockData(sId: id - 33)
                        points.append(DiskUsagePoint(id: id, name: drive.mediaName, usage: usage))
                        self.diskUsageGraph[key] = points
                    }
                }
            }

            self.updateMenu(metrics)
        }
    }
}
