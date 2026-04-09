import AppKit
import Carbon.HIToolbox
import Foundation

struct CasebaseRuntime {
    let configuration: CasebaseConfiguration
    let knowledgeStore: KnowledgeStore
    let libraryService: LibraryService
    let importCoordinator: ImportCoordinator
    let answerService: AnswerService
    let dataResetService: DataResetService

    static func bootstrap() throws -> CasebaseRuntime {
        let configuration = try CasebaseConfiguration.load()
        let aiClient = GeminiAIClient(configuration: configuration)
        let extractor = CompositeExtractor(configuration: configuration)
        let assetVault = AssetVault(configuration: configuration.storage)
        let knowledgeStore = try LocalKnowledgeStore(configuration: configuration.storage)
        let libraryService = CasebaseLibraryService(
            configuration: configuration.storage,
            knowledgeStore: knowledgeStore
        )
        let importCoordinator = CasebaseImportCoordinator(
            extractor: extractor,
            knowledgeStore: knowledgeStore,
            aiClient: aiClient,
            assetVault: assetVault,
            maximumImportFileBytes: configuration.ai.maxImportFileBytes
        )
        let answerService = KnowledgeBackedAnswerService(
            knowledgeStore: knowledgeStore,
            aiClient: aiClient,
            configuration: configuration
        )
        let dataResetService = CasebaseDataResetService(
            knowledgeStore: knowledgeStore,
            assetVault: assetVault
        )

        return CasebaseRuntime(
            configuration: configuration,
            knowledgeStore: knowledgeStore,
            libraryService: libraryService,
            importCoordinator: importCoordinator,
            answerService: answerService,
            dataResetService: dataResetService
        )
    }
}

enum CasebaseHotKeyAction: String {
    case selectionCapture
    case screenshotCapture
}

struct CasebaseHotKeyDescriptor: Equatable, Codable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        self.init(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: Self.carbonModifiers(from: event.modifierFlags)
        )
    }

    var displayString: String {
        let modifiers = Self.modifierSymbols(for: carbonModifiers)
        return modifiers + Self.keyName(for: keyCode)
    }

    static func defaultValue(for action: CasebaseHotKeyAction) -> CasebaseHotKeyDescriptor {
        switch action {
        case .selectionCapture:
            return CasebaseHotKeyDescriptor(keyCode: UInt32(kVK_F1), carbonModifiers: UInt32(cmdKey))
        case .screenshotCapture:
            return CasebaseHotKeyDescriptor(keyCode: UInt32(kVK_F2), carbonModifiers: UInt32(cmdKey))
        }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let relevantFlags = flags.intersection([.command, .option, .control, .shift])
        var carbonModifiers: UInt32 = 0
        if relevantFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if relevantFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if relevantFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if relevantFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        return carbonModifiers
    }

    private static func modifierSymbols(for carbonModifiers: UInt32) -> String {
        var symbols = ""
        if carbonModifiers & UInt32(controlKey) != 0 { symbols += "\u{2303}" }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols += "\u{2325}" }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols += "\u{21E7}" }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols += "\u{2318}" }
        return symbols
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Forward Delete"
        case kVK_Escape: return "Escape"
        case kVK_LeftArrow: return "Left Arrow"
        case kVK_RightArrow: return "Right Arrow"
        case kVK_UpArrow: return "Up Arrow"
        case kVK_DownArrow: return "Down Arrow"
        default:
            guard let characters = keyNameFromCurrentKeyboardLayout(for: UInt16(keyCode)),
                  !characters.isEmpty else {
                return "Key \(keyCode)"
            }
            return characters.uppercased()
        }
    }

    private static func keyNameFromCurrentKeyboardLayout(for keyCode: UInt16) -> String? {
        guard let keyboardLayout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(
                  keyboardLayout,
                  kTISPropertyUnicodeKeyLayoutData
              )
        else {
            return nil
        }

        let rawLayoutData = unsafeBitCast(layoutData, to: CFData.self) as Data
        return rawLayoutData.withUnsafeBytes { pointer -> String? in
            guard let baseAddress = pointer.baseAddress else { return nil }
            let keyboardLayoutPtr = baseAddress.assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeys: UInt32 = 0
            var length = 4
            var unicodeChars = [UniChar](repeating: 0, count: length)

            let status = UCKeyTranslate(
                keyboardLayoutPtr,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeys,
                unicodeChars.count,
                &length,
                &unicodeChars
            )

            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: unicodeChars, count: length)
        }
    }
}

@MainActor
final class CasebaseHotKeyStore: ObservableObject {
    static let shared = CasebaseHotKeyStore()
    static let didChangeNotification = Notification.Name("CasebaseHotKeyStore.didChange")

    @Published private(set) var selectionCaptureShortcut: CasebaseHotKeyDescriptor
    @Published private(set) var screenshotCaptureShortcut: CasebaseHotKeyDescriptor

    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        selectionCaptureShortcut = Self.loadShortcut(for: .selectionCapture, userDefaults: userDefaults)
        screenshotCaptureShortcut = Self.loadShortcut(for: .screenshotCapture, userDefaults: userDefaults)
    }

    func shortcut(for action: CasebaseHotKeyAction) -> CasebaseHotKeyDescriptor {
        switch action {
        case .selectionCapture:
            return selectionCaptureShortcut
        case .screenshotCapture:
            return screenshotCaptureShortcut
        }
    }

    @discardableResult
    func setShortcut(_ shortcut: CasebaseHotKeyDescriptor, for action: CasebaseHotKeyAction) -> Bool {
        let otherAction: CasebaseHotKeyAction = action == .selectionCapture ? .screenshotCapture : .selectionCapture
        let existingOtherShortcut = self.shortcut(for: otherAction)
        guard shortcut != existingOtherShortcut else { return false }

        switch action {
        case .selectionCapture:
            selectionCaptureShortcut = shortcut
        case .screenshotCapture:
            screenshotCaptureShortcut = shortcut
        }

        saveShortcut(shortcut, for: action)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        return true
    }

    func resetShortcut(for action: CasebaseHotKeyAction) {
        _ = setShortcut(Self.loadDefaultShortcut(for: action), for: action)
    }

    private static func loadDefaultShortcut(for action: CasebaseHotKeyAction) -> CasebaseHotKeyDescriptor {
        CasebaseHotKeyDescriptor.defaultValue(for: action)
    }

    private static func storageKey(for action: CasebaseHotKeyAction) -> String {
        switch action {
        case .selectionCapture:
            return "casebase.shortcut.selectionCapture"
        case .screenshotCapture:
            return "casebase.shortcut.screenshotCapture"
        }
    }

    private static func loadShortcut(for action: CasebaseHotKeyAction, userDefaults: UserDefaults) -> CasebaseHotKeyDescriptor {
        let storageKey = storageKey(for: action)
        guard let rawValue = userDefaults.string(forKey: storageKey) else {
            return loadDefaultShortcut(for: action)
        }

        let parts = rawValue.split(separator: ":")
        guard parts.count == 2,
              let keyCode = UInt32(parts[0]),
              let modifiers = UInt32(parts[1]) else {
            return loadDefaultShortcut(for: action)
        }

        return CasebaseHotKeyDescriptor(keyCode: keyCode, carbonModifiers: modifiers)
    }

    private func saveShortcut(_ shortcut: CasebaseHotKeyDescriptor, for action: CasebaseHotKeyAction) {
        let value = "\(shortcut.keyCode):\(shortcut.carbonModifiers)"
        userDefaults.set(value, forKey: Self.storageKey(for: action))
    }
}
