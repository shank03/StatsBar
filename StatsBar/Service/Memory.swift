//
//  Memory.swift
//  StatsBar
//
//  Created by Shashank on 11/04/25.
//

class Memory {

    func getSwap() throws -> (UInt64, UInt64) {
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

    func getMemUsage() throws -> (UInt64, UInt64){
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
        let usage = (UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * pageSize

        return (usage, total)
    }
}
