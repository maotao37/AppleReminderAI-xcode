//
//  RecurrencePickerView.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  重复周期选择器组件
//

import SwiftUI

/// 重复周期选择器
struct RecurrencePickerView: View {
    @Binding var selection: RecurrenceRule
    
    var body: some View {
        Menu {
            Picker("重复周期", selection: $selection) {
                ForEach(RecurrenceRule.allCases, id: \.self) { rule in
                    Label(rule.rawValue, systemImage: rule.icon)
                        .tag(rule)
                }
            }
        } label: {
            HStack {
                Image(systemName: selection.icon)
                    .foregroundColor(.blue)
                Text(selection.rawValue)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .fixedSize()
    }
}

#Preview {
    RecurrencePickerView(selection: .constant(.weekly))
        .padding()
}
