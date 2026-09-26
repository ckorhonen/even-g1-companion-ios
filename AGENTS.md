# Repository agent guide

## Repository workflow and completion

This SwiftUI/Bluetooth prototype uses XcodeGen `project.yml` and the `EvenG1Companion` scheme. README requires Xcode 26.4+ and iOS 26. Run `xcodegen generate`, then build/test using an installed compatible simulator. Keep unit/UI tests aligned with the affected app/protocol code.

Simulator checks cannot prove BLE pairing or glasses behavior. Protocol edits need deterministic byte fixtures and authorized physical-device readback. Preserve the public-Apple-API boundary; do not claim system-wide notification access. Connections, settings, and display writes must target an authorized device; report hardware coverage separately.

Continue the authorized change through relevant validation and repair of failures it causes; preserve unrelated work. Report checks actually run, commands only inspected, and exact missing prerequisites. Ask only when a material decision, missing authorization, or required input blocks progress; continue independent reversible work. Existing mandatory contribution and validation gates still apply.
