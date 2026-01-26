//
//  RootView.swift
//  EarthLord
//
//  Created by Mandy on 2026/1/9.
//

import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
///
/// 页面流程：
/// 1. 启动页 (SplashView) - 显示 Logo，检查会话状态
/// 2. 根据认证状态显示：
///    - 已登录 → 主界面 (MainTabView)
///    - 未登录 → 认证页面 (AuthView)
/// 3. 认证状态变化时自动切换页面
struct RootView: View {
    /// 认证管理器（使用 ObservedObject 以响应状态变化）
    @ObservedObject private var authManager = AuthManager.shared

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页（会检查会话状态）
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                // 已登录 → 主界面
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                // 未登录 → 认证页面
                AuthView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: splashFinished)
        .animation(.easeInOut(duration: 0.4), value: authManager.isAuthenticated)
    }
}

#Preview {
    RootView()
}
