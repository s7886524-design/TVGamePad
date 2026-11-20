# CooKaa virtual controller protocol status

## Recovered from CooKaa 1.4.5 APK

- TV discovery: IPv4 broadcast 255.255.255.255:64315 every 500 ms while the TV virtual-pad waiting UI is active.
- Advertisement model: Ti class ID 3; header 1 contains the TV address and TCP port 62015; header 10 contains the TV model name.
- TV TCP service: port 62015.
- Registration: method 112; header 7 is an opaque client key; header 10 is the controller display name.
- The TV asks the user to approve the connection on the TV. Accepted registration returns 0xF0; rejected registration returns 0xFC.
- Key down: method 4. Key up: method 3. Header 16 is a 32-bit big-endian Android key code. Header 0xFE is a 32-bit big-endian transaction sequence.
- TiMessage uses method + compact length + typed headers. Lengths up to 127 use one byte; larger lengths use two bytes.

## iOS implementation now present

- CooCaaWireProtocol.swift: message framing, advertisement decode, registration and key event encoders, incremental TCP frame sizing.
- CooCaaProtocolAdapter.swift: random opaque registration key and Android gamepad key-code mapping.
- CooCaaSession.swift: UDP 64315 listener, discovered TV address handling, TCP 62015 connect, registration request, TV approval response handling, incremental TCP receive buffer, sequenced key-down/up send.
- ContentView.swift: starts discovery on launch, offers manual IP connect and discovered-TV connect, forwards press/release events into the session.

## Runtime validation still required

Static analysis and compilation do not prove compatibility with the user's TV firmware. The iPhone and TV must be on the same LAN. On the TV, open CooKaa's Connect Virtual Controller waiting screen first; then open TVGamePad and search. Select the discovered TV, and accept the pairing prompt on the TV. Only after the app reports TV authorization should key events be sent.

Potential firmware differences, broadcast delivery behavior on iOS, the exact advertisement envelope, and the registration response framing must be validated on the actual TV. Do not claim full end-to-end success until a physical button press and release are confirmed.

The original APK and game resources are not modified.