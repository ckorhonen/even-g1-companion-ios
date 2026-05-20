# Even G1 Companion iOS

Native iOS 26 companion prototype for Even G1-style smart glasses.

This is not an official Even Realities SDK. It is an iOS-first port shaped
around the parts that are feasible with public Apple APIs:

- CoreBluetooth scanning and dual-leg pairing over the G1 UART service.
- App-owned HUD cards and streamed text.
- Safe firmware settings writes for brightness, tilt-up, double-tap action, mic
  toggle, and display clear.
- Liquid Glass SwiftUI interface for control, composing, and diagnostics.

The Android-first pieces from the source project are intentionally not cloned:
system-wide notification access, telephony watching, hidden background services,
and third-party app notification scraping do not map cleanly to public iOS APIs.

## Requirements

- Xcode 26.4 or newer
- iOS 26 SDK
- XcodeGen

## Build

```bash
xcodegen generate
xcodebuild -project EvenG1Companion.xcodeproj -scheme EvenG1Companion -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Status

This first cut compiles and runs in Simulator. Real hardware validation is still
required before treating any command as production-safe.

Implemented:

- UART service UUIDs and BLE scan/connect/write path.
- Text card packet builder (`0x4E`).
- Streaming text setup and line packets (`0x50`, `0x52`, `0x53`).
- Brightness (`0x01`), head-up (`0x08`), double-tap (`0x26`), mic (`0x0E`),
  and clear display (`0x50` + `0x18`) commands.
- Event parsing for common `0xF5` events.

Deferred:

- QuickNote LC3 decode and STT pipeline.
- Navigation card bitmap generation.
- ANCS or Accessory Transport notification forwarding.
- G2-specific validation.

