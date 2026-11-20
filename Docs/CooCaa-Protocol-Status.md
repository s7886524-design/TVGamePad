# CooCaa virtual controller protocol status

## Confirmed observations from the target TV

- Target: Skyworth/CooCaa Android TV, Android 8.0.
- Package process observed: `com.cocav.tiemu:virtualkeypad`.
- A TCP listener was observed on port `62015` (hex `F23F`) bound to the wildcard IPv6 address.
- The CooCaa UI shown by the user has a single action to connect a virtual controller and then waits/spins while searching for a phone.
- No APK file or verified class-level analysis is currently available in this project workspace. Earlier references to specific virtual-keypad class names are not treated as verified evidence.

## Not yet confirmed

- Whether the iPhone initiates TCP or the TV initiates a connection after discovery.
- UDP discovery destination, port, packet contents, and response.
- Authentication challenge/response fields and cryptographic transformation.
- TCP frame boundaries, byte order, message types, button identifiers, and release semantics.
- Whether the TV requires a controller identity, device name, or session token.

## Engineering rule

Do not send speculative bytes to the CooCaa service. The iOS app currently performs only an explicit TCP reachability/session check on port 62015. It does not claim to authenticate, pair, or control a game.

## Next protocol investigation

1. Obtain the exact CooCaa APK used on the TV (the APK is not currently present in the project workspace or accessible file library).
2. Inspect its virtual-keypad classes and resources; verify class names from the actual binary rather than relying on earlier unverified references.
3. Trace the discovery start/stop path and identify the exact UDP socket configuration.
4. Record one legitimate pairing attempt and correlate TV logs with network socket activity.
5. Recover the authentication exchange and framing from code before implementing a protocol adapter.
6. Validate a single button-down and button-up pair, then test simultaneous inputs and disconnect cleanup.

## Compatibility boundary

Keep the original CooCaa APK and installed game resources unchanged. Any protocol work should be performed against the existing app and a controlled test session.