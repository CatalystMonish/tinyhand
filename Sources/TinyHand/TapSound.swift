import AppKit
import AVFoundation

enum TapSoundChoice: String, CaseIterable {
    case thock, click, pop, wood, boop, squeak

    var title: String {
        switch self {
        case .thock: return "Thock"
        case .click: return "Click"
        case .pop: return "Pop"
        case .wood: return "Wood block"
        case .boop: return "Boop"
        case .squeak: return "Squeak"
        }
    }
}

/// Plays the tap sound. Every AVAudioEngine call runs on `queue`, never on the main thread:
/// when another app reshapes the output device (Google Meet sharing a tab or screen with audio),
/// the engine can fail every render cycle, and calls that wait on the render thread then stall
/// for seconds. Off the main thread such a stall costs a missing tap sound, not a frozen pointer.
final class TapSound {
    private static let players = 4
    private static let maxFramesToRender: AUAudioFrameCount = 4096

    private let queue = DispatchQueue(label: "TinyHand tap sound", qos: .userInteractive)
    private let buffers: [TapSoundChoice: AVAudioPCMBuffer]
    private let format: AVAudioFormat

    // Touched only on `queue`.
    private var choice: TapSoundChoice
    private var engine: AVAudioEngine?
    private var nodes: [AVAudioPlayerNode] = []
    private var next = 0
    private var generation = 0
    private var configObserver: NSObjectProtocol?
    private var idleStop: DispatchWorkItem?

    /// Read and written on the main thread.
    var enabled = true

    init(_ choice: TapSoundChoice = Preferences.tapSound) {
        self.choice = choice
        var buffers: [TapSoundChoice: AVAudioPCMBuffer] = [:]
        for c in TapSoundChoice.allCases {
            if let buffer = TapSound.read(c) {
                buffers[c] = buffer
            }
        }
        self.buffers = buffers
        format = buffers.values.first?.format ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    }

    func load(_ choice: TapSoundChoice) {
        queue.async { [weak self] in
            self?.choice = choice
        }
    }

    func warm() {
        queue.async { [weak self] in
            self?.start()
        }
    }

    func play() {
        guard enabled else {
            return
        }
        queue.async { [weak self] in
            self?.playNow()
        }
    }

    private func playNow() {
        guard let buffer = buffers[choice], start(), !nodes.isEmpty else {
            return
        }
        let node = nodes[next % nodes.count]
        next += 1
        let gen = generation
        var rendered = false
        let lock = NSLock()
        node.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataRendered) { _ in
            lock.withLock { rendered = true }
        }
        if !node.isPlaying {
            node.play()
        }
        // A broken render loop never reaches the player, so the buffer is never rendered:
        // throw the engine away and build a fresh one on the next tap.
        let duration = Double(buffer.frameLength) / buffer.format.sampleRate
        queue.asyncAfter(deadline: .now() + duration + 1) { [weak self] in
            guard let self = self, gen == self.generation, !lock.withLock({ rendered }) else {
                return
            }
            Log.write("tap sound was not rendered; rebuilding the audio engine")
            self.teardown()
        }
    }

    /// Makes sure a running engine exists. Builds a fresh one rather than resuming an old one,
    /// so it picks up the output device's current buffer size. Returns false if it can't start.
    @discardableResult
    private func start() -> Bool {
        scheduleIdleStop()
        if let engine = engine, engine.isRunning {
            return true
        }
        teardown()

        let engine = AVAudioEngine()
        var nodes: [AVAudioPlayerNode] = []
        for _ in 0..<TapSound.players {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            nodes.append(node)
        }
        // Leave headroom for output devices that ask for more frames per cycle than the engine
        // sized itself for (the cause of kAudioUnitErr_TooManyFramesToProcess).
        for unit in nodes.map(\.auAudioUnit) + [engine.mainMixerNode.auAudioUnit]
        where !unit.renderResourcesAllocated && unit.maximumFramesToRender < TapSound.maxFramesToRender {
            unit.maximumFramesToRender = TapSound.maxFramesToRender
        }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            self?.queue.async {
                guard let self = self, self.engine === engine else {
                    return
                }
                Log.write("audio configuration changed; rebuilding the audio engine")
                self.teardown()
            }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            Log.write("audio engine failed to start: \(error.localizedDescription)")
            if let observer = configObserver {
                NotificationCenter.default.removeObserver(observer)
                configObserver = nil
            }
            return false
        }
        self.engine = engine
        self.nodes = nodes
        return true
    }

    private func teardown() {
        generation += 1
        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
            configObserver = nil
        }
        guard let engine = engine else {
            return
        }
        self.engine = nil
        nodes = []
        engine.stop()
    }

    private func scheduleIdleStop() {
        idleStop?.cancel()
        let stop = DispatchWorkItem { [weak self] in
            self?.teardown()
        }
        idleStop = stop
        queue.asyncAfter(deadline: .now() + 30, execute: stop)
    }

    private static func read(_ choice: TapSoundChoice) -> AVAudioPCMBuffer? {
        let name = "tap_\(choice.rawValue)"
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "wav"),
            exeDir.appendingPathComponent("\(name).wav"),
            exeDir.appendingPathComponent("assets/sounds/\(name).wav"),
            URL(fileURLWithPath: "assets/sounds/\(name).wav"),
        ].compactMap { $0 }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            guard let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                continue
            }
            if (try? file.read(into: buffer)) != nil {
                return buffer
            }
        }
        return nil
    }
}
