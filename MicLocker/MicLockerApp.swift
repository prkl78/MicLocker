// MicLockerApp.swift - Main app entry point with mic enumeration, persistence, enforcement, and Dock icon hiding

import SwiftUI
import AVFoundation
import CoreAudio
import AppKit

@main
struct MicLockerApp: App {
    @State private var selectedMicID: String? = UserDefaults.standard.string(forKey: "SelectedMicID")
    @State private var microphones: [AVCaptureDevice] = []
    
    // Timer for continuous enforcement
    let enforcementTimer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()
    
    init() {
        // Programmatically hide Dock icon by setting activation policy to accessory
        print("[MicLocker] Setting app activation policy to accessory to hide Dock icon")
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra("MicLocker", systemImage: "mic.fill") {
            ContentView(microphones: $microphones, selectedMicID: $selectedMicID)
                .onAppear {
                    print("[MicLocker] ContentView appeared, loading microphones")
                    loadMicrophones()
                }
                .onReceive(enforcementTimer) { _ in
                    enforceSelectedMic()
                }
        }
    }
    
    // Load available audio input devices using AVFoundation
    private func loadMicrophones() {
        let devices = AVCaptureDevice.devices(for: .audio)
        print("[MicLocker] Found \(devices.count) audio input devices")
        for device in devices {
            print("[MicLocker] Device: \(device.localizedName), uniqueID: \(device.uniqueID)")
        }
        DispatchQueue.main.async {
            self.microphones = devices
            if let selectedID = self.selectedMicID, !devices.contains(where: { $0.uniqueID == selectedID }) {
                print("[MicLocker] Previously selected mic not found, clearing selection")
                self.selectedMicID = nil
                UserDefaults.standard.removeObject(forKey: "SelectedMicID")
            }
        }
    }
    
    // Enforce the selected microphone as the system default input device
    private func enforceSelectedMic() {
        guard let selectedID = selectedMicID else {
            print("[MicLocker] No microphone selected to enforce")
            return
        }
        print("[MicLocker] Enforcing selected microphone with ID: \(selectedID)")
        
        // Use CoreAudio to set the default input device
        var defaultDeviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        // Find the AudioDeviceID for the selected mic uniqueID
        if let deviceID = getAudioDeviceID(forUniqueID: selectedID) {
            defaultDeviceID = deviceID
            
            let status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                size,
                &defaultDeviceID
            )
            if status == noErr {
                print("[MicLocker] Successfully set default input device to \(selectedID)")
            } else {
                print("[MicLocker] Failed to set default input device, error code: \(status)")
            }
        } else {
            print("[MicLocker] Could not find AudioDeviceID for selected mic")
        }
    }
    
    // Helper to get AudioDeviceID from uniqueID string
    private func getAudioDeviceID(forUniqueID uniqueID: String) -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        if status != noErr {
            print("[MicLocker] Error getting property data size: \(status)")
            return nil
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        if status != noErr {
            print("[MicLocker] Error getting device IDs: \(status)")
            return nil
        }
        
        for id in deviceIDs {
            var cfUniqueID: CFString? = nil
            var propAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var propSize = UInt32(MemoryLayout<CFString?>.size)
            status = AudioObjectGetPropertyData(id, &propAddr, 0, nil, &propSize, &cfUniqueID)
            if status == noErr, let cfUniqueID = cfUniqueID as String?, cfUniqueID == uniqueID {
                return id
            }
        }
        return nil
    }
}

// MARK: - ContentView for menu bar content
struct ContentView: View {
    @Binding var microphones: [AVCaptureDevice]
    @Binding var selectedMicID: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Force use of this microphone")
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .padding(.bottom, 4)
            Divider()
            if microphones.isEmpty {
                Text("No microphones found")
                    .foregroundColor(.red)
            } else {
                ForEach(microphones, id: \ .uniqueID) { mic in
                    Button(action: {
                        selectedMicID = mic.uniqueID
                        UserDefaults.standard.set(mic.uniqueID, forKey: "SelectedMicID")
                        print("[MicLocker] Selected microphone: \(mic.localizedName) (ID: \(mic.uniqueID))")
                    }) {
                        HStack {
                            Text(mic.localizedName)
                            Spacer()
                            if selectedMicID == mic.uniqueID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 250)
        .padding(8)
    }
}
