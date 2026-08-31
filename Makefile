# 作者: mao.tao
# 说明: 本地构建与打包任务管理

.PHONY: all build package package-arm64 package-x86_64 package-all clean help

VERSION ?= 1.0.0

# 默认展示帮助信息
all: help

help:
	@echo "可用命令列表:"
	@echo "  make build               - 本地快速构建项目"
	@echo "  make package             - 打包当前机器架构的 DMG 安装包"
	@echo "  make package-arm64       - 打包 Apple Silicon (arm64) 架构的 DMG"
	@echo "  make package-x86_64      - 打包 Intel (x86_64) 架构的 DMG"
	@echo "  make package-all         - 同时打包 arm64 与 x86_64 架构的 DMG"
	@echo "  make clean               - 清理构建产物与临时文件"

# 本地快速构建
build:
	xcodebuild -project AppleReminderAI-xcode.xcodeproj -scheme AppleReminderAI-xcode -configuration Release build

# 打包当前架构的 DMG
package:
	VERSION=$(VERSION) ./scripts/package.sh

# 打包 arm64 架构
package-arm64:
	ARCH=arm64 VERSION=$(VERSION) ./scripts/package.sh

# 打包 x86_64 架构
package-x86_64:
	ARCH=x86_64 VERSION=$(VERSION) ./scripts/package.sh

# 同时打包两个架构的 DMG
package-all: package-arm64 package-x86_64

# 清理产物
clean:
	rm -rf dist .build
