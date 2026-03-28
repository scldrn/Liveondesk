//
//  SettingsView.swift
//  liveondesk
//

import SwiftUI

struct SettingsView: View {
    @Binding var showOnboarding: Bool
    @Environment(\.openWindow) private var openWindow

    @State private var config = AppConfiguration.shared
    @State private var supabase = SupabaseService()

    // Auth form state
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var isSignUp = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            apiKeysTab
                .tabItem { Label("API Keys", systemImage: "key") }

            accountTab
                .tabItem { Label("Cuenta", systemImage: "person.circle") }
        }
        .frame(width: 480, height: 380)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("LiveOnDesk")
                    .font(.title2.bold())
            }

            Divider()

            HStack {
                Text("Nombre de la mascota")
                Spacer()
                TextField("Nombre", text: $config.petName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }

            Divider()

            Button(action: { openWindow(id: "onboarding") }) {
                Label("Configurar mascota desde foto", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)

            Spacer()

            HStack {
                Spacer()
                Text("v0.1.0 — Fase de desarrollo")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(20)
    }

    // MARK: - API Keys Tab

    private var apiKeysTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claves de API")
                .font(.title3.bold())

            Text("Configura las credenciales para los servicios en la nube. Estas claves se guardan localmente en tu Mac.")
                .font(.callout)
                .foregroundColor(.secondary)

            Divider()

            // OpenAI
            GroupBox(label: Label("OpenAI (Pensamientos con IA)", systemImage: "brain")) {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("API Key (sk-...)", text: $config.openAIAPIKey)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Circle()
                            .fill(config.isOpenAIConfigured ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(config.isOpenAIConfigured ? "Configurado" : "Sin configurar — se usarán frases estáticas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Supabase
            GroupBox(label: Label("Supabase (Auth & Storage)", systemImage: "cloud")) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("URL del proyecto (https://xxx.supabase.co)", text: $config.supabaseURL)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Anon Key", text: $config.supabaseAnonKey)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Circle()
                            .fill(config.isSupabaseConfigured ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(config.isSupabaseConfigured ? "Configurado" : "Sin configurar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Account Tab

    private var accountTab: some View {
        VStack(spacing: 16) {
            switch supabase.authState {
            case .signedOut:
                signedOutView
            case .signingIn:
                ProgressView("Conectando...")
                    .padding()
            case .signedIn(_, let email):
                signedInView(email: email)
            case .error(let message):
                signedOutView
                Text(message)
                    .font(.callout)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .padding(20)
    }

    private var signedOutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(isSignUp ? "Crear cuenta" : "Iniciar sesión")
                .font(.title3.bold())

            if !config.isSupabaseConfigured {
                Text("Configura Supabase en la pestaña 'API Keys' primero.")
                    .font(.callout)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }

            TextField("Email", text: $authEmail)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            SecureField("Contraseña", text: $authPassword)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            Button(action: {
                Task {
                    if isSignUp {
                        await supabase.signUp(email: authEmail, password: authPassword)
                    } else {
                        await supabase.signIn(email: authEmail, password: authPassword)
                    }
                }
            }) {
                Text(isSignUp ? "Registrarse" : "Entrar")
                    .frame(maxWidth: 260)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!config.isSupabaseConfigured || authEmail.isEmpty || authPassword.isEmpty)

            Button(isSignUp ? "¿Ya tienes cuenta? Inicia sesión" : "¿No tienes cuenta? Regístrate") {
                isSignUp.toggle()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private func signedInView(email: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Sesión activa")
                .font(.title3.bold())

            Text(email)
                .font(.callout)
                .foregroundColor(.secondary)

            Button("Cerrar sesión") {
                supabase.signOut()
            }
            .buttonStyle(.bordered)
        }
    }
}
