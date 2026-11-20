# TVGamePad

An iPhone-native virtual controller for a Skyworth/CooCaa Android 8.0 TV.

## Current development status

This repository starts the independent iOS app and Android TV receiver workspace. The CooCaa virtual-pad service was observed listening on TCP port **62015** on the target TV. That confirms a listener exists; it does **not** establish the wire protocol, authentication exchange, discovery mechanism, or button packet format.

The app therefore does not send guessed packets or modify the installed CooCaa APK. The first milestone is a native controller UI plus a safe TCP reachability check. Actual control remains gated on documenting the protocol from the APK and/or a legitimate test session.

## Planned features

- Native SwiftUI iPhone app, landscape-first controller screens.
- FC/NES, Mega Drive/Genesis, SFC/SNES, PlayStation-style, and Xbox-style layouts.
- Button down/up state, turbo, customizable layouts.
- LAN TV discovery and pairing.
- CooCaa protocol adapter, only after the handshake and packet format are verified.
- Android TV receiver for independent/test integrations where needed.

## Repository layout

- `iOS/TVGamePad`: SwiftUI app.
- `AndroidTV`: Android TV receiver workspace.
- `.github/workflows`: unsigned iOS simulator build and Android debug build.

## Build

The iOS workflow builds for the simulator without signing. A distributable iPhone IPA requires a signing certificate/profile or a configured signing service. The Android workflow builds a debug APK.

## Network permissions

The iOS app requires Local Network permission. iOS will prompt on first LAN use. Both devices must be on the same Wi-Fi/LAN, and client isolation on the router must be disabled.

## Safety / compatibility

Do not assume that TCP port 62015 alone is sufficient for compatibility. Do not alter or replace the original CooCaa app or its game resources.