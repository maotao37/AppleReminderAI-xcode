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
                // 顶部输入与控制区域
                VStack(spacing: 14) {
                    // 标题栏与功能操作
                    HStack(alignment: .center, spacing: 12) {
                        // 品牌图标徽章
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(MacOS27Theme.primaryGradient)
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.accentColor.opacity(0.25), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        // 标题与副标题
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.Main.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(L10n.Main.subtitle)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 设置按钮
                        Button {
                            viewModel.showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(MacOS27CircleIconButtonStyle(diameter: 30))
                        .help(L10n.Common.settings)
                    }
                    .padding(.top, 6)
                    
                    // 浮动岛式多行输入框容器
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            // 占位提示文案
                            if viewModel.inputText.isEmpty {
                                Text(L10n.Main.inputPlaceholder)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary.opacity(0.55))
                                    .padding(.top, 12)
                                    .padding(.leading, 12)
                                    .allowsHitTesting(false)
                            }
                            
                            // 核心文本编辑框
                            TextEditor(text: $viewModel.inputText)
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .lineSpacing(3)
                                .frame(height: 86)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .focused($isInputFocused)
                                .onChange(of: viewModel.inputText) {
                                    viewModel.onInputChanged()
                                }
                            
                            // 快捷执行按钮（处于高级模式且存在输入内容时展示）
                            if selectedParserMode == .openAI && !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.parsedItems.isEmpty {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        if viewModel.isParsing {
                                            // 解析中状态：允许取消
                                            Button {
                                                viewModel.cancelParsing()
                                            } label: {
                                                HStack(spacing: 5) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 11, weight: .semibold))
                                                    Text(L10n.Main.cancelParse)
                                                }
                                            }
                                            .buttonStyle(MacOS27DestructiveButtonStyle())
                                            .keyboardShortcut(.cancelAction)
                                            .padding(8)
                                            .transition(.scale.combined(with: .opacity))
                                        } else {
                                            // 就绪状态：触发解析处理
                                            Button {
                                                viewModel.startParsing()
                                            } label: {
                                                HStack(spacing: 5) {
                                                    Image(systemName: "sparkles")
                                                        .font(.system(size: 11, weight: .semibold))
                                                    Text(L10n.Main.aiParse)
                                                    
                                                    // 键盘快捷键提示小徽章
                                                    Text("⌘↩")
                                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.white.opacity(0.2))
                                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                                }
                                            }
                                            .buttonStyle(MacOS27PrimaryButtonStyle())
                                            .keyboardShortcut(.return, modifiers: [.command])
                                            .padding(8)
                                            .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                }
                                .frame(height: 86)
                            }
                        }
                        .macOS27Island(isFocused: isInputFocused, cornerRadius: 12)
                        
                        // 底部状态提示条与模式选择器
                        HStack(spacing: 10) {
                            if viewModel.isParsing {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.75)
                                    Text(L10n.Main.parsing)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Button(L10n.Main.cancel) {
                                        viewModel.cancelParsing()
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .buttonStyle(.plain)
                                    .foregroundColor(.red)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.primary.opacity(0.04)))
                            } else if let error = viewModel.errorMessage {
                                HStack(spacing: 5) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(Color(red: 0.95, green: 0.30, blue: 0.35))
                                        .font(.system(size: 11))
                                    Text(error)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(red: 0.95, green: 0.30, blue: 0.35))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.red.opacity(0.08)))
                            } else if let success = viewModel.successMessage {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(red: 0.15, green: 0.75, blue: 0.45))
                                        .font(.system(size: 11))
                                    Text(success)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(red: 0.15, green: 0.75, blue: 0.45))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.green.opacity(0.08)))
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
                            .frame(width: 170)
                            .onChange(of: selectedParserMode) { oldValue, newValue in
                                DispatchQueue.main.async {
                                    AppSettings.shared.parserMode = newValue
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .background(
                    Color(NSColor.windowBackgroundColor)
                        .opacity(0.85)
                )
                
                // 区域分割线
                Divider()
                    .opacity(0.6)
                
                // 内容区域：预览卡片列表或历史记录
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
                            onSetItemType: { type, index in
                                viewModel.setItemType(type, at: index)
                            },
                            isCreating: viewModel.isCreating,
                            creationProgress: viewModel.creationProgress,
                            reminderLists: viewModel.reminderLists,
                            calendars: viewModel.calendars,
                            selectedReminderList: $viewModel.selectedReminderList,
                            selectedCalendar: $viewModel.selectedCalendar
                        )
                        .padding(.top, 12)
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
                        .padding(.top, 12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: !viewModel.parsedItems.isEmpty)
            }
            .background(Color(NSColor.underPageBackgroundColor).opacity(0.45))
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
