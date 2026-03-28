//
//  SupabaseService.swift
//  liveondesk
//

import Foundation

// MARK: - Auth State

/// Represents the current authentication state.
enum AuthState: Equatable {
    case signedOut
    case signingIn
    case signedIn(userID: String, email: String)
    case error(String)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.signedOut, .signedOut): return true
        case (.signingIn, .signingIn): return true
        case (.signedIn(let a, let b), .signedIn(let c, let d)): return a == c && b == d
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Supabase Service

/// Service layer for interacting with Supabase.
///
/// Currently implemented as a REST-based stub that performs auth
/// via Supabase's GoTrue HTTP endpoints. When the user adds the
/// `supabase-swift` package, this can be replaced with the official SDK.
///
/// Responsibilities:
/// - Email/password authentication
/// - Session persistence
/// - Sprite storage (upload/download)
/// - Cross-device config sync
@MainActor
@Observable
class SupabaseService {
    var authState: AuthState = .signedOut

    private let config: AppConfiguration

    init(config: AppConfiguration = .shared) {
        self.config = config
    }

    // MARK: - Auth

    /// Sign in with email and password via Supabase GoTrue REST API.
    func signIn(email: String, password: String) async {
        guard config.isSupabaseConfigured else {
            authState = .error("Supabase no configurado. Agrega la URL y la clave en Preferencias.")
            return
        }

        authState = .signingIn

        do {
            let url = URL(string: "\(config.supabaseURL)/auth/v1/token?grant_type=password")!

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")

            let body: [String: String] = [
                "email": email,
                "password": password
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                authState = .error("Respuesta inválida del servidor.")
                return
            }

            if httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let user = json["user"] as? [String: Any],
                   let userID = user["id"] as? String,
                   let userEmail = user["email"] as? String {
                    authState = .signedIn(userID: userID, email: userEmail)
                } else {
                    authState = .error("Respuesta inesperada del servidor.")
                }
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Error desconocido"
                authState = .error("Error \(httpResponse.statusCode): \(errorBody)")
            }
        } catch {
            authState = .error(error.localizedDescription)
        }
    }

    /// Sign up a new user.
    func signUp(email: String, password: String) async {
        guard config.isSupabaseConfigured else {
            authState = .error("Supabase no configurado.")
            return
        }

        authState = .signingIn

        do {
            let url = URL(string: "\(config.supabaseURL)/auth/v1/signup")!

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")

            let body: [String: String] = [
                "email": email,
                "password": password
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                authState = .error("Respuesta inválida.")
                return
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let user = json["user"] as? [String: Any],
                   let userID = user["id"] as? String,
                   let userEmail = user["email"] as? String {
                    authState = .signedIn(userID: userID, email: userEmail)
                } else {
                    authState = .signedIn(userID: "pending", email: email)
                }
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Error desconocido"
                authState = .error("Registro fallido: \(errorBody)")
            }
        } catch {
            authState = .error(error.localizedDescription)
        }
    }

    /// Sign out the current user.
    func signOut() {
        authState = .signedOut
    }
}
