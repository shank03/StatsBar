//
//  SMC.swift
//  StatsBar
//
//  Created by Shashank on 24/11/24.
//
//  Referenced: https://github.com/exelban/stats
//

import Foundation

struct KeyData {
    typealias SMCBytes_t = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8)

    struct Version {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct PLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = Version()
    var pLimitData = PLimitData()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes_t = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0))
}

extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4)

        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }

    func toString() -> String {
        return String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 8  & 0xff)!) +
               String(describing: UnicodeScalar(self       & 0xff)!)
    }
}

class SMC {
    let connection: io_connect_t
    var keys: [UInt32: KeyData.KeyInfo]

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

    func readPSTR() throws -> Float32 {
        let key = "PSTR"
        let keyInfo = try self.readKeyInfo(key: key)
        let kVal = FourCharCode(fromString: key)

        var input = KeyData()
        input.key = kVal
        input.keyInfo = keyInfo
        input.data8 = 5
        var output = try self.read(input: &input)

        var res = [UInt8](repeating: 0, count: Int(keyInfo.dataSize))
        memcpy(&res, &output.bytes, Int(keyInfo.dataSize))
        return res.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 0, as: Float32.self)
        }
    }

    private func readKeyInfo(key: String) throws -> KeyData.KeyInfo {
        if key.count != 4 {
            throw ServiceError.unexpectedError(msg: "SMC Key length must be 4")
        }

        let kVal = FourCharCode(fromString: key)
        if let ki = self.keys[kVal] {
            return ki
        }

        var input = KeyData()
        input.key = kVal
        input.data8 = 9

        let output = try self.read(input: &input)
        self.keys[kVal] = output.keyInfo
        return output.keyInfo
    }

    private func read(input: inout KeyData) throws -> KeyData {
        let inputSize = MemoryLayout<KeyData>.stride
        var outputSize = MemoryLayout<KeyData>.stride
        var output = KeyData()

        let ret = IOConnectCallStructMethod(self.connection, 2, &input, inputSize, &output, &outputSize)
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

    deinit {
        IOServiceClose(self.connection)
    }
}
