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
        self.usage = [(usage.read, .read), (usage.write > 0 ? 0 : usage.write * -1, .write)]
    }

    static func mockData() -> Deque<DiskUsagePoint> {
        var res: Deque<DiskUsagePoint> = []
        for _ in 0...32 {
            res.append(DiskUsagePoint(id: res.last?.id.advanced(by: 1) ?? 1, name: "", usage: (0, 0)))
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

    @State private var isRunning: Bool = false
    @State private var sampler: Sampler?
    @State private var metrics: Metrics?
    @State var updateMenu: (Metrics) -> Void
    @State private var disks: OrderedDictionary<String, Drive> = [:]

    @State private var usageGraph: Deque<UsagePoint> = UsagePoint.mockData()
    @State private var diskUsageGraph: OrderedDictionary<String, Deque<DiskUsagePoint>> = [:]
    @State private var graphShape = RoundedRectangle(cornerRadius: 12)
    @State private var gpuSelection: UInt64?
    @State private var eCpuSelection: UInt64?
    @State private var pCpuSelection: UInt64?
    @State private var phyMemSelection: UInt64?
    @State private var swapMemSelection: UInt64?
    @State private var networkSelection: UInt64?
    @State private var diskSelection: [String: UInt64?] = [:]

    private func getNetworkGraphDomain() -> [Int64] {
        let maxUsage = self.usageGraph.reduce(Int64(0)) { max($0, max(abs($1.networkUsage[0].value), abs($1.networkUsage[1].value))) }
        return [maxUsage * -1, maxUsage]
    }
    private func getDiskGraphDomain(disk: String) -> [Int64] {
        let maxUsage = (self.diskUsageGraph[disk] ?? []).reduce(Int64(0)) { max($0, max(abs($1.usage[0].value), abs($1.usage[1].value))) }
        return [maxUsage * -1, maxUsage]
    }

    private func binding(disk: String) -> Binding<UInt64?> {
        return .init(get: { self.diskSelection[disk, default: nil] }, set: { self.diskSelection[disk] = $0 })
    }

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
                                    // interval of 1 sec
                                    try await Task.sleep(for: .milliseconds(500), tolerance: .zero) // 500 ms
                                    let metrics = try await sampler.getMetrics()    // 500 ms

                                    DispatchQueue.main.async {
                                        self.metrics = metrics
                                        self.disks = sampler.disk.getDisks()

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
                                                    var points = DiskUsagePoint.mockData()
                                                    points.append(DiskUsagePoint(id: id, name: drive.mediaName, usage: usage))
                                                    self.diskUsageGraph[key] = points
                                                }
                                            }
                                        }

                                        self.updateMenu(metrics)
                                    }
                                }
                            } catch {
                                print(error)
                            }

                            DispatchQueue.main.async {
                                self.sampler = nil
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

                Spacer()

                LaunchAtLogin.Toggle("Launch at login")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)

            if let metrics = self.metrics {
                Divider()
                    .padding(.bottom, 4)
                    .padding(.horizontal, 12)

                HStack {
                    // CPU
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
                    .padding(.horizontal, 12)

                    Divider()
                        .padding(.vertical, 6)

                    // RAM
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
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: .infinity)

                Divider()
                    .padding(.vertical, 3)
                    .padding(.horizontal, 12)

                // Power
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
                .padding(.horizontal, 12)

                Divider()
                    .padding(.vertical, 3)
                    .padding(.horizontal, 12)

                HStack {
                    // Network
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
                    .padding(.horizontal, 12)

                    Divider()
                        .padding(.vertical, 6)

                    // Disk
                    ScrollView {
                        ForEach(Array(self.diskUsageGraph.elements.enumerated()), id: \.offset) { index, element in
                            VStack(spacing: 8) {
                                HStack(alignment: .center) {
                                    Text("Disk: \(self.disks[element.key]?.mediaName ?? "")")
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Spacer()

                                    Text("\(element.key) (\(self.disks[element.key]?.fileSystem.uppercased() ?? ""))")
                                        .font(.system(size: 12))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }

                                Chart {
                                    ForEach(element.value, id: \.id) { usageInfo in
                                        ForEach(usageInfo.usage, id: \.type) { diskUsage in
                                            AreaMark(
                                                x: .value("X", usageInfo.id),
                                                y: .value("Y", diskUsage.value)
                                            )
                                            .interpolationMethod(.catmullRom)
                                            .foregroundStyle(by: .value("OP Bytes type", diskUsage.type))
                                        }
                                    }

                                    if let selection = self.diskSelection[element.key], let selection {
                                        if let usage = (self.diskUsageGraph[element.key]?.first { $0.id == selection }) {
                                            RuleMark(x: .value("X", selection), yStart: 0)
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        stops: [
                                                            Gradient.Stop(color: .mint, location: 0.0),
                                                            Gradient.Stop(color: .mint, location: 0.5),
                                                            Gradient.Stop(color: .blue, location: 0.50001),
                                                            Gradient.Stop(color: .blue, location: 1.0),
                                                        ],
                                                        startPoint: .bottom,
                                                        endPoint: .top
                                                    )
                                                )
                                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                                    ZStack {
                                                        Text(Units(bytes: usage.usage[0].value).getReadableString())
                                                            .font(.callout)
                                                    }
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 6)
                                                    .background {
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .foregroundStyle(Color.blue)
                                                    }
                                                }
                                                .annotation(position: .bottom, overflowResolution: .init(x: .fit, y: .fit)) {
                                                    ZStack {
                                                        Text(Units(bytes: abs(usage.usage[1].value)).getReadableString())
                                                            .font(.callout)
                                                    }
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 6)
                                                    .background {
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .foregroundStyle(Color.mint)
                                                    }
                                                }
                                        }
                                    }
                                }
                                .chartLegend(.hidden)
                                .chartForegroundStyleScale([
                                    DiskUsageType.read: Color.blue,
                                    DiskUsageType.write: Color.mint,
                                ])
                                .chartXAxis(.hidden)
                                .chartYAxis(.hidden)
                                .chartXScale(domain: [self.diskUsageGraph[element.key]?.first?.id ?? 0, self.diskUsageGraph[element.key]?.last?.id ?? 0])
                                .chartYScale(domain: getDiskGraphDomain(disk: element.key))
                                .chartXSelection(value: self.binding(disk: element.key))
                                .clipShape(self.graphShape)
                                .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
                                .frame(height: max(62, 124 / CGFloat(self.disks.count)))
                                .padding(.vertical, 2)

                                HStack(alignment: .center) {
                                    HStack(alignment: .center) {
                                        RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)).foregroundStyle(Color.blue).frame(width: 10, height: 10, alignment: .center)
                                        Text("Read")
                                            .font(.callout)
                                        Spacer()
                                        Text(Units(bytes: metrics.getDiskRead(key: element.key)).getReadableString())
                                            .font(.callout)
                                    }

                                    Divider()
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 6)

                                    HStack(alignment: .center) {
                                        RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                                            .foregroundStyle(Color.mint)
                                            .frame(width: 10, height: 10, alignment: .center)
                                        Text("Write")
                                            .font(.callout)
                                        Spacer()
                                        Text(Units(bytes: metrics.getDiskWrite(key: element.key)).getReadableString())
                                            .font(.callout)
                                    }
                                }
                                .padding(.vertical, 2)

                                if let disk = self.disks[element.key] {
                                    HStack(alignment: .center) {
                                        Text("Available")
                                            .font(.callout)
                                        Spacer()
                                        Text("\(DiskSize(size: self.disks[element.key]?.free ?? 0).getReadableMemory()) / \(DiskSize(size: self.disks[element.key]?.size ?? 0).getReadableMemory())")
                                            .font(.callout)
                                    }
                                    .padding(.vertical, 2)

                                    if !disk.root {
                                        HStack(alignment: .center) {
                                            Text("Connection")
                                                .font(.callout)
                                            Spacer()
                                            Text(self.disks[element.key]?.connectionType.uppercased() ?? "--")
                                                .font(.callout)
                                        }
                                        .padding(.vertical, 2)

                                        HStack(alignment: .center) {
                                            Text("Model")
                                                .font(.callout)
                                            Spacer()
                                            Text(self.disks[element.key]?.model.uppercased() ?? "--")
                                                .font(.callout)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)

                            if index != (self.disks.count - 1) {
                                Divider().padding(6)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

//#Preview {
//    MenuView()
//}
