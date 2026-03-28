//
//  AppConfiguration.swift
//  liveondesk
//

import Foundation

/// Centralized configuration manager using UserDefaults for persistent storage.
///
/// Stores API keys and service URLs entered by the user via SettingsView.
/// In production, these would migrate to Keychain, but UserDefaults is
/// acceptable during development and for non-secret configuration.
@MainActor
@Observable
class AppConfiguration {
    static let shared = AppConfiguration()

    // MARK: - Supabase Configuration

    var supabaseURL: String {
        didSet { UserDefaults.standard.set(supabaseURL, forKey: Keys.supabaseURL) }
    }

    var supabaseAnonKey: String {
        didSet { UserDefaults.standard.set(supabaseAnonKey, forKey: Keys.supabaseAnonKey) }
    }

    var isSupabaseConfigured: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }

    // MARK: - OpenAI Configuration

    var openAIAPIKey: String {
        didSet { UserDefaults.standard.set(openAIAPIKey, forKey: Keys.openAIKey) }
    }

    var isOpenAIConfigured: Bool {
        !openAIAPIKey.isEmpty
    }

    // MARK: - Pet Profile

    var petName: String {
        didSet { UserDefaults.standard.set(petName, forKey: Keys.petName) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboardingComplete) }
    }

    // MARK: - Init

    private init() {
        self.supabaseURL     = UserDefaults.standard.string(forKey: Keys.supabaseURL) ?? ""
        self.supabaseAnonKey = UserDefaults.standard.string(forKey: Keys.supabaseAnonKey) ?? ""
        self.openAIAPIKey    = UserDefaults.standard.string(forKey: Keys.openAIKey) ?? ""
        self.petName         = UserDefaults.standard.string(forKey: Keys.petName) ?? "Mascota"
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.onboardingComplete)
    }

    // MARK: - Keys

    private enum Keys {
        static let supabaseURL      = "liveondesk.supabase.url"
        static let supabaseAnonKey  = "liveondesk.supabase.anonKey"
        static let openAIKey        = "liveondesk.openai.apiKey"
        static let petName          = "liveondesk.pet.name"
        static let onboardingComplete = "liveondesk.onboarding.complete"
    }
}
