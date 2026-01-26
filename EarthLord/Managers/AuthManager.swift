//
//  AuthManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/15.
//

import Foundation
import Combine
import Supabase
import AuthenticationServices
import GoogleSignIn

// MARK: - 认证管理器
/// 地球新主游戏的认证管理器
///
/// 认证流程说明：
/// - 注册：发验证码 → 验证（此时已登录但没密码）→ 强制设置密码 → 完成
/// - 登录：邮箱 + 密码（直接登录）
/// - 找回密码：发验证码 → 验证（此时已登录）→ 设置新密码 → 完成
///
/// 重要：verifyOTP 成功后用户就已登录，但注册流程必须强制设置密码才能进入主页！
@MainActor
final class AuthManager: ObservableObject {

    // MARK: - 单例
    static let shared = AuthManager()

    // MARK: - 发布属性

    /// 是否已完成认证（已登录且完成所有流程）
    /// 只有在密码设置完成后才为 true
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP 验证后需要设置密码）
    /// 注册流程和找回密码流程中，验证码验证成功后此值为 true
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - 私有属性

    /// 当前正在进行的流程类型
    private var currentFlowType: AuthFlowType = .none

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    /// 认证流程类型
    private enum AuthFlowType {
        case none
        case register    // 注册流程
        case resetPassword  // 找回密码流程
    }

    // MARK: - 初始化
    private init() {
        // 启动认证状态监听
        startAuthStateListener()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - ==================== 认证状态监听 ====================

    /// 启动认证状态监听
    /// 监听 Supabase 的认证状态变化，自动更新 UI
    private func startAuthStateListener() {
        authStateTask = Task { [weak self] in
            // 监听认证状态变化
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self = self else { break }

                await MainActor.run {
                    self.handleAuthStateChange(event: event, session: session)
                }
            }
        }
    }

    /// 处理认证状态变化
    /// - Parameters:
    ///   - event: 认证事件类型
    ///   - session: 当前会话（可能为空）
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        print("🔔 认证状态变化: \(event)")

