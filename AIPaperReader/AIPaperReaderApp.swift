//
//  AIPaperReaderApp.swift
//  AIPaperReader
//
//  Created by JohnnyChan on 2/4/26.
//

import SwiftUI
import SwiftData

@main
struct AIPaperReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatSession.self,
            ChatMessageModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(settings.colorScheme)
                .appLocale(settings.locale)
        }
        .commands {
            // File menu commands
            CommandGroup(replacing: .newItem) {
                Button("menu_open") {
                    NotificationCenter.default.post(name: .openDocument, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            // View menu commands
            CommandGroup(after: .toolbar) {
                Divider()

                Button("menu_zoom_in") {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("menu_zoom_out") {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("menu_actual_size") {
                    NotificationCenter.default.post(name: .zoomToFit, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("menu_find") {
                    NotificationCenter.default.post(name: .toggleSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button("menu_toggle_chat") {
                    NotificationCenter.default.post(name: .toggleChat, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
            }

            // Sidebar toggle
            SidebarCommands()
        }

        // Settings window
        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup any app-level configuration
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle opening PDF files from Finder
        guard let url = urls.first, url.pathExtension.lowercased() == "pdf" else { return }
        NotificationCenter.default.post(name: .openDocumentURL, object: url)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openDocument = Notification.Name("openDocument")
    static let openDocumentURL = Notification.Name("openDocumentURL")
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let zoomToFit = Notification.Name("zoomToFit")
    static let toggleSearch = Notification.Name("toggleSearch")
    static let toggleChat = Notification.Name("toggleChat")
}

// MARK: - View Extension
extension View {
    @ViewBuilder
    func appLocale(_ locale: Locale?) -> some View {
        if let locale = locale {
            self.environment(\.locale, locale)
        } else {
            self
        }
    }
}
