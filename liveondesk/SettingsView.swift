//
//  SettingsView.swift
//  liveondesk
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("LiveOnDesk Preferences")
                .font(.headline)
            
            Text("Más opciones llegarán en futuras versiones.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(minWidth: 300, minHeight: 200)
    }
}

#Preview {
    SettingsView()
}
