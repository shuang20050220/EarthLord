//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by Mandy on 2026/1/9.
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 是否显示登出确认弹窗
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - 用户信息卡片
                        userInfoCard

                        // MARK: - 菜单列表
                        menuSection

                        // MARK: - 登出按钮
                        logoutButton

                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.large)
        }
        // 登出确认弹窗
        .alert("确认退出", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) {}
            Button("退出登录", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("确定要退出当前账号吗？")
        }
    }

    // MARK: - 用户信息卡片
    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                // 如果有头像URL则显示头像，否则显示默认图标
                if let avatarURL = authManager.currentUser?.userMetadata["avatar_url"]?.stringValue,
                   let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 10)

            // 用户名
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 邮箱
                if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 用户ID（简短显示）
            if let userId = authManager.currentUser?.id {
                Text("ID: \(String(userId.uuidString.prefix(8)))...")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 显示名称
    private var displayName: String {
        // 优先使用 user_metadata 中的用户名
        if let username = authManager.currentUser?.userMetadata["username"]?.stringValue {
            return username
        }
        // 其次使用邮箱前缀
        if let email = authManager.currentUser?.email {
            return String(email.split(separator: "@").first ?? "幸存者")
        }
        return "幸存者"
    }

    // MARK: - 菜单列表
    private var menuSection: some View {
        VStack(spacing: 0) {
            // 账号设置
            ProfileMenuRow(icon: "gearshape.fill", title: "账号设置", color: ApocalypseTheme.info) {
                // TODO: 跳转账号设置
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            // 游戏数据
            ProfileMenuRow(icon: "chart.bar.fill", title: "游戏数据", color: ApocalypseTheme.success) {
                // TODO: 跳转游戏数据
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            // 关于我们
            ProfileMenuRow(icon: "info.circle.fill", title: "关于我们", color: ApocalypseTheme.warning) {
                // TODO: 跳转关于页面
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 登出按钮
    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.title3)
                Text("退出登录")
                    .fontWeight(.medium)
            }
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ApocalypseTheme.danger.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 菜单行组件
struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)

                Text(title)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding()
        }
    }
}

#Preview {
    ProfileTabView()
}
