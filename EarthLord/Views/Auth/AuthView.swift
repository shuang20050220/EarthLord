//
//  AuthView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/15.
//

import SwiftUI

// MARK: - 认证页面
/// 地球新主游戏的认证页面
/// 包含登录、注册、忘记密码功能
struct AuthView: View {

    // MARK: - 状态
    @StateObject private var authManager = AuthManager.shared

    /// 当前选中的Tab：0=登录，1=注册
    @State private var selectedTab: Int = 0

    /// 是否显示忘记密码弹窗
    @State private var showForgotPassword: Bool = false

    /// Toast 提示信息
    @State private var toastMessage: String?

    // MARK: - 登录表单
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""

    // MARK: - 注册表单
    @State private var registerEmail: String = ""
    @State private var registerOTP: String = ""
    @State private var registerPassword: String = ""
    @State private var registerConfirmPassword: String = ""
    @State private var registerCountdown: Int = 0
    @State private var registerTimer: Timer?

    // MARK: - 忘记密码表单
    @State private var resetEmail: String = ""
    @State private var resetOTP: String = ""
    @State private var resetPassword: String = ""
    @State private var resetConfirmPassword: String = ""
    @State private var resetCountdown: Int = 0
    @State private var resetTimer: Timer?
    @State private var resetStep: Int = 1  // 1=输入邮箱, 2=输入验证码, 3=设置新密码

