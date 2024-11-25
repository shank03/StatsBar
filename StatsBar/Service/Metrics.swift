//
//  Metrics.swift
//  StatsBar
//
//  Created by Shashank on 14/11/24.
//

import Foundation
import CoreFoundation
import IOKit

struct Metrics {
    let eCpuUsage: (UInt32, Float32)
    let pCpuUsage: (UInt32, Float32)
    let gpuUsage: (UInt32, Float32)
    let cpuPower: Float32
    let gpuPower: Float32
    let anePower: Float32
    let allPower: Float32
    let sysPower: Float32
    let memUsage: (UInt64, UInt64)
    let swapUsage: (UInt64, UInt64)

    init(eCpuUsage: (UInt32, Float32), pCpuUsage: (UInt32, Float32), gpuUsage: (UInt32, Float32), cpuPower: Float32, gpuPower: Float32, anePower: Float32, sysPower: Float32, memUsage: (UInt64, UInt64), swapUsage: (UInt64, UInt64)) {
        self.eCpuUsage = eCpuUsage
        self.pCpuUsage = pCpuUsage
        self.gpuUsage = gpuUsage
        self.cpuPower = cpuPower
        self.gpuPower = gpuPower
        self.anePower = anePower
        self.allPower = self.cpuPower + self.gpuPower + self.anePower
        self.sysPower = sysPower
        self.memUsage = memUsage
        self.swapUsage = swapUsage
    }

    func getCPUFreqs() -> [Double] {
        return [Double(self.eCpuUsage.0) / 1000.0, Double(self.pCpuUsage.0) / 1000.0]
    }

    func getCPUUsage() -> Double {
        let eCpu = self.eCpuUsage.1 * 100
        let pCpu = self.pCpuUsage.1 * 100

        return (Double(eCpu + pCpu) * 100.0) / 200.0
    }

    func getECPUInfo() -> [Double] {
        return [Double(self.eCpuUsage.1 * 100), Double(self.eCpuUsage.0) / 1000.0]
    }

    func getPCPUInfo() -> [Double] {
        return [Double(self.pCpuUsage.1 * 100), Double(self.pCpuUsage.0) / 1000.0]
    }

    func getGPUFreq() -> Double {
        return Double(self.gpuUsage.0) / 1000.0
    }

    func getGPUUsage() -> Double {
        return Double(self.gpuUsage.1) * 100
    }

    func getMemUsed() -> Double {
        return Double(self.memUsage.0) / 1024.0 / 1024.0 / 1024.0
    }

    func getMemUsage() -> Double {
        return Double(self.getMemUsed() * 100) / Double(self.getTotalMemory())
    }

    func getTotalMemory() -> UInt64 {
        return self.memUsage.1 / 1024 / 1024 / 1024
    }

    func getSwapUsage() -> Double {
        return (self.getSwapUsed() * 100) / Double(self.getTotalSwap())
    }

    func getSwapUsed() -> Double {
        return Double(self.swapUsage.0) / 1024.0 / 1024.0 / 1024.0
    }

    func getTotalSwap() -> UInt64 {
        return self.swapUsage.1 / 1024 / 1024 / 1024
    }
}
