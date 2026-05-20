# Porting Notes

## Scope

This repository is an iOS-native port, not a Flutter port. The first version
keeps the feasible iOS surface:

- Bluetooth LE command/control.
- App-owned display content.
- Visible, user-initiated sessions.
- Native iOS 26 Liquid Glass UI.

It excludes Android-only behaviors:

- `NotificationListenerService` parity.
- `READ_PHONE_STATE`-style telephony monitoring.
- Android foreground service parity.
- Google Maps notification scraping.

## Protocol Baseline

The baseline comes from `Cheddies1/even-g1-companion` at
`bd3ebda6faf3c3490c954e17c6ca7cdd2c84e15d`.

Core BLE service:

- Service: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- Write: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- Notify: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`

Implemented command families:

- `0x4E`: text card packets.
- `0x50`: display mode setup/clear.
- `0x52`: streaming text mode and line updates.
- `0x53`: streaming keepalive.
- `0x01`: brightness.
- `0x08`: head-up setting.
- `0x26`: double-tap action setting.
- `0x0E`: mic enable/disable.
- `0x18`: exit-to-dashboard / clear completion.

## iOS Design Decisions

- Scan uses the explicit UART service UUID so it can work with iOS background
  BLE rules better than a broad nil-service scan.
- Writes are paced by user action in v1. A later hardware pass should add a
  command queue that respects `canSendWriteWithoutResponse` more aggressively.
- Text card chunks default to 160 UTF-8 bytes to stay conservative under iOS BLE
  write-size negotiation. The upstream protocol documents a 176-byte body limit.
- Notification mirroring is not implemented. If it becomes important, evaluate
  ANCS and Apple Accessory Transport as accessory/firmware-level work rather
  than app-only work.

