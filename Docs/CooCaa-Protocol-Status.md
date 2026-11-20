# CooKaa virtual controller protocol status

## Source and analysis

- Source APK: CooKaa game 1.4.5, stored by the user in the public s7886524-design/rea repository.
- Static analysis: GitHub Actions run 44818653783, completed successfully.
- Artifact: CooKaa-1.4.5-static-analysis (14-day retention).
- Decompiled implementation classes are in package com.cocav.tiemu.service.

## Confirmed discovery protocol

TiVirtualKeypad starts a UDP broadcaster when the TV-side virtual-pad screen is waiting for a phone:
- Destination: IPv4 broadcast 255.255.255.255
- UDP destination port: 64315
- Interval: 500 ms
- Payload: TiObjectConverter.getBytes(VirtualPadModel)
- VirtualPadModel has Ti class ID 3
- Header 1: TV address string, formatted as ip:62015
- Header 10: Android Build.MODEL device name

The iPhone should listen on UDP 64315 while the TV's virtual-pad waiting screen is active. It should not send an invented discovery packet.

## Confirmed TCP registration and approval

The TV listens on 0.0.0.0:62015. TiVirtualKeypad handles method 112 (Register):
- Header 7: opaque authentication key bytes; the TV uses the hex representation as the pending device key.
- Header 10: controller display name.
- A transaction sequence header is required for a response.
- If the TV-side waiting state is active and this key has not already been approved, the TV broadcasts ACTION_VKEY_NEED_AUTH and shows an approval dialog.
- Accepting on the TV broadcasts Action_VKEY_AUTHED; the TV then attaches a TiVirtualKeypadEvent handler and responds with 0xF0 (OK).
- Rejecting responds with 0xFC (NotAvailable).
- This is an explicit on-TV user approval flow. Static code does not show a cryptographic challenge/response exchange.

## Confirmed key event protocol

TiVirtualKeypadEvent handles:
- Method 4: key down (KeyEvent.ACTION_DOWN).
- Method 3: key up (KeyEvent.ACTION_UP).
- Header 16: 32-bit big-endian Android key code.
- Header 0xFE: transaction sequence, 32-bit big-endian.
- The TV sends an OK response for sequenced transactions.

The TV additionally remaps Android key codes 96/108 to DPAD_CENTER and 97 to BACK. DPAD directions are 19/20/21/22.

## Wire framing recovered

TiMessage.toBytes() and TiHeader.toBytes() use a compact TLV-like format:
- Message: method byte, message payload length, then headers.
- Header: type byte, value length, value bytes.
- Lengths 0-127 use one byte; larger lengths use two bytes with the high bit set in the first byte.
- Integer values use big-endian byte order.
- VirtualPadModel strings use UTF-8.

The iOS project now contains CooCaaWireProtocol.swift for advertisement decoding and message encoding, and CooCaaProtocolAdapter.swift for method/key-code mapping.

## Remaining implementation and runtime validation

- Integrate UDP 64315 listening into the iOS connection screen.
- Connect to the discovered ip:62015, register with a generated opaque key and device name, and wait for the TV approval response.
- Keep the TCP stream parser robust to partial/coalesced frames.
- Send sequenced key-down/key-up requests only after successful registration.
- Test on the actual TV and confirm one button press/release before calling the app fully compatible.

## Safety and compatibility boundary

- The original CooKaa APK and game resources remain unchanged.
- No arbitrary packets are sent before the registration format is implemented.
- A TCP socket connection alone is not considered successful pairing.
- Static analysis is evidence of code paths, not proof of runtime behavior on every TV firmware version.
