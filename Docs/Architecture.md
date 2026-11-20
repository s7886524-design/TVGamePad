# TVGamePad architecture

## iOS app

- `ContentView.swift`: landscape controller UI and manual TV connection panel.
- `ControllerInput.swift`: normalized button down/up event model.
- `TVConnectionModel`: TCP reachability/session lifecycle for the observed CooCaa port.

## Input pipeline

Touch gestures produce `ControllerInputEvent` values with a button name and pressed/released phase. The event model deliberately has no network encoder yet. Once the CooCaa wire format is confirmed, a protocol adapter can subscribe to these events without coupling the UI to packet details.

## Connection pipeline

The current connection check opens a TCP connection to the manually entered TV address on port 62015. A successful TCP connection means only that the socket accepted a connection. It does not mean the CooCaa pairing/authentication succeeded.

## Discovery

No Bonjour service type or UDP discovery format has been confirmed. Do not invent a Bonjour service name or send arbitrary broadcast packets. Add automatic discovery only after the target protocol is identified.

## Build policy

GitHub Actions contains a simulator build workflow. Do not trigger it until the user explicitly asks to build.