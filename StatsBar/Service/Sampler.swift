//
//  Sampler.swift
//  StatsBar
//
//  Created by Shashank on 24/11/24.
//

import Foundation

private let CPU_FREQ_SUBG = "CPU Core Performance States"
private let GPU_FREQ_SUBG = "GPU Performance States"

struct Sampler {

    let socInfo: SOCInfo
    let ior: IOReport
    let smc: SMC
    let network: Network
    let disk: Disk
    let memory: Memory

    init() throws {
        self.socInfo = try SOCInfo()
        self.ior = try IOReport()
        self.smc = try SMC()
        self.network = Network()
        self.disk = Disk()
        self.memory = Memory()
    }

    func getMetrics() async throws -> Metrics {
        let measures = 4
        try self.disk.updateDiskSpaceStats()

        let sampleData = try await self.ior.getSamples(measures: measures)
        var results = [Metrics]()

        for (samples, dt) in sampleData {
            var eCpuUsages = [(UInt32, Float32)]()
            var pCpuUsages = [(UInt32, Float32)]()
            var eCores = [Float32](repeating: 0, count: self.socInfo.eCores)
            var pCores = [Float32](repeating: 0, count: self.socInfo.pCores)
            var gpuUsage: (UInt32, Float32) = (0, 0)
            var cpuPower = Float32(0)
            var gpuPower = Float32(0)
            var anePower = Float32(0)

            var eCpuCounter = 0
            var pCpuCounter = 0

            for sample in samples {
                if sample.group == "CPU Stats" && sample.subGroup == CPU_FREQ_SUBG {
                    if sample.channel.starts(with: "ECPU") {
                        let info = self.calculateFrequencies(dict: sample.delta, freqs: self.socInfo.eCpuFreqs)
                        eCpuUsages.append(info)

                        eCores[eCpuCounter] = info.usage
                        eCpuCounter += 1
                        continue
                    }

                    if sample.channel.starts(with: "PCPU") {
                        let info = self.calculateFrequencies(dict: sample.delta, freqs: self.socInfo.pCpuFreqs)
                        pCpuUsages.append(info)

                        pCores[pCpuCounter] = info.usage
                        pCpuCounter += 1
                        continue
                    }
                }

                if sample.group == "GPU Stats" && sample.subGroup == GPU_FREQ_SUBG && sample.channel == "GPUPH" {
                    gpuUsage = self.calculateFrequencies(dict: sample.delta, freqs: Array(self.socInfo.gpuFreqs.dropFirst(1)))
                    continue
                }

                if sample.group == "Energy Model" {
                    let watts = self.calculateWatts(dict: sample.delta, unit: sample.unit, duration: UInt64(dt.magnitude))
                    if sample.channel == "CPU Energy" {
                        cpuPower += watts
                    }
                    if sample.channel == "GPU Energy" {
                        gpuPower += watts
                    }
                    if sample.channel.starts(with: "ANE") {
                        anePower += watts
                    }
                }
            }

            let metrics = Metrics(
                eCpuUsage: self.calcuateAggregateFrequencies(items: eCpuUsages, freqs: self.socInfo.eCpuFreqs),
                pCpuUsage: self.calcuateAggregateFrequencies(items: pCpuUsages, freqs: self.socInfo.pCpuFreqs),
                eCores: eCores,
                pCores: pCores,
                gpuUsage: gpuUsage,
                cpuPower: cpuPower,
                gpuPower: gpuPower,
                anePower: anePower,
                sysPower: 0,
                memUsage: (0, 0),
                swapUsage: (0, 0),
                networkUsage: (0, 0),
                diskUsage: [:]
            )
            results.append(metrics)
        }

        var eCores = [Float32](repeating: 0, count: self.socInfo.eCores)
        var pCores = [Float32](repeating: 0, count: self.socInfo.pCores)
        for i in 0..<self.socInfo.eCores {
            eCores[i] = results.reduce(0, { $0 + $1.eCores[i] }) / Float32(measures)
        }
        for i in 0..<self.socInfo.pCores{
            pCores[i] = results.reduce(0, { $0 + $1.pCores[i] }) / Float32(measures)
        }

        let metrics = Metrics(
            eCpuUsage: (
                results.reduce(0, { $0 + $1.eCpuUsage.0 }) / UInt32(measures),
                results.reduce(0, { $0 + $1.eCpuUsage.1 }) / Float32(measures)
            ),
            pCpuUsage: (
                results.reduce(0, { $0 + $1.pCpuUsage.0 }) / UInt32(measures),
                results.reduce(0, { $0 + $1.pCpuUsage.1 }) / Float32(measures)
            ),
            eCores: eCores,
            pCores: pCores,
            gpuUsage: (
                results.reduce(0, { $0 + $1.gpuUsage.0 }) / UInt32(measures),
                results.reduce(0, { $0 + $1.gpuUsage.1 }) / Float32(measures)
            ),
            cpuPower: results.reduce(0, { $0 + $1.cpuPower }),
            gpuPower: results.reduce(0, { $0 + $1.gpuPower }),
            anePower: results.reduce(0, { $0 + $1.anePower }),
            sysPower: try self.smc.readPSTR(),
            memUsage: try self.memory.getMemUsage(),
            swapUsage: try self.memory.getSwap(),
            networkUsage: try self.network.readStats(),
            diskUsage: self.disk.readDriveStats()
        )

        return metrics
    }