        switch event {
        case .initialSession:
            // 初始会话检查
            if let session = session {
                currentUser = session.user
                // 如果不是正在注册/重置密码流程中，设置为已认证
                if !needsPasswordSetup {
                    isAuthenticated = true
                    print("✅ 初始会话有效，用户已登录")
                }
            } else {
                print("ℹ️ 无初始会话")
            }

        case .signedIn:
            // 用户登录
            if let session = session {
                currentUser = session.user
                // 如果不是正在注册/重置密码流程中，设置为已认证
                if !needsPasswordSetup && currentFlowType == .none {
                    isAuthenticated = true
                    print("✅ 用户已登录")
                }
            }

        case .signedOut:
            // 用户登出
            resetState()
            print("ℹ️ 用户已登出")

        case .tokenRefreshed:
            // Token 刷新
            if let session = session {
                currentUser = session.user
                print("🔄 Token 已刷新")
            }

        case .userUpdated:
            // 用户信息更新
            if let session = session {
                currentUser = session.user
                print("👤 用户信息已更新")
            }

        case .passwordRecovery:
            // 密码恢复流程
            print("🔑 进入密码恢复流程")

        case .mfaChallengeVerified:
            // MFA 验证完成
            print("🔐 MFA 验证完成")

        @unknown default:
            print("⚠️ 未知认证事件: \(event)")
        }
    }

    // MARK: - ==================== 注册流程 ====================

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    ///
    /// 调用 supabase.auth.signInWithOTP，shouldCreateUser 为 true 表示允许创建新用户
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false
        currentFlowType = .register

        do {
            // 使用 OTP 方式发送验证码，允许创建新用户
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            print("📧 注册验证码已发送至: \(email)")

        } catch {
            errorMessage = parseAuthError(error)
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    ///
    /// 重要：验证成功后用户已登录，但 isAuthenticated 保持 false，需要设置密码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，type 为 .email 表示邮箱验证
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true  // 需要设置密码
            // 注意：isAuthenticated 保持 false，必须设置密码后才能进入主页

            print("✅ 注册验证码验证成功，用户已登录，等待设置密码")
            print("👤 用户ID: \(session.user.id)")

        } catch {
            errorMessage = parseAuthError(error)
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    ///
    /// 调用 updateUser 设置密码，成功后 isAuthenticated = true
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: password))

            // 密码设置成功，完成注册流程
            needsPasswordSetup = false
            isAuthenticated = true
            currentFlowType = .none

            print("✅ 注册完成，密码已设置")

        } catch {
            errorMessage = parseAuthError(error)
            print("❌ 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - ==================== 登录流程 ====================

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    ///
    /// 直接登录，成功后 isAuthenticated = true
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = session.user
            isAuthenticated = true

            print("✅ 登录成功")
            print("👤 用户ID: \(session.user.id)")

        } catch {
            errorMessage = parseAuthError(error)
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - ==================== 找回密码流程 ====================

    /// 发送重置密码验证码
    /// - Parameter email: 用户邮箱
    ///
    /// 调用 resetPasswordForEmail，会触发 Reset Password 邮件模板
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false
        currentFlowType = .resetPassword

        do {
            // 发送重置密码邮件
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            print("📧 重置密码验证码已发送至: \(email)")

        } catch {
            errorMessage = parseAuthError(error)
            print("❌ 发送重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证重置密码验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    ///
    /// ⚠️ 注意：type 是 .recovery 不是 .email！
    /// 验证成功后用户已登录，等待设置新密码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，⚠️ type 为 .recovery 表示密码重置验证
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery  // 重要：找回密码使用 .recovery 类型
            )

            // 验证成功，用户已登录
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true  // 需要设置新密码

            print("✅ 重置密码验证码验证成功，用户已登录，等待设置新密码")

        } catch {
            errorMessage = parseAuthError(error)
            print("❌ 验证重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    ///
    /// 调用 updateUser 设置新密码，成功后 isAuthenticated = true
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: newPassword))

            // 密码重置成功
            needsPasswordSetup = false
            isAuthenticated = true
            currentFlowType = .none

            print("✅ 密码重置成功")

        } catch {
            errorMessage = parseAuthError(error)
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - ==================== 第三方登录 ====================

    /// Apple 登录
    /// TODO: 实现 Sign in with Apple
    /// 需要配置 Apple Developer 账号和 Supabase Apple OAuth
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 ASAuthorizationAppleIDProvider 获取授权
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        // 3. 处理登录结果
        print("⚠️ Apple 登录尚未实现")
    }

    /// Google Client ID（从 Google Cloud Console 获取）
    private let googleClientID = "991972707945-33u58c8f7amka2v85ppinmpnuhhov79o.apps.googleusercontent.com"

    /// Google 登录
    /// 使用 Google Sign-In SDK 获取 ID Token，然后通过 Supabase 验证
    func signInWithGoogle() async {
        print("🔵 [Google登录] 开始 Google 登录流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 步骤1：配置 Google Sign-In
            print("🔵 [Google登录] 步骤1: 配置 Google Sign-In...")
            let config = GIDConfiguration(clientID: googleClientID)
            GIDSignIn.sharedInstance.configuration = config
            print("✅ [Google登录] Google Sign-In 配置完成，Client ID: \(googleClientID.prefix(20))...")

            // 步骤2：获取根视图控制器
            print("🔵 [Google登录] 步骤2: 获取根视图控制器...")
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("❌ [Google登录] 错误: 无法获取根视图控制器")
                errorMessage = "无法启动 Google 登录"
                isLoading = false
                return
            }
            print("✅ [Google登录] 成功获取根视图控制器")

            // 步骤3：调用 Google Sign-In
            print("🔵 [Google登录] 步骤3: 调用 Google Sign-In SDK...")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            print("✅ [Google登录] Google Sign-In 成功")
            print("🔵 [Google登录] 用户邮箱: \(result.user.profile?.email ?? "未知")")

            // 步骤4：获取 ID Token
            print("🔵 [Google登录] 步骤4: 获取 ID Token...")
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ [Google登录] 错误: 无法获取 ID Token")
                errorMessage = "Google 登录失败：无法获取凭证"
                isLoading = false
                return
            }
            print("✅ [Google登录] 成功获取 ID Token")
            print("🔵 [Google登录] ID Token 前20字符: \(String(idToken.prefix(20)))...")

            // 步骤5：获取 Access Token
            let accessToken = result.user.accessToken.tokenString
            print("✅ [Google登录] 成功获取 Access Token")

            // 步骤6：使用 Supabase 验证
            print("🔵 [Google登录] 步骤6: 使用 Supabase 验证 ID Token...")
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )

            // 登录成功
            currentUser = session.user
            isAuthenticated = true

            print("✅ [Google登录] Supabase 验证成功！")
            print("✅ [Google登录] 用户ID: \(session.user.id)")
            print("✅ [Google登录] 用户邮箱: \(session.user.email ?? "未知")")

        } catch let error as GIDSignInError {
            // Google Sign-In 特定错误
            print("❌ [Google登录] Google Sign-In 错误: \(error)")
            switch error.code {
            case .canceled:
                print("ℹ️ [Google登录] 用户取消了登录")
                errorMessage = nil  // 用户取消不显示错误
            case .hasNoAuthInKeychain:
                print("❌ [Google登录] Keychain 中没有认证信息")
                errorMessage = "请重新登录 Google 账号"
            default:
                errorMessage = "Google 登录失败: \(error.localizedDescription)"
            }
        } catch {
            print("❌ [Google登录] 登录失败: \(error)")
            errorMessage = parseAuthError(error)
        }

        isLoading = false
        print("🔵 [Google登录] 登录流程结束")
    }

    // MARK: - ==================== 其他方法 ====================

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            resetState()

            print("✅ 已登出")

        } catch {
            errorMessage = parseAuthError(error)
            print("❌ 登出失败: \(error)")
        }

        isLoading = false
    }

    /// 删除账户
    /// 调用边缘函数 delete-account 删除当前用户账户
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteAccount() async -> Bool {
        print("🔴 [删除账户] 开始删除账户流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 步骤1：获取当前会话
            print("🔴 [删除账户] 步骤1: 获取当前会话...")
            let session = try await supabase.auth.session
            print("✅ [删除账户] 成功获取会话，用户ID: \(session.user.id)")

            // 调试：打印 token 的前后部分（不打印完整 token 以保护安全）
            let token = session.accessToken
            let tokenPrefix = String(token.prefix(20))
            let tokenSuffix = String(token.suffix(20))
            print("🔴 [删除账户] Token预览: \(tokenPrefix)...\(tokenSuffix)")
            print("🔴 [删除账户] Token长度: \(token.count)")
            print("🔴 [删除账户] Token过期时间: \(session.expiresAt ?? 0)")

            // 步骤2：调用边缘函数
            print("🔴 [删除账户] 步骤2: 调用 delete-account 边缘函数...")

            // 定义响应结构
            struct DeleteResponse: Decodable {
                let success: Bool?
                let error: String?
                let message: String?
            }

            // 使用自定义解码器来处理响应，同时获取原始数据用于调试
            // 注意：边缘函数需要手动传递 Authorization header
            let deleteResponse: DeleteResponse = try await supabase.functions.invoke(
                "delete-account",
                options: .init(
                    headers: ["Authorization": "Bearer \(session.accessToken)"],
                    body: ["user_id": session.user.id.uuidString]
                ),
                decode: { data, response in
                    // 打印原始响应用于调试
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("🔴 [删除账户] 原始响应: \(jsonString)")
                    }
                    print("🔴 [删除账户] HTTP状态码: \(response.statusCode)")

                    // 解码响应
                    let decoder = JSONDecoder()
                    return try decoder.decode(DeleteResponse.self, from: data)
                }
            )

            // 步骤3：检查响应
            print("🔴 [删除账户] 步骤3: 检查响应...")
            print("🔴 [删除账户] success=\(String(describing: deleteResponse.success)), error=\(String(describing: deleteResponse.error))")

            if deleteResponse.success == true {
                print("✅ [删除账户] 账户删除成功！")

                // 步骤4：重置本地状态
                print("🔴 [删除账户] 步骤4: 重置本地状态...")
                resetState()

                isLoading = false
                return true
            } else if let error = deleteResponse.error {
                print("❌ [删除账户] 服务器返回错误: \(error)")
                errorMessage = error
                isLoading = false
                return false
            }

            // 如果 success 不为 true 且没有错误信息，也算成功
            print("✅ [删除账户] 账户删除完成")
            resetState()
            isLoading = false
            return true

        } catch let error as FunctionsError {
            // 处理 FunctionsError 类型的错误
            switch error {
            case .httpError(let code, let data):
                let responseStr = String(data: data, encoding: .utf8) ?? "无法解析"
                print("❌ [删除账户] HTTP错误 \(code): \(responseStr)")
                errorMessage = "删除失败 (HTTP \(code)): \(responseStr)"
            case .relayError:
                print("❌ [删除账户] 中继错误")
                errorMessage = "网络中继错误，请稍后重试"
            }
            isLoading = false
            return false
        } catch {
            print("❌ [删除账户] 删除失败: \(error)")
            print("❌ [删除账户] 错误类型: \(type(of: error))")
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    /// 检查会话状态
    ///
    /// 应用启动时调用，检查是否有有效的登录会话
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let session = try await supabase.auth.session
            currentUser = session.user

            // 检查用户是否设置了密码
            // 如果用户有 email_confirmed_at 且能正常获取会话，说明已完成注册
            if session.user.emailConfirmedAt != nil {
                isAuthenticated = true
                print("✅ 会话有效，用户已登录")
                print("👤 用户ID: \(session.user.id)")
            } else {
                // 邮箱未确认，可能需要完成注册流程
                needsPasswordSetup = true
                print("⚠️ 会话存在但邮箱未确认")
            }

        } catch {
            // 没有有效会话，用户未登录
            print("ℹ️ 无有效会话: \(error)")
            resetState()
        }

        isLoading = false
    }

    // MARK: - ==================== 辅助方法 ====================

    /// 重置所有状态
    func resetState() {
        isAuthenticated = false
        needsPasswordSetup = false
        currentUser = nil
        errorMessage = nil
        otpSent = false
        otpVerified = false
        currentFlowType = .none
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 重置 OTP 状态（用于重新发送验证码）
    func resetOTPState() {
        otpSent = false
        otpVerified = false
    }

    /// 解析认证错误
    /// - Parameter error: 错误对象
    /// - Returns: 用户友好的错误信息
    private func parseAuthError(_ error: Error) -> String {
        let errorString = String(describing: error)

        // 常见错误映射
        if errorString.contains("Invalid login credentials") {
            return "邮箱或密码错误"
        } else if errorString.contains("Email not confirmed") {
            return "邮箱未验证"
        } else if errorString.contains("User already registered") {
            return "该邮箱已注册"
        } else if errorString.contains("Invalid OTP") || errorString.contains("Token has expired") {
            return "验证码无效或已过期"
        } else if errorString.contains("Password should be at least") {
            return "密码长度至少为6位"
        } else if errorString.contains("network") || errorString.contains("NSURLErrorDomain") {
            return "网络连接失败，请检查网络"
        } else if errorString.contains("rate limit") {
            return "请求过于频繁，请稍后再试"
        }

        // 返回原始错误信息
        return error.localizedDescription
    }
}
