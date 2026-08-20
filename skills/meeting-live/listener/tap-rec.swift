// Captures all system audio with a Core Audio process tap and writes 16 kHz mono WAV chunks.
// Usage: tap-rec <output-dir> [chunk-seconds]
import Foundation
import CoreAudio
import AudioToolbox
import AVFoundation

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : NSTemporaryDirectory()
let chunkSeconds = args.count > 2 ? Double(args[2]) ?? 20.0 : 20.0
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func err(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

// 1. Global process tap (all processes, muted for nobody — we only listen).
let tapDesc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
tapDesc.name = "meeting-listener"
tapDesc.isPrivate = true
tapDesc.muteBehavior = .unmuted
var tapID = AUAudioObjectID(kAudioObjectUnknown)
let tapStatus = AudioHardwareCreateProcessTap(tapDesc, &tapID)
guard tapStatus == noErr else { err("AudioHardwareCreateProcessTap failed: \(tapStatus)"); exit(1) }
err("tap created id=\(tapID)")

// 2. Aggregate device that contains the tap.
let aggUID = "meeting-listener-agg"
let aggDesc: [String: Any] = [
    kAudioAggregateDeviceNameKey as String: "Meeting Listener",
    kAudioAggregateDeviceUIDKey as String: aggUID,
    kAudioAggregateDeviceIsPrivateKey as String: true,
    kAudioAggregateDeviceIsStackedKey as String: false,
    kAudioAggregateDeviceTapAutoStartKey as String: true,
    kAudioAggregateDeviceSubDeviceListKey as String: [],
    kAudioAggregateDeviceTapListKey as String: [
        [kAudioSubTapUIDKey as String: tapDesc.uuid.uuidString,
         kAudioSubTapDriftCompensationKey as String: true]
    ]
]
var aggID = AudioObjectID(kAudioObjectUnknown)
let aggStatus = AudioHardwareCreateAggregateDevice(aggDesc as CFDictionary, &aggID)
guard aggStatus == noErr else { err("AudioHardwareCreateAggregateDevice failed: \(aggStatus)"); exit(1) }
err("aggregate device id=\(aggID)")

// 3. Read the tap's stream format.
var addr = AudioObjectPropertyAddress(
    mSelector: kAudioTapPropertyFormat,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)
var asbd = AudioStreamBasicDescription()
var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
let fmtStatus = AudioObjectGetPropertyData(tapID, &addr, 0, nil, &size, &asbd)
guard fmtStatus == noErr else { err("tap format failed: \(fmtStatus)"); exit(1) }
err("tap format: \(asbd.mSampleRate) Hz, \(asbd.mChannelsPerFrame) ch, flags=\(asbd.mFormatFlags)")

let srcRate = asbd.mSampleRate
let srcChannels = Int(asbd.mChannelsPerFrame)
let dstRate = srcRate   // keep native rate; listen.sh resamples with ffmpeg
let ratio = srcRate / dstRate

final class Sink {
    var samples: [Int16] = []
    var chunkStart = Date()
    var acc = 0.0
    let q = DispatchQueue(label: "wav")

    func feed(_ mono: [Float]) {
        // naive decimation to 16 kHz
        var i = 0.0
        while Int(i) < mono.count {
            let v = max(-1.0, min(1.0, mono[Int(i)]))
            samples.append(Int16(v * 32767.0))
            i += ratio
        }
        if Date().timeIntervalSince(chunkStart) >= chunkSeconds { flush() }
    }

    func flush() {
        guard !samples.isEmpty else { chunkStart = Date(); return }
        let data = samples; samples = []
        let started = chunkStart; chunkStart = Date()
        q.async { self.write(data, started) }
    }

    private func write(_ pcm: [Int16], _ started: Date) {
        let name = String(format: "chunk-%.0f.wav", started.timeIntervalSince1970)
        let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        let bytes = UInt32(pcm.count * 2)
        d.append("RIFF".data(using: .ascii)!); u32(36 + bytes); d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
        u32(UInt32(dstRate)); u32(UInt32(dstRate) * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(bytes)
        pcm.withUnsafeBufferPointer { d.append(Data(buffer: $0)) }
        try? d.write(to: url)
        err("wrote \(name) (\(pcm.count) samples)")
    }
}

let sink = Sink()
var procID: AudioDeviceIOProcID?
let ioStatus = AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, nil) { _, inData, _, _, _ in
    let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
    guard let first = list.first, let mData = first.mData else { return }
    let frames = Int(first.mDataByteSize) / MemoryLayout<Float32>.size
    let p = mData.bindMemory(to: Float32.self, capacity: frames)
    var mono = [Float](); mono.reserveCapacity(frames / max(1, srcChannels))
    if Int(first.mNumberChannels) > 1 {
        let ch = Int(first.mNumberChannels)
        var i = 0
        while i + ch <= frames { mono.append(p[i]); i += ch }
    } else {
        for i in 0..<frames { mono.append(p[i]) }
    }
    sink.feed(mono)
}
guard ioStatus == noErr, let procID else { err("AudioDeviceCreateIOProcID failed: \(ioStatus)"); exit(1) }
let startStatus = AudioDeviceStart(aggID, procID)
guard startStatus == noErr else { err("AudioDeviceStart failed: \(startStatus)"); exit(1) }
err("capturing system audio -> \(outDir)")

func cleanup() {
    sink.flush()
    AudioDeviceStop(aggID, procID)
    AudioDeviceDestroyIOProcID(aggID, procID)
    AudioHardwareDestroyAggregateDevice(aggID)
    AudioHardwareDestroyProcessTap(tapID)
}
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)
let sigInt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigInt.setEventHandler { cleanup(); exit(0) }
sigInt.resume()
let sigTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigTerm.setEventHandler { cleanup(); exit(0) }
sigTerm.resume()
RunLoop.main.run()
