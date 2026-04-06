import Combine
import Foundation

enum CasebaseLanguage: String, CaseIterable, Codable, Hashable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var shortDisplayName: String {
        switch self {
        case .simplifiedChinese:
            return "中文"
        case .english:
            return "EN"
        }
    }
}

enum CasebaseLanguagePreference {
    static let userDefaultsKey = "casebase.language"

    static func current(userDefaults: UserDefaults = .standard) -> CasebaseLanguage {
        guard
            let rawValue = userDefaults.string(forKey: userDefaultsKey),
            let language = CasebaseLanguage(rawValue: rawValue)
        else {
            return .simplifiedChinese
        }
        return language
    }

    static func set(_ language: CasebaseLanguage, userDefaults: UserDefaults = .standard) {
        userDefaults.set(language.rawValue, forKey: userDefaultsKey)
    }
}

final class CasebaseLanguageController: ObservableObject {
    static let shared = CasebaseLanguageController()

    @Published private(set) var language: CasebaseLanguage

    private init(userDefaults: UserDefaults = .standard) {
        language = CasebaseLanguagePreference.current(userDefaults: userDefaults)
    }

    func setLanguage(_ language: CasebaseLanguage) {
        guard self.language != language else { return }
        CasebaseLanguagePreference.set(language)
        self.language = language
    }
}
