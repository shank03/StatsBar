//
//  Disk.swift
//  StatsBar
//
//  Created by Shashank on 03/12/24.
//
//  Referenced: https://github.com/exelban/stats
//

import Foundation
import OrderedCollections

public struct Drive {
    var parent: io_object_t = 0

    var uuid: String = ""
    var mediaName: String = ""
    var BSDName: String = ""

    var root: Bool = false

    var model: String = ""
    var path: URL?
    var connectionType: String = ""
    var fileSystem: String = ""

    var size: Int64 = 1
    var free: Int64 = 0

    var activity: (read: Int64, write: Int64) = (0, 0)
}

class Disk {

    private var diskMap: OrderedDictionary<String, Drive> = [:]

    func updateDiskSpaceStats() throws {
        let fileManager = FileManager.default
        let paths = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey], options: [.skipHiddenVolumes])!

        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            throw ServiceError.unexpectedError(msg: "Failed to create DASession")
        }

        var disks: [String: Bool] = [:]
        for url in paths {
            if url.pathComponents.count != 1 && !(url.pathComponents.count > 1 && url.pathComponents[1] == "Volumes") {
                continue
            }

            if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) {
                if let diskName = DADiskGetBSDName(disk) {
                    let bsdName = String(cString: diskName)
                    disks[bsdName] = true

                    if var d = self.diskMap[bsdName] {
                        if let path = d.path {
                            d.free = try self.getFreeSpaceInBytes(path: path)
                        }
                        self.diskMap[bsdName] = d
                        continue
                    }

                    if var d = self.getDriveDetails(disk: disk) {
                        if let path = d.path {
                            d.free = try self.getFreeSpaceInBytes(path: path)
                            d.size = try self.getTotalDiskSpaceInBytes(path: path)
                        }
                        if d.size == 0 {
                            continue
                        }

                        self.diskMap[bsdName] = d
                    }
                }
            }
        }

        for (key, _) in self.diskMap {
            if disks[key] == nil {
                self.diskMap.removeValue(forKey: key)
            }
        }
    }

    func getDisks() -> OrderedDictionary<String, Drive> {
        return self.diskMap
    }

    func readDriveStats() -> [String : (Int64, Int64)] {
        var res: [String: (Int64, Int64)] = [:]

        for (name, var disk) in self.diskMap {
            guard let props = getIOProperties(disk.parent) else {
                continue
            }

            if let statistics = props.object(forKey: "Statistics") as? NSDictionary {
                let readBytes = statistics.object(forKey: "Bytes (Read)") as? Int64 ?? 0
                let writeBytes = statistics.object(forKey: "Bytes (Write)") as? Int64 ?? 0

                var read = Int64(0)
                var write = Int64(0)

                if disk.activity.read != 0 {
                    read = readBytes - disk.activity.read
                }
                if disk.activity.write != 0 {
                    write = writeBytes - disk.activity.write
                }

                disk.activity = (readBytes, writeBytes)
                self.diskMap[name] = disk
                res[name] = (read, write)
            }
        }
        return res
    }

    private func getDriveDetails(disk: DADisk) -> Drive? {
        var d = Drive()

        d.BSDName = if let name = DADiskGetBSDName(disk) {
            String(cString: name)
        } else {
            "Unknown disk"
        }

        guard let diskDescription = DADiskCopyDescription(disk) as? [String: Any] else {
            return nil
        }

        if let uuid = diskDescription[kDADiskDescriptionMediaUUIDKey as String] {
            d.uuid = CFUUIDCreateString(kCFAllocatorDefault, (uuid as! CFUUID)) as String
        }
        if let media = diskDescription[kDADiskDescriptionVolumeNameKey as String] {
            d.mediaName = media as! String
            if d.mediaName == "Recovery" {
                return nil
            }
        }
        if d.mediaName.isEmpty {
            if let media = diskDescription[kDADiskDescriptionMediaNameKey as String] {
                d.mediaName = media as! String
                if d.mediaName == "Recovery" {
                    return nil
                }
            }
        }
        if let model = diskDescription[kDADiskDescriptionDeviceModelKey as String] {
            d.model = (model as! String).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let proto = diskDescription[kDADiskDescriptionDeviceProtocolKey as String] {
            d.connectionType = proto as! String
        }
        if let path = diskDescription[kDADiskDescriptionVolumePathKey as String] {
            if let url = path as? NSURL {
                d.path = url as URL

                if let components = url.pathComponents {
                    d.root = components.count == 1

                    if components.count > 1 && components[1] == "Volumes" {
                        if let name: String = url.lastPathComponent, name != "" {
                            d.mediaName = name
                        }
                    }
                }
            }
        }
        if let volumeKind = diskDescription[kDADiskDescriptionVolumeKindKey as String] {
            d.fileSystem = volumeKind as! String
        }

        if d.path == nil {
            return nil
        }
        let partitionLevel = d.BSDName.filter { "0"..."9" ~= $0 }.count
        if let parent = getDeviceIOParent(DADiskCopyIOMedia(disk), level: Int(partitionLevel)) {
            d.parent = parent
        }

        return d
    }

    private func getFreeSpaceInBytes(path: URL) throws -> Int64 {
        do {
            if let url = URL(string: path.absoluteString) {
                let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                if let capacity = values.volumeAvailableCapacityForImportantUsage, capacity != 0 {
                    return capacity
                }
            }
        } catch {
            throw ServiceError.unexpectedError(msg: "Failed to read free space [0]: \(error)")
        }

        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: path.path)
            if let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value {
                return freeSpace
            }
        } catch {
            throw ServiceError.unexpectedError(msg: "Failed to read free space [1]: \(error)")
        }

        return 0
    }

    private func getTotalDiskSpaceInBytes(path: URL) throws -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: path.path)
            if let totalSpace = (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value {
                return totalSpace
            }
        } catch {
            throw ServiceError.unexpectedError(msg: "Failed to read total space: \(error)")
        }

        return 0
    }
}

// https://opensource.apple.com/source/bless/bless-152/libbless/APFS/BLAPFSUtilities.c.auto.html
public func getDeviceIOParent(_ obj: io_registry_entry_t, level: Int) -> io_registry_entry_t? {
    var parent: io_registry_entry_t = 0

    if IORegistryEntryGetParentEntry(obj, kIOServicePlane, &parent) != KERN_SUCCESS {
        return nil
    }

    for _ in 1...level where IORegistryEntryGetParentEntry(parent, kIOServicePlane, &parent) != KERN_SUCCESS {
        IOObjectRelease(parent)
        return nil
    }

    return parent
}

public func getIOProperties(_ entry: io_registry_entry_t) -> NSDictionary? {
    var properties: Unmanaged<CFMutableDictionary>? = nil

    if IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) != kIOReturnSuccess {
        return nil
    }

    defer { properties?.release() }

    return properties?.takeUnretainedValue()
}
