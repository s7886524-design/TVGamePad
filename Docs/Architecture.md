# TVGamePad architecture

## iOS app

- ContentView.swift: landscape controller UI and connection panel.
- ControllerInput.swift: normalized button down/up events.
- CooCaaWireProtocol.swift: recovered TiMessage framing, TV UDP advertisement decoding, registration and key-event encoders.
- CooCaaProtocolAdapter.swift: registration identity and Android KeyEvent mapping.

## Recovered CooKaa 1.4.5 protocol

- TV advertises on UDP broadcast port 64315 while its virtual-pad waiting screen is active.
- Advertisement contains a Ti model message (class ID 3), header 1 = TV ip:62015, header 10 = TV model name.
- iPhone connects to the TV TCP listener on port 62015.
- Register is method 112, header 7 = opaque client key bytes, header 10 = controller display name.
- The TV asks the user to approve the connection on the TV screen. Successful approval returns response 0xF0.
- Key down is method 4; key up is method 3; header 16 carries a 32-bit big-endian Android key code.
- Each request includes header 0xFE with a 32-bit big-endian transaction sequence.

## Remaining connection work

The wire codec and key mapping are committed, but the current screen still performs only a manual TCP reachability check. UDP discovery, registration/approval state, stream framing, and actual input delivery must be integrated and tested before claiming end-to-end controller support.

## Build policy

GitHub Actions is configured to start an iOS Simulator build automatically after relevant source changes on main. Simulator build output is not an installable signed iPhone IPA.