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

    /// 语言管理器
    @ObservedObject private var languageManager = LanguageManager.shared

    /// 是否显示登出确认弹窗
    @State private var showLogoutAlert = false

    /// 是否显示删除账户确认弹窗
    @State private var showDeleteAccountSheet = false

    /// 删除账户确认输入文本
    @State private var deleteConfirmationText = ""

    /// 是否显示语言选择弹窗
    @State private var showLanguageSheet = false

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

                        // MARK: - 删除账户按钮
                        deleteAccountButton

                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle(Text("个人中心"))  // 使用 Text() 以支持本地化
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
        // 删除账户确认弹窗
        .sheet(isPresented: $showDeleteAccountSheet) {
            deleteAccountConfirmationSheet
        }
        // 语言选择弹窗
        .sheet(isPresented: $showLanguageSheet) {
            languageSelectionSheet
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
            // 语言设置
            LanguageMenuRow(
                icon: "globe",
                title: "语言设置",  // 直接使用字符串字面量，SwiftUI 会自动作为 LocalizedStringKey 处理
                currentLanguage: languageManager.selectedLanguage.displayName,
                color: ApocalypseTheme.primary
            ) {
                showLanguageSheet = true
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))

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

    // MARK: - 删除账户按钮
    private var deleteAccountButton: some View {
        Button {
            print("🔴 [删除账户] 点击删除账户按钮")
            deleteConfirmationText = ""  // 清空之前的输入
            showDeleteAccountSheet = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                    .font(.title3)
                Text("删除账户")
                    .fontWeight(.medium)
            }
            .foregroundColor(ApocalypseTheme.danger.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .cornerRadius(16)
        }
        .padding(.top, 8)
    }

    // MARK: - 删除账户确认弹窗
    private var deleteAccountConfirmationSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.top, 20)

                    // 警告标题
                    Text("危险操作")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.danger)

                    // 警告说明
                    VStack(spacing: 12) {
                        Text("删除账户将永久移除以下内容：")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            warningItem("您的个人资料和设置")
                            warningItem("所有游戏进度和数据")
                            warningItem("领地和兴趣点记录")
                        }
                        .padding(.horizontal)

                        Text("此操作不可撤销！")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.danger)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(16)

                    // 确认输入框
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请输入 \"删除\" 以确认")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField("请输入 删除", text: $deleteConfirmationText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)

                    // 删除按钮
                    Button {
                        print("🔴 [删除账户] 确认删除，输入内容：\(deleteConfirmationText)")
                        Task {
                            let success = await authManager.deleteAccount()
                            if success {
                                print("✅ [删除账户] 账户已成功删除")
                                showDeleteAccountSheet = false
                            } else {
                                print("❌ [删除账户] 删除失败")
                            }
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "trash.fill")
                                Text("确认删除账户")
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            deleteConfirmationText == "删除"
                                ? ApocalypseTheme.danger
                                : ApocalypseTheme.danger.opacity(0.3)
                        )
                        .cornerRadius(12)
                    }
                    .disabled(deleteConfirmationText != "删除" || authManager.isLoading)
                    .padding(.horizontal)

                    // 错误提示
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("删除账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        print("🔴 [删除账户] 用户取消删除")
                        showDeleteAccountSheet = false
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 警告项
    private func warningItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(ApocalypseTheme.danger.opacity(0.7))
            Text(text)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 语言选择弹窗
    private var languageSelectionSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    // 语言选项列表
                    VStack(spacing: 0) {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                languageManager.setLanguage(language)
                                // 延迟关闭以便用户看到选择效果
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showLanguageSheet = false
                                }
                            } label: {
                                HStack {
                                    // 语言图标
                                    Image(systemName: language == .system ? "iphone" : "globe")
                                        .font(.title3)
                                        .foregroundColor(ApocalypseTheme.primary)
                                        .frame(width: 30)

                                    // 语言名称
                                    Text(language.localizedDisplayName)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Spacer()

                                    // 选中标记
                                    if languageManager.selectedLanguage == language {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(ApocalypseTheme.success)
                                    }
                                }
                                .padding()
                                .background(
                                    languageManager.selectedLanguage == language
                                        ? ApocalypseTheme.primary.opacity(0.1)
                                        : Color.clear
                                )
                            }

                            if language != AppLanguage.allCases.last {
                                Divider()
                                    .background(ApocalypseTheme.textMuted.opacity(0.2))
                            }
                        }
                    }
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle(Text("选择语言"))  // 使用 Text() 以支持本地化
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLanguageSheet = false
                    } label: {
                        Text("取消")  // 直接使用字符串字面量
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }
}

// MARK: - 菜单行组件
struct ProfileMenuRow: View {
    let icon: String
    let title: LocalizedStringKey  // 改为 LocalizedStringKey 以支持本地化
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

// MARK: - 语言菜单行组件
struct LanguageMenuRow: View {
    let icon: String
    let title: LocalizedStringKey  // 改为 LocalizedStringKey 以支持本地化
    let currentLanguage: String
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

                // 当前语言
                Text(currentLanguage)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

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
