import SwiftUI

/// Sync Settings View - UI for CloudKit sync configuration
struct SyncSettingsView: View {
    @StateObject private var viewModel = SyncSettingsViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    
    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "icloud")
                    .font(.title2)
                    .foregroundStyle(themeColors.primary)
                
                Text("iCloud Sync")
                    .font(.headline)
                    .foregroundStyle(themeColors.text)
                
                Spacer()
                
                syncStatusBadge
            }
            
            Divider()
                .background(themeColors.secondaryText.opacity(0.3))
            
            // iCloud availability
            if !viewModel.iCloudAvailable {
                iCloudUnavailableView
            } else {
                // Sync toggle
                Toggle(isOn: Binding(
                    get: { viewModel.syncEnabled },
                    set: { newValue in
                        Task { await viewModel.toggleSync() }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sync Settings Across Devices")
                            .foregroundStyle(themeColors.text)
                        
                        Text("Sync theme, UI preferences, and game settings to other Macs")
                            .font(.caption)
                            .foregroundStyle(themeColors.secondaryText)
                    }
                }
                .toggleStyle(.switch)
                .tint(themeColors.primary)
                
                if viewModel.syncEnabled {
                    syncDetailsView
                }
            }
            
            // What syncs / doesn't sync
            whatSyncsSection
        }
        .padding()
        .background(themeColors.cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Subviews
    
    private var syncStatusBadge: some View {
        HStack(spacing: 6) {
            switch viewModel.syncState {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(themeColors.success)
                Text("Synced")
                    .font(.caption)
                    .foregroundStyle(themeColors.success)
                
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundStyle(themeColors.secondary)
                
            case .error(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(themeColors.warning)
                Text(msg.prefix(20) + "...")
                    .font(.caption)
                    .foregroundStyle(themeColors.warning)
                
            case .disabled:
                Image(systemName: "icloud.slash")
                    .foregroundStyle(themeColors.secondaryText)
                Text("Disabled")
                    .font(.caption)
                    .foregroundStyle(themeColors.secondaryText)
                
            case .noAccount:
                Image(systemName: "person.crop.circle.badge.xmark")
                    .foregroundStyle(themeColors.destructive)
                Text("No Account")
                    .font(.caption)
                    .foregroundStyle(themeColors.destructive)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(themeColors.secondaryBackground)
        .cornerRadius(8)
    }
    
    private var iCloudUnavailableView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.title3)
                    .foregroundStyle(themeColors.warning)
                
                Text("iCloud Not Available")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(themeColors.text)
            }
            
            Text("Sign in to iCloud in System Settings to sync your OpenFlux preferences across Macs.")
                .font(.caption)
                .foregroundStyle(themeColors.secondaryText)
            
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColors.primary)
        }
        .padding()
        .background(themeColors.secondaryBackground)
        .cornerRadius(8)
    }
    
    private var syncDetailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Last sync time
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(themeColors.secondaryText)
                Text(viewModel.lastSyncDescription)
                    .font(.caption)
                    .foregroundStyle(themeColors.secondaryText)
                
                Spacer()
                
                Button("Sync Now") {
                    Task { await viewModel.syncNow() }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(viewModel.syncState == .syncing)
            }
            .padding(.top, 8)
            
            // Device info
            HStack {
                Image(systemName: "laptopcomputer")
                    .foregroundStyle(themeColors.secondaryText)
                Text("This device: \(CloudKitManager.deviceName)")
                    .font(.caption)
                    .foregroundStyle(themeColors.secondaryText)
            }
        }
    }
    
    private var whatSyncsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What Syncs")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(themeColors.secondaryText)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    syncItem(icon: "checkmark.circle.fill", text: "Theme preferences", syncs: true)
                    syncItem(icon: "checkmark.circle.fill", text: "UI scale & layout", syncs: true)
                    syncItem(icon: "checkmark.circle.fill", text: "Game settings", syncs: true)
                    syncItem(icon: "checkmark.circle.fill", text: "Recent launches", syncs: true)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    syncItem(icon: "xmark.circle", text: "Wine prefixes", syncs: false)
                    syncItem(icon: "xmark.circle", text: "Game files", syncs: false)
                    syncItem(icon: "xmark.circle", text: "Log history", syncs: false)
                    syncItem(icon: "xmark.circle", text: "Credentials", syncs: false)
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func syncItem(icon: String, text: String, syncs: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(syncs ? themeColors.success : themeColors.secondaryText.opacity(0.5))
            
            Text(text)
                .font(.caption2)
                .foregroundStyle(syncs ? themeColors.text : themeColors.secondaryText.opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview {
    SyncSettingsView()
        .environmentObject(ThemeManager.shared)
        .frame(width: 400)
        .padding()
        .background(Color.black)
}
