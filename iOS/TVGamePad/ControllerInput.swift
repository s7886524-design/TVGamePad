import Foundation
import Combine

enum ControllerInputPhase {
    case pressed
    case released
}

struct ControllerInputEvent: Identifiable {
    let id = UUID()
    let button: String
    let phase: ControllerInputPhase
    let timestamp = Date()
}

@MainActor
final class ControllerInputState: ObservableObject {
    @Published private(set) var pressedButtons: Set<String> = []
    @Published private(set) var latestEvent = "等待按键"
    @Published private(set) var eventCount = 0

    var onEvent: ((ControllerInputEvent) -> Void)?
    private var activeEventButtons: [String: String] = [:]

    func update(_ button: String, eventButton: String? = nil, pressed: Bool) {
        let wasPressed = pressedButtons.contains(button)
        guard wasPressed != pressed else { return }

        if pressed {
            pressedButtons.insert(button)
            activeEventButtons[button] = eventButton ?? button
        } else {
            pressedButtons.remove(button)
        }

        eventCount += 1
        latestEvent = "\(button) · \(pressed ? "DOWN" : "UP")"
        let wireButton = pressed ? (eventButton ?? button) : (activeEventButtons.removeValue(forKey: button) ?? eventButton ?? button)
        onEvent?(ControllerInputEvent(button: wireButton, phase: pressed ? .pressed : .released))
    }

    func releaseAll() {
        let current = Array(pressedButtons)
        for button in current {
            update(button, pressed: false)
        }
        activeEventButtons.removeAll()
    }
}
