//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by Mandy on 2026/1/9.
//

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct EarthLordApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
            RootView()
                // 处理 Google 登录的 URL 回调
                .onOpenURL { url in
                    print("🔵 [URL回调] 收到 URL: \(url)")
                    handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// 处理传入的 URL（Google 登录回调）
    private func handleIncomingURL(_ url: URL) {
        print("🔵 [URL回调] 开始处理 URL...")
        print("🔵 [URL回调] Scheme: \(url.scheme ?? "无")")
        print("🔵 [URL回调] Host: \(url.host ?? "无")")

        // 让 Google Sign-In 处理回调
        if GIDSignIn.sharedInstance.handle(url) {
            print("✅ [URL回调] Google Sign-In 成功处理了 URL")
        } else {
            print("⚠️ [URL回调] URL 未被 Google Sign-In 处理")
        }
    }
}
