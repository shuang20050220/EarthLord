//
//  TestView.swift
//  EarthLord
//
//  Created by Mandy on 2026/1/9.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color(red: 0.68, green: 0.85, blue: 0.9)
                .ignoresSafeArea()

            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    TestView()
}
