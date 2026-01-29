import SwiftUI

struct PrefixesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var showCreateSheet = false
    @State private var newPrefixName = ""
    @State private var selectedPrefix: GamePrefix?
    
    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let errorMsg = appState.errorMessage, !errorMsg.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(themeColors.warning)
                    Text(errorMsg)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(themeColors.text)
                    Spacer()
                    Button(action: { appState.errorMessage = "" }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(themeColors.warning)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeColors.warning.opacity(0.1))
            }
            
            if appState.prefixes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundStyle(themeColors.secondaryText)
                    Text("No Wine prefixes")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)
                    Text("Create a prefix to run games")
                        .font(.caption)
                        .foregroundStyle(themeColors.secondaryText)
                    
                    Button(action: { showCreateSheet = true }) {
                        Label("Create Prefix", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeColors.primary)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.prefixes, selection: $selectedPrefix) { prefix in
                    PrefixRow(prefix: prefix)
                        .environmentObject(themeManager)
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(themeColors.cardBackground)
            }
            
            Divider()
                .background(themeColors.secondaryText.opacity(0.1))
            
            HStack(spacing: 12) {
                Picker("Default Launch Environment", selection: Binding(
                    get: { settingsManager.preferredLaunchEnvironment },
                    set: { settingsManager.preferredLaunchEnvironment = $0 }
                )) {
                    Text("x86").tag(ExecutionEnvironment.x86)
                    Text("Native").tag(ExecutionEnvironment.native)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Text("\(appState.prefixes.count) prefix(es)")
                    .font(.caption)
                    .foregroundStyle(themeColors.secondaryText)
                
                Spacer()
                
                if selectedPrefix != nil {
                    Button(role: .destructive, action: {
                        if let prefix = selectedPrefix {
                            appState.deletePrefix(prefix)
                            appState.log("Prefix deleted: \(prefix.name)", category: .prefixes)
                            selectedPrefix = nil
                        }
                    }) {
                        Label("Delete", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(themeColors.destructive)
                }
                
                Button(action: { showCreateSheet = true }) {
                    Label("Create", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColors.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeColors.cardBackground)
        }
        .background(themeColors.background.ignoresSafeArea())
        .sheet(isPresented: $showCreateSheet) {
            CreatePrefixSheet(isPresented: $showCreateSheet, onCreate: { name in
                appState.createPrefix(name: name)
                appState.log("New prefix created: \(name)", category: .prefixes)
            })
            .environmentObject(themeManager)
        }
    }
}

struct PrefixRow: View {
    let prefix: GamePrefix
    @EnvironmentObject var themeManager: ThemeManager
    
    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(prefix.name)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundStyle(themeColors.text)
                        
                        if prefix.isDefault {
                            Text("Default")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeColors.primary.opacity(0.2))
                                .foregroundStyle(themeColors.primary)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        if let wine = prefix.wineVersion {
                            Text("Wine: \(wine)")
                                .font(.caption)
                                .foregroundStyle(themeColors.secondaryText)
                        }
                        
                        if let gptk = prefix.gptkVersion {
                            Text("GPTK: \(gptk)")
                                .font(.caption)
                                .foregroundStyle(themeColors.secondaryText)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(prefix.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(themeColors.secondaryText)
                }
            }
            
            Text(prefix.path)
                .font(.caption)
                .foregroundStyle(themeColors.secondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }
}

struct CreatePrefixSheet: View {
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void
    @State private var name = ""
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create Wine Prefix")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prefix Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter prefix name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: {
                    onCreate(name)
                    isPresented = false
                }) {
                    Text("Create")
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400, height: 200)
    }
}

#if canImport(PreviewsMacros)
#Preview {
    PrefixesView()
        .environmentObject(AppState.shared)
}
#endif
