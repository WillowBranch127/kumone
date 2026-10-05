import SwiftUI
import AppKit

struct ShortcutSettingsView: View {
    @ObservedObject var manager = ShortcutManager.shared
    
    var body: some View {
        Form {
            Section {
                ForEach(ShortcutAction.allCases) { action in
                    ShortcutRow(action: action)
                }
            } header: {
                Text("快捷键设置")
            } footer: {
                Text("点击按键进行录制，按下 Esc 键可清除快捷键。")
            }
            
            Section {
                Button("重置为默认") {
                    manager.resetToDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("快捷键")
    }
}

struct ShortcutRow: View {
    let action: ShortcutAction
    @ObservedObject var manager = ShortcutManager.shared
    @State private var isRecording = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Label(action.displayName, systemImage: action.systemImage)
            Spacer()
            Button {
                isRecording = true
                isFocused = true
            } label: {
                Text(isRecording ? String(localized: "请按下按键...") : manager.shortcut(for: action).displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(minWidth: 60)
                    .background(isRecording ? Color.accentColor : Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                    .foregroundColor(isRecording ? .white : .primary)
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            
            if isRecording {
                ShortcutRecorderView(isRecording: $isRecording) { key, modifiers in
                    manager.setShortcut(UserShortcut(key: key, modifiers: modifiers), for: action)
                }
                .frame(width: 0, height: 0)
            }
        }
        .padding(.vertical, 2)
    }
}

extension ShortcutAction {
    var systemImage: String {
        switch self {
        case .togglePlayPause: return "playpause"
        case .nextTrack: return "forward.end"
        case .previousTrack: return "backward.end"
        case .cycleQueueOrder: return "shuffle"
        case .cycleRepeatMode: return "repeat"
        case .toggleLike: return "heart"
        case .toggleLyrics: return "quote.bubble"
        case .toggleQueue: return "list.bullet"
        case .closeImmersive: return "xmark.circle"
        }
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (String, UserShortcut.ShortcutModifiers) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = RecorderNSView()
        view.onRecord = { key, modifiers in
            onRecord(key, modifiers)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
    
    class RecorderNSView: NSView {
        var onRecord: ((String, UserShortcut.ShortcutModifiers) -> Void)?
        var onCancel: (() -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { // Esc
                onRecord?("", UserShortcut.ShortcutModifiers(rawValue: 0))
                return
            }
            
            let modifiers = UserShortcut.ShortcutModifiers(nsFlags: event.modifierFlags)
            let key = event.charactersIgnoringModifiers ?? ""
            
            if !key.isEmpty {
                onRecord?(key, modifiers)
            } else {
                super.keyDown(with: event)
            }
        }
        
        override func resignFirstResponder() -> Bool {
            onCancel?()
            return super.resignFirstResponder()
        }
    }
}
