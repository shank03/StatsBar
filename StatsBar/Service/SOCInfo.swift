//
//  SOCInfo.swift
//  StatsBar
//
//  Created by Shashank on 14/11/24.
//

import Foundation
import CoreFoundation
import IOKit

struct SOCInfo {
    let eCpuFreqs: [UInt32]
    let pCpuFreqs: [UInt32]
    let gpuFreqs: [UInt32]

    let chipName: String
    let macModel: String
    let memorySize: Int     // GB
    let eCores: Int
    let pCores: Int
    let gpuCores: Int

    init() throws {
        let m3Below = try Regex("[m|M][1-3]")
        let services = try getIOServices(service: SERVICE_NAME)

        guard let pmgr = services.first(where: { (name, _) in
            name == "pmgr"
        }) else {
            print("Power metrics entry not found")
            throw ServiceError.powerManagerRegistryNotFound
        }

        var props: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(pmgr.next, &props, kCFAllocatorDefault, 0) != 0 {
            print("Error: failed to get properties")
        }

        guard let props = props?.takeUnretainedValue() as? [String: Any] else {
            print("Props is empty")
            throw ServiceError.dictionaryNull(for: "Power manager")
        }

        let sysInfo = try runSystemProfiler()

        self.chipName = sysInfo.spHardwareDataType[0].chip_type
        self.macModel = sysInfo.spHardwareDataType[0].machine_model
        self.memorySize = Int(sysInfo.spHardwareDataType[0].physical_memory.split(separator: " GB")[0]) ?? 0

        let proc = sysInfo.spHardwareDataType[0].number_processors.split(separator: "proc ").last ?? ""
        let cores = proc.split(separator: ":").map { Int($0) ?? 0 }
        self.eCores = cores[2]
        self.pCores = cores[1]
        self.gpuCores = Int(sysInfo.spDisplaysDataType[0].sppci_cores) ?? 0

        let eCpuKey = "voltage-states1-sram"
        let pCpuKey = "voltage-states5-sram"
        let gpuKey = "voltage-states9-sram"

        let isM3Below = chipName.contains(m3Below)
        let eCpuFreq = try getFreq(dict: props, key: eCpuKey, isM3Below: isM3Below)
        let pCpuFreq = try getFreq(dict: props, key: pCpuKey, isM3Below: isM3Below)
        let gpuFreq = try getFreq(dict: props, key: gpuKey, isM3Below: true)

        if eCpuFreq.isEmpty || pCpuFreq.isEmpty {
            throw ServiceError.noCpuCores
        }

        self.eCpuFreqs = eCpuFreq
        self.pCpuFreqs = pCpuFreq
        self.gpuFreqs = gpuFreq
    }
}

private func getFreq(dict: [String: Any], key: String, isM3Below: Bool) throws -> [UInt32] {
    guard let value = dict[key] else {
        throw ServiceError.dictionaryNull(for: key)
    }

    let data = value as! CFData

    let length = CFDataGetLength(data)
    var bytes = [UInt8](repeating: 0, count: length)
    CFDataGetBytes(data, CFRange(location: 0, length: length), &bytes)


    let scale: UInt32 = isM3Below ? 1000 * 1000 : 1000
    var freqs: [UInt32] = []
    //        var volts: [UInt32] = []

    var chunks = stride(from: 0, to: bytes.count, by: 8).map { Array(bytes[$0..<min($0 + 8, bytes.count)])}
    for chunk in chunks {
        //            volts.append(UInt32(chunk[4]) | UInt32(chunk[5]) << 8 | UInt32(chunk[6]) << 16 | UInt32(chunk[7]) << 24)

        let f = UInt32(chunk[0]) | UInt32(chunk[1]) << 8 | UInt32(chunk[2]) << 16 | UInt32(chunk[3]) << 24
        freqs.append(f / scale)   // MHz
    }

    bytes.removeAll()
    chunks.removeAll()

    //        print("key: \(key): V: \(length) - \(freqs) - \(volts)")
    return freqs
}

private let SERVICE_NAME = "AppleARMIODevice"

struct SPDisplaysDataType: Decodable {
    let name: String
    let spdisplays_mtlgpufamilysupport: String
    let spdisplays_vendor: String
    let sppci_bus: String
    let sppci_cores: String
    let sppci_device_type: String
    let sppci_model: String

    enum CodingKeys: String, CodingKey {
        case name = "_name"
        case spdisplays_mtlgpufamilysupport, spdisplays_vendor, sppci_bus, sppci_cores, sppci_device_type, sppci_model
    }
}

struct SPHardwareDataType: Decodable {
    let _name: String
    let chip_type: String
    let machine_model: String
    let machine_name: String
    let model_number: String
    let number_processors: String
    let os_loader_version: String
    let physical_memory: String
    let platform_UUID: String
    let provisioning_UDID: String
    let serial_number: String
}

struct ProfilerResponse: Decodable {
    let spDisplaysDataType: [SPDisplaysDataType]
    let spHardwareDataType: [SPHardwareDataType]

    enum CodingKeys: String, CodingKey {
        case spDisplaysDataType = "SPDisplaysDataType"
        case spHardwareDataType = "SPHardwareDataType"
    }
}

func runSystemProfiler() throws -> ProfilerResponse {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.standardInput = nil
    task.arguments = ["-c", "system_profiler SPHardwareDataType SPDisplaysDataType -json"]
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")

    try task.run()

    guard let data = try pipe.fileHandleForReading.readToEnd() else {
        throw ServiceError.failedToReadPipe
    }

    do {
        let json = try JSONDecoder().decode(ProfilerResponse.self, from: data)
        return json
    } catch {
        throw ServiceError.failedDeserialization
    }
}