    private func calculateFrequencies(dict: CFDictionary, freqs: [UInt32]) -> (freq: UInt32, usage: Float32){
        let items = getResidencies(dict: dict)

        let offset = items.firstIndex { (x, _) in
            return x != "IDLE" && x != "DOWN" && x != "OFF"
        }!

        let usage = items.dropFirst(offset).reduce(0.0) { $0 + Double($1.f) }
        let total = items.reduce(0.0) { $0 + Double($1.f) }
        let count = freqs.count

        var avgFreq = Double(0)
        for i in 0..<count {
            let percent = usage == 0 ? 0 : Double(items[i + offset].f) / usage;
            avgFreq += percent * Double(freqs[i])
        }

        let usageRatio = total == 0 ? 0 : usage / total;
        let minFreq = freqs.first!
        let maxFreq = freqs.last!
        let fromMax = (max(avgFreq, Double(minFreq)) * usageRatio) / Double(maxFreq)

        return (UInt32(avgFreq), Float32(fromMax))
    }

    private func calcuateAggregateFrequencies(items: [(UInt32, Float32)], freqs: [UInt32]) -> (UInt32, Float32) {
        let avgFreq = items.count == 0 ? 0 : (items.reduce(0.0, { $0 + Float32($1.0) }) / Float32(items.count))
        let avgPrec = items.count == 0 ? 0 : (items.reduce(0.0, { $0 + Float32($1.1) }) / Float32(items.count))
        let minFreq = Float32(freqs.first!)

        return (UInt32(max(avgFreq, minFreq)), avgPrec)
    }

    private func calculateWatts(dict: CFDictionary, unit: String, duration: UInt64) -> Float32 {
        let val = IOReportSimpleGetIntegerValue(dict, 0)
        let watts = Float32(val) / (Float32(duration) / 1000.0)
        switch unit {
        case "mJ":
            return watts / 1e3
        case "uJ":
            return watts / 1e6
        case "nJ":
            return watts / 1e9
        default:
            print("Invalid energy unit: \(unit)")
            return 0
        }
    }

    private func getResidencies(dict: CFDictionary) -> [(ns: String, f: Int64)] {
        let count = IOReportStateGetCount(dict);

        var res = [(String, Int64)]()

        for i in 0..<count {
            let name = IOReportStateGetNameForIndex(dict, i)?.takeUnretainedValue() ?? ("" as CFString)
            let val = IOReportStateGetResidency(dict, i)
            res.append((name as String, val))
        }

        return res
    }
}
