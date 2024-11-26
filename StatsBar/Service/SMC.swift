//
//  SMC.swift
//  StatsBar
//
//  Created by Shashank on 24/11/24.
//

import Foundation

struct KeyDataVer {
    let major: UInt8
    let minor: UInt8
    let build: UInt8
    let reserved: UInt8
    let release: UInt16
}

struct PLimitData {
    let version: UInt16
    let length: UInt16
    let cpuPLimit: UInt32
    let gpuPLimit: UInt32
    let memPLimit: UInt32
}

struct KeyInfo {
    let dataSize: UInt32
    let dataType: UInt32
    let dataAttributes: UInt8
}

struct KeyData {
    let key: UInt32
    let vers: KeyDataVer
    let pLimitData: PLimitData
    let keyInfo: KeyInfo
    let result: UInt8
    let status: UInt8
    let data8: UInt8
    let data32: UInt32
    let bytes = [UInt8](repeating: 0, count: 32)

    init() {
        self.key = 0
        self.vers = KeyDataVer(major: 0, minor: 0, build: 0, reserved: 0, release: 0)
        self.pLimitData = PLimitData(version: 0, length: 0, cpuPLimit: 0, gpuPLimit: 0, memPLimit: 0)
        self.keyInfo = KeyInfo(dataSize: 0, dataType: 0, dataAttributes: 0)
        self.result = 0
        self.status = 0
        self.data8 = 0
        self.data32 = 0
    }

    init(data8: UInt8, key: UInt32) {
        self.key = key
        self.vers = KeyDataVer(major: 0, minor: 0, build: 0, reserved: 0, release: 0)
        self.pLimitData = PLimitData(version: 0, length: 0, cpuPLimit: 0, gpuPLimit: 0, memPLimit: 0)
        self.keyInfo = KeyInfo(dataSize: 0, dataType: 0, dataAttributes: 0)
        self.result = 0
        self.status = 0
        self.data8 = data8
        self.data32 = 0
    }

    init(data8: UInt8, key: UInt32, keyInfo: KeyInfo) {
        self.key = key
        self.vers = KeyDataVer(major: 0, minor: 0, build: 0, reserved: 0, release: 0)
        self.pLimitData = PLimitData(version: 0, length: 0, cpuPLimit: 0, gpuPLimit: 0, memPLimit: 0)
        self.keyInfo = keyInfo
        self.result = 0
        self.status = 0
        self.data8 = data8
        self.data32 = 0
    }
}

class SMC {
    let connection: io_connect_t
    var keys: [UInt32: KeyInfo]

    init() throws {
        let services = try getIOServices(service: "AppleSMC")

        var conn = io_connect_t(0)
        for (name, dev) in services {
            if name == "AppleSMCKeysEndpoint" {
                let rs = IOServiceOpen(dev, mach_task_self_, 0, &conn)
                if rs != 0 {
                    throw ServiceError.unexpectedError(msg: "Failed connect SMC channel")
                }
            }
        }

        self.connection = conn
        self.keys = [:]
    }

    func readPSTR() throws -> [UInt8] {
        let key = "PSTR"
        let keyInfo = try self.readKeyInfo(key: key)
        let kVal = key.reduce(UInt32(0)) { ($0 << 8) + UInt32($1.wholeNumberValue ?? 0) }

        let input = KeyData(data8: 5, key: kVal, keyInfo: keyInfo)
        let output = try self.read(input: input)

        return Array(output.bytes[0...Int(keyInfo.dataSize)])
    }

    private func readKeyInfo(key: String) throws -> KeyInfo {
        if key.count != 4 {
            throw ServiceError.unexpectedError(msg: "SMC Key length must be 4")
        }

        let kVal = key.reduce(UInt32(0)) { ($0 << 8) + UInt32($1.wholeNumberValue ?? 0) }
        if let ki = self.keys[kVal] {
            return ki
        }

        let input = KeyData(data8: 9, key: kVal)
        let output = try self.read(input: input)
        self.keys[kVal] = output.keyInfo
        return output.keyInfo
    }

    private func read(input: KeyData) throws -> KeyData {
        let inputSize = MemoryLayout<KeyData>.size
        var outputSize = MemoryLayout<KeyData>.size
        var inD = input

        var output = KeyData()

        // TODO: Fix ret value -536870206
        let ret = withUnsafePointer(to: &inD) { inputPtr in
            withUnsafeMutablePointer(to: &output) { outputPtr in
                IOConnectCallStructMethod(self.connection, 2, inputPtr, inputSize, outputPtr, &outputSize)
                //                        IOConnectCallStructMethod(self.connection, 2, reboundInputPtr, inputSize, reboundOutputPtr, &outputLength)
            }
        }
        if ret != 0 {
            throw ServiceError.unexpectedError(msg: "SMC: Failed to read IOConnect - \(ret)")
        }

        if output.result == 132 {
            throw ServiceError.unexpectedError(msg: "SMC Key not found")
        }
        if output.result != 0 {
            throw ServiceError.unexpectedError(msg: "SMC error: \(output.result)")
        }

        return output
    }
}
