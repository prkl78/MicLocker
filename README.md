# MicLocker - macOS App

MicLocker is a lightweight menu bar utility for macOS that locks your preferred microphone input device. It prevents macOS from automatically switching your mic (for example, to AirPods) when new audio hardware connects. Simply select your favorite mic from the menu bar, and MicLocker will enforce that choice continuously.

<p align="center">
  <img src="assets/mic-menu.png" alt="Mic selection menu" width="400"/>
</p>

## Features
- Locks the system default input to your chosen microphone
- Menu bar picker built with SwiftUI's `MenuBarExtra` (no Dock icon)
- Dynamic menu width and aligned checkmarks
- Persists your selection across restarts
- Listens for default-input changes and re-applies your choice in real time
- Console logs for visibility and debugging

## Usage
1. Build and run the app in Xcode or launch the `.app` bundle directly.
2. Click the mic icon in the menu bar.
3. Choose **Force use of this microphone** and select your device.
4. The app will continually enforce your selection, even when new devices (like AirPods) connect.

## Building & Installation
- Requirements: macOS 15.4 or later, Xcode 16+
- Open `MicLocker.xcworkspace` and build the **MicLocker** scheme.
- To install permanently, copy the built `MicLocker.app` into `/Applications`.

A modern macOS application using a **workspace + SPM package** architecture for clean separation between app shell and feature code.

## Project Architecture

```
MicLocker/
├── MicLocker.xcworkspace/              # Open this file in Xcode
├── MicLocker.xcodeproj/                # App shell project
├── MicLocker/                          # App target (minimal)
│   ├── Assets.xcassets/                # App-level assets (icons, colors)
│   ├── MicLockerApp.swift              # App entry point
│   ├── MicLocker.entitlements          # App sandbox settings
│   └── MicLocker.xctestplan            # Test configuration
├── MicLockerPackage/                   # 🚀 Primary development area
│   ├── Package.swift                   # Package configuration
│   ├── Sources/MicLockerFeature/       # Your feature code
│   └── Tests/MicLockerFeatureTests/    # Unit tests
└── MicLockerUITests/                   # UI automation tests
```
