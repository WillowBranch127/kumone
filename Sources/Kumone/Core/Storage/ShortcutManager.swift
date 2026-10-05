import SwiftUI
import AppKit

public struct UserShortcut: Codable, Equatable {
    public var key: String
    public var modifiers: ShortcutModifiers

    public struct ShortcutModifiers: OptionSet, Codable, Equatable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = ShortcutModifiers(rawValue: 1 << 0)
        public static let shift   = ShortcutModifiers(rawValue: 1 << 1)
        public static let option  = ShortcutModifiers(rawValue: 1 << 2)
        public static let control = ShortcutModifiers(rawValue: 1 << 3)

        public var eventModifiers: EventModifiers {
            var flags: EventModifiers = []
            if contains(.command) { flags.insert(.command) }
            if contains(.shift) { flags.insert(.shift) }
            if contains(.option) { flags.insert(.option) }
            if contains(.control) { flags.insert(.control) }
            return flags
        }

        public var nsModifierFlags: NSEvent.ModifierFlags {
            var flags: NSEvent.ModifierFlags = []
            if contains(.command) { flags.insert(.command) }
            if contains(.shift) { flags.insert(.shift) }
            if contains(.option) { flags.insert(.option) }
            if contains(.control) { flags.insert(.control) }
            return flags
        }

        public init(nsFlags: NSEvent.ModifierFlags) {
            var flags: ShortcutModifiers = []
            if nsFlags.contains(.command) { flags.insert(.command) }
            if nsFlags.contains(.shift) { flags.insert(.shift) }
            if nsFlags.contains(.option) { flags.insert(.option) }
            if nsFlags.contains(.control) { flags.insert(.control) }
            self = flags
        }
    }

    public var keyboardShortcut: KeyboardShortcut? {
        guard !key.isEmpty else { return nil }
        return KeyboardShortcut(KeyEquivalent(Character(key)), modifiers: modifiers.eventModifiers)
    }

    public var displayString: String {
        if key.isEmpty { return String(localized: "无") }
        var str = ""
        if modifiers.contains(.control) { str += "⌃" }
        if modifiers.contains(.option) { str += "⌥" }
        if modifiers.contains(.shift) { str += "⇧" }
        if modifiers.contains(.command) { str += "⌘" }
        
        switch key {
        case " ": str += "Space"
        case "\u{F703}": str += "→"
        case "\u{F702}": str += "←"
        case "\u{F700}": str += "↑"
        case "\u{F701}": str += "↓"
        case "\u{1B}": str += "⎋"
        case "\u{F704}": str += "F1"
        case "\u{F705}": str += "F2"
        case "\u{F706}": str += "F3"
        case "\u{F707}": str += "F4"
        case "\u{F708}": str += "F5"
        case "\u{F709}": str += "F6"
        case "\u{F70A}": str += "F7"
        case "\u{F70B}": str += "F8"
        case "\u{F70C}": str += "F9"
        case "\u{F70D}": str += "F10"
        case "\u{F70E}": str += "F11"
        case "\u{F70F}": str += "F12"
        case "\r": str += "↩"
        case "\u{7F}": str += "⌫"
        default: str += key.uppercased()
        }
        return str
    }
}

