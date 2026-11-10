import AppKit

/// Handles tinyhand:// URLs and mirrors the app state to a JSON file, so launchers
/// like Raycast can drive TinyHand and read what it is doing.
final class Automation {
    static let stateURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/TinyHand/state.json")

    private let overlay: OverlayController

    init(overlay: OverlayController) {
        self.overlay = overlay
        NotificationCenter.default.addObserver(forName: CustomHands.changed, object: nil, queue: .main) { [weak self] _ in
            self?.writeState()
        }
    }

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "tinyhand", let command = url.host?.lowercased() else {
            return
        }
        let argument = url.pathComponents.dropFirst().first
        Log.write("url command: \(command) \(argument ?? "")")

        switch command {
        case "on":
            overlay.activate()
        case "off":
            overlay.deactivate()
        case "toggle":
            overlay.toggle()
        case "clear":
            overlay.clearInk()
        case "style":
            selectStyle(argument)
        case "sound":
            setSound(argument)
        default:
            Log.write("unknown url command: \(command)")
        }
    }

    private func selectStyle(_ id: String?) {
        guard let id = id, let style = PointerStyle(rawValue: id) else {
            Log.write("unknown pointer style: \(id ?? "none")")
            return
        }
        overlay.pick(style)
        overlay.activate()
    }

    private func setSound(_ value: String?) {
        switch value {
        case "on":
            overlay.soundOn = true
        case "off":
            overlay.soundOn = false
        case "toggle", nil:
            overlay.soundOn.toggle()
        default:
            Log.write("unknown sound value: \(value ?? "")")
        }
    }

    func writeState() {
        let styles: [[String: String]] = PointerStyle.allCases.map { style in
            let type = style == .laser ? "laser" : style.isCustom ? "custom" : "hand"
            return ["id": style.rawValue, "name": style.title, "type": type]
        }
        let state: [String: Any] = [
            "pid": Int(getpid()),
            "active": overlay.isActive,
            "style": overlay.style.rawValue,
            "soundOn": overlay.soundOn,
            "styles": styles,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        let dir = Automation.stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: Automation.stateURL, options: .atomic)
    }
}
