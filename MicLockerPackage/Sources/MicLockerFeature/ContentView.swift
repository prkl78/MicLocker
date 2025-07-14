import SwiftUI
import AppKit

public struct ContentView: View {
    @StateObject private var manager = AudioDeviceManager()
    
    /// Calculate width based on longest item and header text
    private var menuWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let header = "Force use of this microphone"
        let allTexts = manager.devices.map { $0.name } + [header]
        let maxTextWidth = allTexts.map {
            NSString(string: $0).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return maxTextWidth + 40 // add space for checkmark and padding
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Force use of this microphone")
                .font(.headline)
            Divider()
            if manager.devices.isEmpty {
                Text("No input devices found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(manager.devices) { device in
                    Button(action: {
                        manager.setDefaultInputDevice(device.id)
                    }) {
                        HStack {
                            Text(device.name)
                            Spacer()
                            if manager.selectedDeviceID == device.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(8)
        .frame(width: menuWidth)
    }
    
    public init() {}
}
