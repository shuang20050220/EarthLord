//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/27.
//

import Foundation
import SwiftUI
import Combine

// MARK: - 语言选项枚举
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case zhHans = "zh-Hans"     // 简体中文
    case en = "en"              // English

    var id: String { rawValue }

    /// 显示名称（用于 Text 直接显示）
    /// 注意：简体中文和English始终显示为原生名称
    var displayName: String {
        switch self {
        case .system:
            // 返回中文，让 SwiftUI 的 LocalizedStringKey 处理翻译
            return "跟随系统"
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }

    /// 本地化显示名称（用于需要 LocalizedStringKey 的场景）
    var localizedDisplayName: LocalizedStringKey {
        switch self {
        case .system:
            return "跟随系统"
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }

    /// 获取对应的 Locale
    func locale(systemLocale: Locale = .current) -> Locale {
        switch self {
        case .system:
            return systemLocale
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .en:
            return Locale(identifier: "en")
        }
    }
}

// MARK: - 语言管理器
/// 管理 App 内语言切换
/// 支持跟随系统、简体中文、英文三种选项
@MainActor
final class LanguageManager: ObservableObject {

    // MARK: - 单例
    static let shared = LanguageManager()

    // MARK: - 存储 Key
    private let languageKey = "app_language_preference"

    // MARK: - 发布属性

    /// 当前选择的语言选项
    @Published var selectedLanguage: AppLanguage {
        didSet {
            // 保存到 UserDefaults
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: languageKey)
            print("🌐 [语言管理] 语言已切换为: \(selectedLanguage.displayName)")
        }
    }

    /// 当前应用的 Locale
    var currentLocale: Locale {
        selectedLanguage.locale()
    }

    // MARK: - 初始化
    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedValue = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedValue) {
            self.selectedLanguage = language
            print("🌐 [语言管理] 已恢复语言设置: \(language.displayName)")
        } else {
            // 默认跟随系统
            self.selectedLanguage = .system
            print("🌐 [语言管理] 使用默认设置: 跟随系统")
        }
    }

    // MARK: - 公共方法

    /// 切换语言
    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
    }

    /// 获取当前语言代码（用于调试）
    var currentLanguageCode: String {
        switch selectedLanguage {
        case .system:
            return Locale.current.language.languageCode?.identifier ?? "unknown"
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        }
    }
}

// MARK: - 环境值扩展
private struct AppLocaleKey: EnvironmentKey {
    static let defaultValue: Locale = .current
}

extension EnvironmentValues {
    var appLocale: Locale {
        get { self[AppLocaleKey.self] }
        set { self[AppLocaleKey.self] = newValue }
    }
}

// MARK: - View 扩展
extension View {
    /// 应用当前语言设置
    func applyAppLanguage(_ languageManager: LanguageManager) -> some View {
        self.environment(\.locale, languageManager.currentLocale)
    }
}