public enum ShortcutAction: String, CaseIterable, Identifiable {
    case togglePlayPause
    case nextTrack
    case previousTrack
    case cycleQueueOrder
    case cycleRepeatMode
    case toggleLike
    case toggleLyrics
    case toggleQueue
    case closeImmersive

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .togglePlayPause: return String(localized: "播放 / 暂停")
        case .nextTrack: return String(localized: "下一首")
        case .previousTrack: return String(localized: "上一首")
        case .cycleQueueOrder: return String(localized: "切换播放顺序")
        case .cycleRepeatMode: return String(localized: "切换循环模式")
        case .toggleLike: return String(localized: "喜欢 / 取消喜欢")
        case .toggleLyrics: return String(localized: "切换歌词面板")
        case .toggleQueue: return String(localized: "切换播放队列")
        case .closeImmersive: return String(localized: "关闭沉浸播放页")
        }
    }

    public var defaultShortcut: UserShortcut {
        switch self {
        case .togglePlayPause: return UserShortcut(key: " ", modifiers: [])
        case .nextTrack: return UserShortcut(key: "\u{F703}", modifiers: [.command])
        case .previousTrack: return UserShortcut(key: "\u{F702}", modifiers: [.command])
        case .cycleQueueOrder: return UserShortcut(key: "s", modifiers: [.command, .shift])
        case .cycleRepeatMode: return UserShortcut(key: "r", modifiers: [.command, .shift])
        case .toggleLike: return UserShortcut(key: "l", modifiers: [.command, .shift])
        case .toggleLyrics: return UserShortcut(key: "l", modifiers: [.command])
        case .toggleQueue: return UserShortcut(key: "u", modifiers: [.command])
        case .closeImmersive: return UserShortcut(key: "\u{1B}", modifiers: [])
        }
    }
}

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    @Published var shortcuts: [ShortcutAction: UserShortcut] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let prefix = "settings.shortcut."
    
    private init() {
        loadShortcuts()
    }
    
    private func loadShortcuts() {
        var loaded: [ShortcutAction: UserShortcut] = [:]
        for action in ShortcutAction.allCases {
            if let data = userDefaults.data(forKey: prefix + action.rawValue),
               let shortcut = try? JSONDecoder().decode(UserShortcut.self, from: data) {
                loaded[action] = shortcut
            } else {
                loaded[action] = action.defaultShortcut
            }
        }
        self.shortcuts = loaded
    }
    
    func setShortcut(_ shortcut: UserShortcut, for action: ShortcutAction) {
        shortcuts[action] = shortcut
        if let data = try? JSONEncoder().encode(shortcut) {
            userDefaults.set(data, forKey: prefix + action.rawValue)
        }
        // Force UI update for anyone observing us
        objectWillChange.send()
    }
    
    func resetToDefaults() {
        for action in ShortcutAction.allCases {
            setShortcut(action.defaultShortcut, for: action)
        }
    }
    
    func shortcut(for action: ShortcutAction) -> UserShortcut {
        shortcuts[action] ?? action.defaultShortcut
    }
    
    // MARK: - Key Event Matching
    
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        let currentModifiers = UserShortcut.ShortcutModifiers(nsFlags: event.modifierFlags)
        
        // We handle some keys only if not editing text
        let editingText = NSApp.keyWindow?.firstResponder is NSText
            || NSApp.keyWindow?.firstResponder is NSTextView
        
        // Match against registered shortcuts
        for (action, shortcut) in shortcuts {
            // Some shortcuts (like Space) should only work if not editing text
            // Others (like Cmd-Right) can work globally
            if editingText {
                // If editing text, only allow command-based shortcuts
                if shortcut.modifiers.isEmpty || (!shortcut.modifiers.contains(.command) && !shortcut.modifiers.contains(.control)) {
                    continue
                }
            }
            
            if event.charactersIgnoringModifiers == shortcut.key && currentModifiers == shortcut.modifiers {
                executeAction(action)
                return true
            }
        }
        
        return false
    }
    
    private func executeAction(_ action: ShortcutAction) {
        Task { @MainActor in
            let player = PlayerService.shared
            switch action {
            case .togglePlayPause:
                player.togglePlayPause()
            case .nextTrack:
                player.next()
            case .previousTrack:
                player.previous()
            case .cycleQueueOrder:
                player.cycleQueueOrder()
            case .cycleRepeatMode:
                player.cycleRepeatMode()
            case .toggleLike:
                if let track = player.currentTrack {
                    await AccountStore.shared.toggleLike(trackID: track.id)
                }
            case .toggleLyrics:
                player.activePanel = player.activePanel == .lyrics ? nil : .lyrics
            case .toggleQueue:
                player.activePanel = player.activePanel == .queue ? nil : .queue
            case .closeImmersive:
                if player.showNowPlaying {
                    player.showNowPlaying = false
                }
            }
        }
    }
}
