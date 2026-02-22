#!/usr/bin/env swift
import Foundation
import AppKit
import AudioToolbox
import Darwin

// Core Audio process property selectors (from AudioHardware.h)
private let kAudioObjectSystemObject = AudioObjectID(bitPattern: 1)
private let kAudioObjectPropertyScopeGlobal: AudioObjectPropertyScope = 0
private let kAudioObjectPropertyElementMain: AudioObjectPropertyElement = 0

// Process list (from AudioHardware.h: 'prs#')
private let kAudioHardwarePropertyProcessObjectList: AudioObjectPropertySelector = 0x70727323
// Process properties (from AudioHardware.h)
private let kAudioProcessPropertyPID: AudioObjectPropertySelector = 0x70706964           // 'ppid'
private let kAudioProcessPropertyIsRunning: AudioObjectPropertySelector = 0x7069723F   // 'pir?'
private let kAudioProcessPropertyBundleID: AudioObjectPropertySelector = 0x70626964    // 'pbid'

private let systemDaemonPrefixes = [
    "com.apple.siri", "com.apple.Siri", "com.apple.assistant", "com.apple.audio",
    "com.apple.coreaudio", "com.apple.mediaremote", "com.apple.accessibility.heard",
    "com.apple.hearingd", "com.apple.voicebankingd", "com.apple.systemsound",
    "com.apple.FrontBoardServices", "com.apple.frontboard", "com.apple.springboard",
    "com.apple.notificationcenter", "com.apple.NotificationCenter", "com.apple.UserNotifications",
    "com.apple.usernotifications",
]

private let systemDaemonNames = ["systemsoundserverd", "systemsoundserv", "coreaudiod", "audiomxd"]

func isSystemDaemon(bundleID: String?, name: String) -> Bool {
    if let bundleID {
        if systemDaemonPrefixes.contains(where: { bundleID.hasPrefix($0) }) { return true }
    }
    let lower = name.lowercased()
    if systemDaemonNames.contains(where: { lower.hasPrefix($0) }) { return true }
    return false
}

func readProcessList() throws -> [AudioObjectID] {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    var err = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, nil, &size)
    guard err == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil) }
    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    var objectIDs = [AudioObjectID](repeating: 0, count: count)
    err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, nil, &size, &objectIDs)
    guard err == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil) }
    return objectIDs
}

func readProcessPID(objectID: AudioObjectID) throws -> pid_t {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyPID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var pid: pid_t = 0
    var size = UInt32(MemoryLayout<pid_t>.size)
    let err = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &pid)
    guard err == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil) }
    return pid
}

func readProcessIsRunning(objectID: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyIsRunning,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    let err = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
    return err == noErr && value != 0
}

func readProcessBundleID(objectID: AudioObjectID) -> String? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyBundleID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    var err = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size)
    guard err == noErr else { return nil }
    var cfString: CFString = "" as CFString
    err = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &cfString)
    guard err == noErr else { return nil }
    return cfString as String
}

let myPID = ProcessInfo.processInfo.processIdentifier
let runningApps = NSWorkspace.shared.runningApplications
var seen = Set<String>()
var lines: [String] = []

do {
    let processIDs = try readProcessList()
    for objectID in processIDs {
        guard readProcessIsRunning(objectID: objectID) else { continue }
        guard let pid = try? readProcessPID(objectID: objectID), pid != myPID else { continue }
        let directApp = runningApps.first { $0.processIdentifier == pid }
        let isRealApp = directApp?.bundleURL?.pathExtension == "app"
        let resolvedApp: NSRunningApplication? = isRealApp ? directApp : {
            var currentPID = pid
            var visited = Set<pid_t>()
            while currentPID > 1, !visited.contains(currentPID) {
                visited.insert(currentPID)
                if let app = runningApps.first(where: { $0.processIdentifier == currentPID }),
                   app.bundleURL?.pathExtension == "app" { return app }
                var info = kinfo_proc()
                var size = MemoryLayout<kinfo_proc>.size
                var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, currentPID]
                guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { break }
                let parentPID = info.kp_eproc.e_ppid
                if parentPID == currentPID { break }
                currentPID = parentPID
            }
            return nil
        }()
        let name = resolvedApp?.localizedName
            ?? readProcessBundleID(objectID: objectID)?.split(separator: ".").last.map(String.init)
            ?? "Unknown"
        let bundleID = resolvedApp?.bundleIdentifier ?? readProcessBundleID(objectID: objectID)
        guard let bundleID = bundleID, !bundleID.isEmpty else { continue }
        if isSystemDaemon(bundleID: bundleID, name: name) { continue }
        if seen.contains(bundleID) { continue }
        seen.insert(bundleID)
        lines.append("\(name)\t\(bundleID)")
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}

lines.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.forEach { print($0) }