    var body: some View {
        ZStack {
            // MARK: - 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.10, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.10)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Logo 和标题
                    headerView

                    // MARK: - Tab 切换
                    tabSwitcher

                    // MARK: - 内容区域
                    if selectedTab == 0 {
                        loginView
                    } else {
                        registerView
                    }

                    // MARK: - 第三方登录
                    socialLoginView

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }

            // MARK: - Loading 遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // MARK: - Toast 提示
            if let message = toastMessage {
                toastView(message: message)
            }
        }
        // MARK: - 忘记密码弹窗
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        // MARK: - 错误提示
        .onChange(of: authManager.errorMessage) { _, newValue in
            if let error = newValue {
                showToast(error)
                authManager.clearError()
            }
        }
    }

    // MARK: - 头部视图
    private var headerView: some View {
        VStack(spacing: 12) {
            // Logo
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 标题
            Text("地球新主")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text("征服世界，从这里开始")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Tab 切换器
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 0
                }
            } label: {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(selectedTab == 0 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }

            // 注册 Tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                }
            } label: {
                Text("注册")
                    .font(.headline)
                    .foregroundColor(selectedTab == 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            // 底部指示条
            GeometryReader { geometry in
                Rectangle()
                    .fill(ApocalypseTheme.primary)
                    .frame(width: geometry.size.width / 2, height: 3)
                    .offset(x: selectedTab == 0 ? 0 : geometry.size.width / 2)
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
            .frame(height: 3)
            , alignment: .bottom
        )
    }

    // MARK: - 登录视图
    private var loginView: some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入框
            AuthTextField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword,
                isSecure: true
            )

            // 登录按钮
            AuthButton(title: "登录") {
                await authManager.signIn(email: loginEmail, password: loginPassword)
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)

            // 忘记密码链接
            Button {
                resetStep = 1
                resetEmail = ""
                resetOTP = ""
                resetPassword = ""
                resetConfirmPassword = ""
                authManager.resetOTPState()
                showForgotPassword = true
            } label: {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.info)
            }
            .padding(.top, 8)
        }
        .padding(.top, 20)
    }

    // MARK: - 注册视图
    private var registerView: some View {
        VStack(spacing: 16) {
            // 根据状态显示不同步骤
            if authManager.otpVerified && authManager.needsPasswordSetup {
                // 第三步：设置密码
                registerStep3View
            } else if authManager.otpSent {
                // 第二步：验证码输入
                registerStep2View
            } else {
                // 第一步：邮箱输入
                registerStep1View
            }
        }
        .padding(.top, 20)
    }

    // MARK: - 注册第一步：输入邮箱
    private var registerStep1View: some View {
        VStack(spacing: 16) {
            // 步骤指示
            StepIndicator(currentStep: 1, totalSteps: 3)

            Text("输入您的邮箱地址")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 邮箱输入框
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            // 发送验证码按钮
            AuthButton(title: "发送验证码") {
                await authManager.sendRegisterOTP(email: registerEmail)
                if authManager.otpSent {
                    startRegisterCountdown()
                }
            }
            .disabled(registerEmail.isEmpty || !isValidEmail(registerEmail))
        }
    }

    // MARK: - 注册第二步：输入验证码
    private var registerStep2View: some View {
        VStack(spacing: 16) {
            // 步骤指示
            StepIndicator(currentStep: 2, totalSteps: 3)

            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(registerEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 验证码输入框
            OTPInputField(code: $registerOTP)

            // 验证按钮
            AuthButton(title: "验证") {
                await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
            }
            .disabled(registerOTP.count != 6)

            // 重发验证码
            HStack {
                if registerCountdown > 0 {
                    Text("\(registerCountdown)秒后可重新发送")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Button {
                        Task {
                            await authManager.sendRegisterOTP(email: registerEmail)
                            if authManager.otpSent {
                                startRegisterCountdown()
                            }
                        }
                    } label: {
                        Text("重新发送验证码")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.info)
                    }
                }
            }
        }
    }

    // MARK: - 注册第三步：设置密码
    private var registerStep3View: some View {
        VStack(spacing: 16) {
            // 步骤指示
            StepIndicator(currentStep: 3, totalSteps: 3)

            Text("设置您的密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("请设置一个安全的密码以完成注册")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 密码输入框
            AuthTextField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $registerPassword,
                isSecure: true
            )

            // 确认密码输入框
            AuthTextField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword,
                isSecure: true
            )

            // 密码匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 完成注册按钮
            AuthButton(title: "完成注册") {
                await authManager.completeRegistration(password: registerPassword)
            }
            .disabled(
                registerPassword.count < 6 ||
                registerPassword != registerConfirmPassword
            )
        }
    }

    // MARK: - 忘记密码弹窗
    private var forgotPasswordSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 根据步骤显示不同内容
                        switch resetStep {
                        case 1:
                            resetStep1View
                        case 2:
                            resetStep2View
                        case 3:
                            resetStep3View
                        default:
                            EmptyView()
                        }
                    }
                    .padding(24)
                }

                if authManager.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showForgotPassword = false
                        authManager.resetOTPState()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 重置密码第一步
    private var resetStep1View: some View {
        VStack(spacing: 16) {
            StepIndicator(currentStep: 1, totalSteps: 3)

            Text("输入您的注册邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            AuthButton(title: "发送验证码") {
                await authManager.sendResetOTP(email: resetEmail)
                if authManager.otpSent {
                    resetStep = 2
                    startResetCountdown()
                }
            }
            .disabled(resetEmail.isEmpty || !isValidEmail(resetEmail))
        }
    }

    // MARK: - 重置密码第二步
    private var resetStep2View: some View {
        VStack(spacing: 16) {
            StepIndicator(currentStep: 2, totalSteps: 3)

            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(resetEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            OTPInputField(code: $resetOTP)

            AuthButton(title: "验证") {
                await authManager.verifyResetOTP(email: resetEmail, code: resetOTP)
                if authManager.otpVerified {
                    resetStep = 3
                }
            }
            .disabled(resetOTP.count != 6)

            HStack {
                if resetCountdown > 0 {
                    Text("\(resetCountdown)秒后可重新发送")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Button {
                        Task {
                            await authManager.sendResetOTP(email: resetEmail)
                            if authManager.otpSent {
                                startResetCountdown()
                            }
                        }
                    } label: {
                        Text("重新发送验证码")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.info)
                    }
                }
            }
        }
    }

    // MARK: - 重置密码第三步
    private var resetStep3View: some View {
        VStack(spacing: 16) {
            StepIndicator(currentStep: 3, totalSteps: 3)

            Text("设置新密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            AuthTextField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $resetPassword,
                isSecure: true
            )

            AuthTextField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetConfirmPassword,
                isSecure: true
            )

            if !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            AuthButton(title: "重置密码") {
                await authManager.resetPassword(newPassword: resetPassword)
                if authManager.isAuthenticated {
                    showForgotPassword = false
                }
            }
            .disabled(
                resetPassword.count < 6 ||
                resetPassword != resetConfirmPassword
            )
        }
    }

    // MARK: - 第三方登录视图
    private var socialLoginView: some View {
        VStack(spacing: 16) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(height: 1)

                Text("或者使用以下方式登录")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .fixedSize()

                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.top, 20)

            // Apple 登录按钮
            Button {
                showToast("Apple 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("通过 Apple 登录")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }

            // Google 登录按钮
            Button {
                showToast("Google 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("通过 Google 登录")
                        .fontWeight(.medium)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Loading 遮罩
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)

                Text("请稍候...")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Toast 视图
    private func toastView(message: String) -> some View {
        VStack {
            Spacer()

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: toastMessage)
    }

    // MARK: - 辅助方法

    /// 显示 Toast
    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toastMessage = nil
        }
    }

    /// 验证邮箱格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    /// 开始注册倒计时
    private func startRegisterCountdown() {
        registerCountdown = 60
        registerTimer?.invalidate()
        registerTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if registerCountdown > 0 {
                registerCountdown -= 1
            } else {
                registerTimer?.invalidate()
            }
        }
    }

    /// 开始重置密码倒计时
    private func startResetCountdown() {
        resetCountdown = 60
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resetCountdown > 0 {
                resetCountdown -= 1
            } else {
                resetTimer?.invalidate()
            }
        }
    }
}

// MARK: - 自定义输入框组件
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    @State private var isPasswordVisible: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 24)

            if isSecure && !isPasswordVisible {
                SecureField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 自定义按钮组件
struct AuthButton: View {
    let title: String
    let action: () async -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isEnabled
                        ? LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [ApocalypseTheme.textMuted, ApocalypseTheme.textMuted],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - 步骤指示器
struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(width: 10, height: 10)

                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(width: 30, height: 2)
                }
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - OTP 输入框
struct OTPInputField: View {
    @Binding var code: String
    let length: Int = 6

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // 隐藏的输入框
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .onChange(of: code) { _, newValue in
                    // 限制长度
                    if newValue.count > length {
                        code = String(newValue.prefix(length))
                    }
                    // 只允许数字
                    code = code.filter { $0.isNumber }
                }

            // 显示的格子
            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.cardBackground)
                            .frame(width: 45, height: 55)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        index < code.count || (index == code.count && isFocused)
                                            ? ApocalypseTheme.primary
                                            : ApocalypseTheme.textMuted.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )

                        if index < code.count {
                            let charIndex = code.index(code.startIndex, offsetBy: index)
                            Text(String(code[charIndex]))
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }
                    }
                }
            }
            .onTapGesture {
                isFocused = true
            }
        }
    }
}

// MARK: - 预览
#Preview {
    AuthView()
}
