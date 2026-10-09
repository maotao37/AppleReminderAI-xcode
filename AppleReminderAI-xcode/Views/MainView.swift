//
//  MainView.swift
//  AppleReminderAI
//
//  Created by mao.tao
//  主界面视图
//

import SwiftUI

/// 主界面
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @FocusState private var isInputFocused: Bool
    
    /// 使用 @State 存储解析模式，避免直接绑定到 @Published 属性导致的循环更新
    @State private var selectedParserMode: ParserMode = AppSettings.shared.parserMode
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部输入区域
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Main.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(L10n.Main.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 设置按钮
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                viewModel.showSettings = true
                            }
                            .help(L10n.Common.settings)
                    }
                    .padding(.top, 8)
                    
                    // 输入框
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            if viewModel.inputText.isEmpty {
                                Text(L10n.Main.inputPlaceholder)
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.top, 12)
                                    .padding(.leading, 12)
                                    .font(.body)
                            }
                            
                            TextEditor(text: $viewModel.inputText)
                                .font(.body)
                                .frame(height: 80)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                                .focused($isInputFocused)
                                .onChange(of: viewModel.inputText) {
                                    viewModel.onInputChanged()
                                }
                            
                            // AI 解析按钮 (仅在 AI 模式下且输入不为空时显示)
                            if selectedParserMode == .openAI && !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.parsedItems.isEmpty {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        if viewModel.isParsing {
                                            // 解析中显示取消按钮（Esc），慢网络不必干等超时
                                            Button {
                                                viewModel.cancelParsing()
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "xmark.circle")
                                                    Text(L10n.Main.cancelParse)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.red)
                                                .foregroundColor(.white)
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .keyboardShortcut(.cancelAction)
                                            .padding(8)
                                            .transition(.scale.combined(with: .opacity))
                                        } else {
                                            Button {
                                                viewModel.startParsing()
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "sparkles")
                                                    Text(L10n.Main.aiParse)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .keyboardShortcut(.return, modifiers: [.command])
                                            .padding(8)
                                            .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                }
                                .frame(height: 80) // 与 TextEditor 高度一致
                            }
                        }
                        
                        // 状态提示
                        HStack {
                            if viewModel.isParsing {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.8)
                                Text(L10n.Main.parsing)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button(L10n.Main.cancel) {
                                    viewModel.cancelParsing()
                                }
                                .font(.caption)
                                .buttonStyle(PlainButtonStyle())
                                .foregroundColor(.red)
                            } else if let error = viewModel.errorMessage {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                            } else if viewModel.successMessage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(viewModel.successMessage ?? "")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            // 解析模式选择器
                            Picker("", selection: $selectedParserMode) {
                                ForEach(ParserMode.allCases, id: \.self) { mode in
                                    Label(mode.rawValue, systemImage: mode.icon)
                                        .tag(mode)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 180)
                            .onChange(of: selectedParserMode) { oldValue, newValue in
                                // 延迟更新 AppSettings 以避免在视图更新期间修改状态
                                DispatchQueue.main.async {
                                    AppSettings.shared.parserMode = newValue
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                // 内容区域：预览或历史记录
                ZStack {
                    if !viewModel.parsedItems.isEmpty {
                        // 显示解析结果列表
                        ParsedItemsListView(
                            items: $viewModel.parsedItems,
                            onCreateItem: { index in
                                Task { await viewModel.createItem(at: index) }
                            },
                            onCreateAll: {
                                Task { await viewModel.createAllItems() }
                            },
                            onRemoveItem: { index in
                                viewModel.removeItem(at: index)
                            },
                            onUpdateItem: { item, index in
                                viewModel.updateParsedItem(item, at: index)
                            },
                            isCreating: viewModel.isCreating,
                            creationProgress: viewModel.creationProgress,
                            reminderLists: viewModel.reminderLists,
                            calendars: viewModel.calendars,
                            selectedReminderList: $viewModel.selectedReminderList,
                            selectedCalendar: $viewModel.selectedCalendar
                        )
                        .padding(.top)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // 显示历史记录
                        HistoryView(
                            history: viewModel.history,
                            loadWarning: viewModel.historyLoadWarning,
                            onClear: { viewModel.clearHistory() },
                            onRetry: { viewModel.retryHistoryItem(id: $0) },
                            onUndo: { id in
                                Task { await viewModel.undoHistoryItem(id: id) }
                            }
                        )
                        .padding(.top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(), value: !viewModel.parsedItems.isEmpty)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .sheet(isPresented: $viewModel.showSettings, onDismiss: {
                viewModel.loadAvailableLists()
            }) {
                SettingsView()
            }
            .onAppear {
                isInputFocused = true
                viewModel.loadAvailableLists()
            }
        }
    }
}

#Preview {
    MainView()
}
