//
//  MoreTabView.swift
//  EarthLord
//
//  Created by Mandy on 2026/1/9.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                List {
                    // 开发者工具区
                    Section {
                        NavigationLink(destination: SupabaseTestView()) {
                            HStack {
                                Image(systemName: "server.rack")
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 30)
                                Text("Supabase 连接测试")
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                            }
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)
                    } header: {
                        Text("开发者工具")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MoreTabView()
}
