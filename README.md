# TVGamePad

An iPhone-native virtual controller for a Skyworth/CooCaa Android TV.

## Current development status

The exact CooKaa 1.4.5 APK has now been statically analyzed in GitHub Actions. The recovered protocol shows:

- TV discovery: UDP broadcast to 255.255.255.255:64315 every 500 ms while the TV-side virtual-pad screen is waiting.
- Advertisement payload: Ti model message (class ID 3), header 1 = TV address ending in :62015, header 10 = TV model name.
- TCP service: TV listens on port 62015.
- Registration: method 112, header 7 = opaque client key, header 10 = controller name. The TV asks the user to approve the pairing on the TV screen.
- Input: method 4 for key down, method 3 for key up, header 16 = 32-bit Android key code, header 0xFE = transaction sequence.

The iOS repository now contains a TiMessage wire codec and Android key-code adapter based on the decompiled implementation. UDP discovery, TCP registration/approval handling, stream parsing, and end-to-end input delivery still need integration and testing on the actual TV. The app must not be described as fully working until that test passes.

## Planned and implemented UI features

- Native SwiftUI iPhone app, landscape-first controller screens.
- FC/NES, Mega Drive/Genesis, SFC/SNES, PlayStation-style, and Xbox-style layouts.
- Button down/up state and a protocol adapter boundary.
- LAN discovery and TV-approved pairing are the next integration stage.

## Repository layout

- iOS/TVGamePad: SwiftUI app and CooKaa protocol implementation.
- Docs: architecture and protocol analysis notes.
- .github/workflows: automatic iOS Simulator build on relevant main-branch changes.

## Build

The iOS workflow builds for the simulator without signing. A distributable iPhone IPA requires a signing certificate/profile or a configured signing service.

## Safety / compatibility

The original CooKaa APK and game resources remain unchanged. Static analysis is not a substitute for validating pairing and button events on the target TV.