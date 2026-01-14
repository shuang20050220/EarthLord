//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by Mandy on 2026/1/14.
//

import SwiftUI
import Supabase

// MARK: - Supabase 客户端初始化
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://rgekiyaidqvnjhdtltlb.supabase.co")!,
    supabaseKey: "sb_publishable_zZ_gG1MZ8e4_KVeZhPRK5w_io0HfhTH"
)

struct SupabaseTestView: View {
    // MARK: - State
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var debugLog: String = "点击按钮开始测试连接..."

    enum ConnectionStatus {
        case idle
        case testing
        case success
        case failure
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 标题
                Text("Supabase 连接测试")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 状态图标
                statusIcon
                    .frame(width: 80, height: 80)

                // 调试日志
                ScrollView {
                    Text(debugLog)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 200)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)

                // 测试按钮
                Button(action: testConnection) {
                    HStack {
                        if connectionStatus == .testing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(connectionStatus == .testing ? "测试中..." : "测试连接")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(connectionStatus == .testing)

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - 状态图标
    @ViewBuilder
    private var statusIcon: some View {
        switch connectionStatus {
        case .idle:
            Image(systemName: "cloud.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)
        case .testing:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(2)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.success)
        case .failure:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.danger)
        }
    }

    // MARK: - 测试连接
    private func testConnection() {
        connectionStatus = .testing
        debugLog = "[\(timestamp)] 开始测试连接...\n"
        debugLog += "[\(timestamp)] URL: https://rgekiyaidqvnjhdtltlb.supabase.co\n"
        debugLog += "[\(timestamp)] 正在查询测试表...\n"

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                let _: [EmptyRow] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（理论上不会发生）
                await MainActor.run {
                    debugLog += "[\(timestamp)] 查询成功（意外情况）\n"
                    connectionStatus = .success
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }

    // MARK: - 错误处理
    private func handleError(_ error: Error) {
        let errorString = String(describing: error)
        debugLog += "[\(timestamp)] 收到响应，正在分析...\n"
        debugLog += "[\(timestamp)] 错误信息: \(errorString)\n\n"

        // 判断连接状态
        if errorString.contains("PGRST") || errorString.contains("Could not find") {
            // PostgreSQL REST API 错误，说明服务器已响应
            debugLog += "[\(timestamp)] ✅ 连接成功（服务器已响应）\n"
            debugLog += "[\(timestamp)] 服务器返回了 PostgreSQL 错误，\n"
            debugLog += "[\(timestamp)] 说明网络连接正常，Supabase 服务可用。\n"
            connectionStatus = .success
        } else if errorString.contains("relation") && errorString.contains("does not exist") {
            // 表不存在错误，也说明连接成功
            debugLog += "[\(timestamp)] ✅ 连接成功（服务器已响应）\n"
            debugLog += "[\(timestamp)] 数据库返回"表不存在"错误，\n"
            debugLog += "[\(timestamp)] 说明已成功连接到 Supabase 数据库。\n"
            connectionStatus = .success
        } else if errorString.contains("hostname") ||
                  errorString.contains("URL") ||
                  errorString.contains("NSURLErrorDomain") ||
                  errorString.contains("Could not connect") {
            // 网络或 URL 错误
            debugLog += "[\(timestamp)] ❌ 连接失败：URL 错误或无网络\n"
            debugLog += "[\(timestamp)] 请检查：\n"
            debugLog += "[\(timestamp)] 1. 网络连接是否正常\n"
            debugLog += "[\(timestamp)] 2. Supabase URL 是否正确\n"
            connectionStatus = .failure
        } else {
            // 其他错误
            debugLog += "[\(timestamp)] ⚠️ 未知错误\n"
            debugLog += "[\(timestamp)] 错误详情: \(error.localizedDescription)\n"
            connectionStatus = .failure
        }
    }

    // MARK: - 时间戳
    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - 空行模型（用于解码）
private struct EmptyRow: Decodable {}

#Preview {
    SupabaseTestView()
}
