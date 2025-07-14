// AudioDeviceManager.swift
// Description: Manages audio input devices using Core Audio and publishes updates.

import Foundation
import CoreAudio
import Combine

public struct AudioDevice: Identifiable {
    public let id: AudioDeviceID
    public let name: String
}

// Ensure updates to devices happen on the main actor to avoid data races
@MainActor
public class AudioDeviceManager: ObservableObject {
    @Published public private(set) var devices: [AudioDevice] = []
    @Published public var selectedDeviceID: AudioDeviceID?

    public init() {
        fetchInputDevices()
        // Load saved selection
        if let saved = UserDefaults.standard.value(forKey: "selectedDeviceID") as? UInt32 {
            setDefaultInputDevice(saved)
        }
        // Start listening for default input changes
        startListeningForChanges()
    }

    private func fetchInputDevices() {
        // Get all audio device IDs
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster)

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize)
        guard status == noErr else {
            print("Error getting devices data size: \(status)")
            return
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceIDs)
        guard status == noErr else {
            print("Error getting device IDs: \(status)")
            return
        }

        var inputs: [AudioDevice] = []
        for id in deviceIDs {
            // Check input stream configuration
            var configAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMaster)
            var configSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(id, &configAddress, 0, nil, &configSize)
            if status != noErr || configSize == 0 {
                continue
            }

            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(configSize))
            defer { bufferList.deallocate() }
            status = AudioObjectGetPropertyData(id, &configAddress, 0, nil, &configSize, bufferList)
            if status != noErr {
                continue
            }

            let buffers = UnsafeBufferPointer(start: &bufferList.pointee.mBuffers, count: Int(bufferList.pointee.mNumberBuffers))
            let channels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard channels > 0 else { continue }

            // Fetch device name
            var nameCF: CFString = "" as CFString
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMaster)
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &nameCF)
            let name = (status == noErr) ? (nameCF as String) : "Unknown"

            inputs.append(AudioDevice(id: id, name: name))
        }

        // Update published devices on main actor
        devices = inputs
        print("Fetched input devices: \(inputs.map { $0.name })")
    }

    /// Sets the system default input device to the given device ID
    public func setDefaultInputDevice(_ deviceID: AudioDeviceID) {
        var id = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster)
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &id)
        if status != noErr {
            print("Failed to set default input device: \(status)")
        } else {
            selectedDeviceID = deviceID
            UserDefaults.standard.set(deviceID, forKey: "selectedDeviceID")
            print("Default input device set to \(deviceID)")
        }
    }

    /// Listen for system default input device changes and enforce selected device
    private func startListeningForChanges() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main) { [weak self] _, _ in
                guard let self = self, let selected = self.selectedDeviceID else { return }
                print("System input changed, forcing back to \(selected)")
                self.setDefaultInputDevice(selected)
        }
    }
} 