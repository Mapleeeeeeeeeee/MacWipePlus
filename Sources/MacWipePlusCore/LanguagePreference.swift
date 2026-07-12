import Foundation

public enum AppLanguage: String, CaseIterable, Equatable {
    case english = "en"
    case traditionalChinese = "zh-Hant-TW"
}

public struct LanguagePreferenceStore {
    public static let key = "appLanguage"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var language: AppLanguage {
        get {
            guard let rawValue = defaults.string(forKey: Self.key),
                  let language = AppLanguage(rawValue: rawValue) else {
                return .english
            }
            return language
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.key)
        }
    }
}
