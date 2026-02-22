#!/usr/bin/env swift
import Foundation
import AudioToolbox

// List output devices: "Name\tUID" or "Name\tUID\tVolumePercent" when --with-volume
// Set volume: --set-volume UID 0-100
// Skips aggregate and virtual devices to match FineTune's device list.

private let systemObject = AudioObjectID(bitPattern: 1)

func readDeviceList() throws -> [AudioDeviceID] {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    var err = AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size)
    guard err == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil) }
    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
    err = AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &deviceIDs)
    guard err == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil) }
    return deviceIDs
}

func readString(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    var err = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
    guard err == noErr else { return nil }
    var ref: CFString?
    err = withUnsafeMutablePointer(to: &ref) { ptr in
        var sz = size
        return AudioObjectGetPropertyData(deviceID, &address, 0, nil, &sz, ptr)
    }
    guard err == noErr, let cf = ref else { return nil }
    return cf as String
}

func hasOutputStreams(deviceID: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    let err = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
    return err == noErr && size > 0
}

func isAggregateDevice(deviceID: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyClass,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var classID: AudioClassID = 0
    var size = UInt32(MemoryLayout<AudioClassID>.size)
    let err = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &classID)
    return err == noErr && classID == kAudioAggregateDeviceClassID
}

func isVirtualDevice(deviceID: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyTransportType,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var transportType: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    let err = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType)
    return err == noErr && transportType == kAudioDeviceTransportTypeVirtual
}

func readOutputVolumeScalar(deviceID: AudioDeviceID) -> Float? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectHasProperty(deviceID, &address) else { return nil }
    var volume: Float32 = 1.0
    var size = UInt32(MemoryLayout<Float32>.size)
    let err = AudioHardwareServiceGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
    return err == noErr ? volume : nil
}

func setOutputVolumeScalar(deviceID: AudioDeviceID, volume: Float) -> Bool {
    let clamped = max(0.0, min(1.0, volume))
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectHasProperty(deviceID, &address) else { return false }
    var volumeValue: Float32 = clamped
    let size = UInt32(MemoryLayout<Float32>.size)
    let err = AudioHardwareServiceSetPropertyData(deviceID, &address, 0, nil, size, &volumeValue)
    return err == noErr
}

struct DeviceInfo {
    let name: String
    let uid: String
    let deviceID: AudioDeviceID
}

var devices: [DeviceInfo] = []

do {
    let deviceIDs = try readDeviceList()
    for deviceID in deviceIDs {
        guard !isAggregateDevice(deviceID: deviceID) else { continue }
        guard hasOutputStreams(deviceID: deviceID), !isVirtualDevice(deviceID: deviceID) else { continue }
        guard let uid = readString(deviceID: deviceID, selector: kAudioDevicePropertyDeviceUID),
              let name = readString(deviceID: deviceID, selector: kAudioObjectPropertyName),
              !uid.isEmpty, !name.isEmpty else { continue }
        devices.append(DeviceInfo(name: name, uid: uid, deviceID: deviceID))
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}

devices.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

// --set-volume UID PERCENT
let args = CommandLine.arguments
if args.count == 4 && args[1] == "--set-volume" {
    let uid = args[2]
    guard let percent = Int(args[3]), (0...100).contains(percent) else {
        fputs("error: volume must be 0-100\n", stderr)
        exit(1)
    }
    guard let dev = devices.first(where: { $0.uid == uid }) else {
        fputs("error: device not found: \(uid)\n", stderr)
        exit(1)
    }
    let scalar = Float(percent) / 100.0
    if setOutputVolumeScalar(deviceID: dev.deviceID, volume: scalar) {
        exit(0)
    } else {
        fputs("error: failed to set volume (device may not support it)\n", stderr)
        exit(1)
    }
}

// Default or --with-volume: output name\tuid or name\tuid\tvolumePercent
let withVolume = args.contains("--with-volume")
for dev in devices {
    if withVolume, let scalar = readOutputVolumeScalar(deviceID: dev.deviceID) {
        let percent = Int(round(scalar * 100))
        print("\(dev.name)\t\(dev.uid)\t\(percent)")
    } else {
        print("\(dev.name)\t\(dev.uid)")
    }
}
