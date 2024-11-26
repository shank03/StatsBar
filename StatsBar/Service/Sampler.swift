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
    private let ior: IOReport
    private let smc: SMC

    init() throws {
        self.socInfo = try SOCInfo()
        self.ior = try IOReport()
        self.smc = try SMC()
    }

    func getMetrics(duration: Int) async throws -> Metrics {
        let measures = 4

        let sampleData = try await self.ior.getSamples(duration: duration, count: measures)

        var results = [Metrics]()
        for (samples, dt) in sampleData {

            var eCpuUsages = [(UInt32, Float32)]()
            var pCpuUsages = [(UInt32, Float32)]()
            var gpuUsage: (UInt32, Float32) = (0, 0)
            var cpuPower = Float32(0)
            var gpuPower = Float32(0)
            var anePower = Float32(0)

            for sample in samples {
                if sample.group == "CPU Stats" && sample.subGroup == CPU_FREQ_SUBG {
                    if sample.channel.contains("ECPU") {
                        eCpuUsages.append(self.calculateFrequencies(dict: sample.delta, freqs: self.socInfo.eCpuFreqs))
                        continue
                    }

                    if sample.channel.contains("PCPU") {
                        pCpuUsages.append(self.calculateFrequencies(dict: sample.delta, freqs: self.socInfo.pCpuFreqs))
                        continue
                    }
                }

                if sample.group == "GPU Stats" && sample.subGroup == GPU_FREQ_SUBG {
                    if sample.channel == "GPUPH" {
                        gpuUsage = self.calculateFrequencies(dict: sample.delta, freqs: Array(self.socInfo.gpuFreqs.dropFirst(1)))
                    }
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
                gpuUsage: gpuUsage,
                cpuPower: cpuPower,
                gpuPower: gpuPower,
                anePower: anePower,
                sysPower: 0,
                memUsage: (0, 0),
                swapUsage: (0, 0)
            )
            results.append(metrics)
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
            gpuUsage: (
                results.reduce(0, { $0 + $1.gpuUsage.0 }) / UInt32(measures),
                results.reduce(0, { $0 + $1.gpuUsage.1 }) / Float32(measures)
            ),
            cpuPower: results.reduce(0, { $0 + $1.cpuPower }),
            gpuPower: results.reduce(0, { $0 + $1.gpuPower }),
            anePower: results.reduce(0, { $0 + $1.anePower }),
            sysPower: 0,
            memUsage: try self.getMemUsage(),
            swapUsage: try self.getSwap()
        )

        return metrics
    }

    private func calculateFrequencies(dict: CFDictionary, freqs: [UInt32]) -> (freq: UInt32, fromMax: Float32){
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

    private func getMemUsage() throws -> (usage: UInt64, total: UInt64) {
        var name = [CTL_HW, HW_MEMSIZE]
        let size = u_int(name.count)
        var oLen = MemoryLayout<UInt64>.size

        var total = UInt64(0)

        let res = sysctl(&name, size, &total, &oLen, nil, 0)
        if res != 0 {
            throw ServiceError.unexpectedError(msg: "Failed to get total mem")
        }

        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64()

        let ret = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &count)
            }
        }
        if ret != 0 {
            throw ServiceError.unexpectedError(msg: "Failed to get mem usage")
        }

        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        let usage = (UInt64(stats.active_count)
                     + UInt64(stats.inactive_count)
                     + UInt64(stats.wire_count)
                     + UInt64(stats.speculative_count)
                     + UInt64(stats.compressor_page_count)
                     - UInt64(stats.purgeable_count)
                     - UInt64(stats.external_page_count)) * pageSize

        return (usage, total)
    }

    private func getSwap() throws -> (UInt64, UInt64) {
        var name = [CTL_VM, VM_SWAPUSAGE]
        let len = u_int(name.count)
        var size = MemoryLayout<xsw_usage>.size
        var xsw = xsw_usage()

        let ret = withUnsafeMutablePointer(to: &xsw) { xswPtr in
            xswPtr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { pointer in
                sysctl(&name, len, pointer, &size, nil, 0)
            }
        }

        if ret != 0 {
            throw ServiceError.unexpectedError(msg: "Failed to get swap")
        }

        return (xsw.xsu_used, xsw.xsu_total)
    }

    private func getSysPower() throws -> Float32 {
        let pstr = try self.smc.readPSTR()
        let val32 = UInt32(pstr[0]) | UInt32(pstr[1]) << 8 | UInt32(pstr[2]) << 16 | UInt32(pstr[3]) << 24
        return Float32(val32)
    }
}
