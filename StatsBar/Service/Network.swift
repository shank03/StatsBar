//
//  Network.swift
//  StatsBar
//
//  Created by Shashank on 28/11/24.
//
//  Referenced: https://github.com/exelban/stats
//

import Foundation
import SystemConfiguration
import CoreWLAN
import Network

enum NetworkType: String, Codable {
    case wifi
    case ethernet
    case bluetooth
    case other

    func getSystemIcon() -> String {
        switch self {
        case .wifi:
            return "wifi"
        case .ethernet:
            return "network"
        case .bluetooth:
            return "network"
        case .other:
            return "network"
        }
    }
}

struct NetworkInterface {
    let bsdName: String
    let address: String
    let displayName: String
}

struct WiFi {
    let ssid: String
    let bssid: String
}

struct Bandwidth {
    var totalUpload: UInt64
    var totalDownload: UInt64
    var upload: Int64
    var download: Int64
}

class Network {

    private let infName: String
    private var interface: NetworkInterface?
    private var connType: NetworkType?
    private var wifi: WiFi?
    private var localIP: String = ""
    private var prevBandwidth: Bandwidth?

    init() {
        let defaultInfName = if let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString),
                                let name = global["PrimaryInterface"] as? String
        {
            name
        } else {
            ""
        }
        self.infName = defaultInfName

        let interfaces = SCNetworkInterfaceCopyAll() as NSArray
        let defInf = interfaces.first { inf in
            let interface = inf as! SCNetworkInterface
            let bsd = SCNetworkInterfaceGetBSDName(interface) as? String
            return bsd == defaultInfName
        }
        if defInf == nil {
            return
        }

        let interface = defInf as! SCNetworkInterface

        let bsdName = SCNetworkInterfaceGetBSDName(interface) as? String ?? ""
        let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface) as? String ?? ""
        let address = SCNetworkInterfaceGetHardwareAddressString(interface) as? String ?? ""

        let type = SCNetworkInterfaceGetInterfaceType(interface)
        var nType = NetworkType.other
        switch type {
        case kSCNetworkInterfaceTypeEthernet:
            nType = .ethernet
        case kSCNetworkInterfaceTypeIEEE80211, kSCNetworkInterfaceTypeWWAN:
            nType = .wifi
        case kSCNetworkInterfaceTypeBluetooth:
            nType = .bluetooth
        default:
            nType = .other
        }
        self.connType = nType
        self.interface = NetworkInterface(bsdName: bsdName, address: address, displayName: displayName)
    }

    func readStats() throws -> (Int64, Int64) {
        let current = try self.readInterfaceBandwidth()

        var upload = Int64(0)
        var download = Int64(0)
        if let prevBandwidth = self.prevBandwidth {
            upload = max(0, current.upload - prevBandwidth.upload)
            download = max(0, current.download - prevBandwidth.download)

            self.prevBandwidth?.upload = current.upload
            self.prevBandwidth?.download = current.download
        } else {
            self.prevBandwidth = Bandwidth(totalUpload: 0, totalDownload: 0, upload: current.upload, download: current.download)
        }

        self.readLocalIP()

        return (upload, download)
    }

    func getLocalIP() -> String {
        self.localIP
    }

    func getConnType() -> NetworkType {
        self.connType ?? .other
    }

    private func readInterfaceBandwidth() throws -> (upload: Int64, download: Int64) {
        if self.infName == "" {
            return (0, 0)
        }

        var totalUpload = Int64(0)
        var totalDownload = Int64(0)

        var ifmib = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: size_t = 0

        var ret = sysctl(&ifmib, u_int(ifmib.count), nil, &len, nil, 0)
        if ret != 0 {
            throw ServiceError.unexpectedError(msg: "Failed to get ifmib length - \(ret)")
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        defer { buffer.deallocate() }

        ret = sysctl(&ifmib, u_int(ifmib.count), buffer, &len, nil, 0)
        if ret != 0 {
            throw ServiceError.unexpectedError(msg: "Failed to read ifmib buffer - \(ret)")
        }

        var ptr = buffer
        let end = buffer + len
        while ptr < end {
            let ifm = ptr.withMemoryRebound(to: if_msghdr.self, capacity: 1) { $0.pointee }
            if ifm.ifm_type == RTM_IFINFO2 {
                let if2 = ptr.withMemoryRebound(to: if_msghdr2.self, capacity: 0) { $0.pointee }

                var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                if let _ = if_indextoname(UInt32(if2.ifm_index), &name), String(cString: name) == self.infName {
                    totalUpload += Int64(if2.ifm_data.ifi_obytes)
                    totalDownload += Int64(if2.ifm_data.ifi_ibytes)
                }
            }

            ptr += Int(ifm.ifm_msglen)
        }

        return (totalUpload, totalDownload)
    }

    private func readLocalIP() {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&interfaceAddresses) == 0 else {
            return
        }
        defer { freeifaddrs(interfaceAddresses) }

        for inf in sequence(first: interfaceAddresses, next: { $0?.pointee.ifa_next }) {
            guard let name = inf?.pointee.ifa_name.map({ String(cString: $0) }), name == self.infName else {
                continue
            }

            var addr = inf!.pointee.ifa_addr.pointee
            guard addr.sa_family == UInt8(AF_INET) else {
                continue
            }

            var ip = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(&addr, socklen_t(addr.sa_len), &ip, socklen_t(ip.count), nil, 0, NI_NUMERICHOST)
            self.localIP = String(cString: ip)
        }
    }

    private func getTxRxBytes(inf: UnsafeMutablePointer<ifaddrs>) -> (upload: Int64, download: Int64) {
        let addr = inf.pointee.ifa_addr.pointee

        guard addr.sa_family == UInt8(AF_LINK) else {
            return (0, 0)
        }

        let data: UnsafeMutablePointer<if_data>? = unsafeBitCast(inf.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
        return (upload: Int64(data?.pointee.ifi_obytes ?? 0), download: Int64(data?.pointee.ifi_ibytes ?? 0))
    }
}
