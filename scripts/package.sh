#!/usr/bin/env bash

# 作者: mao.tao
# 说明: macOS 应用程序打包脚本，支持编译指定架构（arm64 / x86_64）并打包为 DMG 文件。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AppleReminderAI"
SCHEME_NAME="AppleReminderAI-xcode"
PROJECT_FILE="$ROOT_DIR/AppleReminderAI-xcode.xcodeproj"
ENTITLEMENTS_FILE="$ROOT_DIR/AppleReminderAI-xcode/AppleReminderAI.entitlements"

ARCH="${ARCH:-$(uname -m)}"
CONFIGURATION="${CONFIGURATION:-Release}"

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "[package] 不支持的架构: $ARCH" >&2
  exit 2
fi

if [[ ! "$CONFIGURATION" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "[package] 无效的构建配置名: $CONFIGURATION" >&2
  exit 2
fi

DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
BUILD_DIR="$ROOT_DIR/.build/${ARCH}-apple-macosx/${CONFIGURATION}"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
STAGING_DIR="$DIST_DIR/.dmg-staging-${ARCH}"
BUILD_LOG="$DIST_DIR/xcodebuild-${ARCH}.log"

# 解析版本号
resolve_version() {
  if [[ -n "${VERSION:-}" ]]; then
    printf '%s\n' "$VERSION"
    return 0
  fi

  if git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    local tag
    tag="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
    tag="${tag#v}"
    if [[ -n "$tag" ]]; then
      printf '%s\n' "$tag"
      return 0
    fi
  fi

  # 默认版本号
  printf '1.0.0\n'
}

VERSION="$(resolve_version)"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-${ARCH}.dmg"

printf '[package] 开始构建 %s %s (%s)\n' "$APP_NAME" "$VERSION" "$ARCH"

# 清理当前架构产物；CONFIGURATION_BUILD_DIR 必须由 Xcode 自行创建。
# 否则 Xcode 26 的 clean 会拒绝删除没有 CreatedByBuildSystem 标记的目录。
mkdir -p "$DIST_DIR"
rm -rf "$BUILD_DIR"

# 执行 xcodebuild 编译指定架构。
# Xcode 26 在完全禁用签名时可能在执行策略/元数据阶段返回 65。
# 使用系统提供的 Ad-Hoc 身份（-）无需证书或开发团队，同时保持产物可验证。
if ! xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME_NAME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  ARCHS="$ARCH" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION" \
  MACOSX_DEPLOYMENT_TARGET="14.0" \
  CODE_SIGN_STYLE="Manual" \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  build 2>&1 | tee "$BUILD_LOG"; then
  echo "[package] xcodebuild 构建失败，提取关键错误:" >&2
  grep -Eni "error:|fatal error:|\*\* (CLEAN|BUILD) FAILED|The following build commands failed" "$BUILD_LOG" >&2 || true
  exit 65
fi

BUILT_APP="$BUILD_DIR/AppleReminderAI-xcode.app"

if [[ ! -d "$BUILT_APP" ]]; then
  # 若默认路径不存在，自动在构建目录中寻找 .app 文件
  BUILT_APP="$(find "$BUILD_DIR" -maxdepth 1 -name "*.app" | head -n 1)"
fi

if [[ -z "$BUILT_APP" || ! -d "$BUILT_APP" ]]; then
  echo "❌ 编译产物不存在: $BUILD_DIR" >&2
  exit 1
fi

# 复制 App 到 dist 目录并重命名为统一名称
rm -rf "$APP_DIR" "$STAGING_DIR"
cp -R "$BUILT_APP" "$APP_DIR"

# 代码签名处理
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  printf '[package] 使用指定证书签名: %s\n' "$CODESIGN_IDENTITY"
  if [[ -f "$ENTITLEMENTS_FILE" ]]; then
    codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS_FILE" --sign "$CODESIGN_IDENTITY" "$APP_DIR"
  else
    codesign --force --deep --options runtime --sign "$CODESIGN_IDENTITY" "$APP_DIR"
  fi
else
  printf '[package] 执行本地 Ad-Hoc 签名\n'
  if [[ -f "$ENTITLEMENTS_FILE" ]]; then
    codesign --force --deep --entitlements "$ENTITLEMENTS_FILE" --sign - "$APP_DIR"
  else
    codesign --force --deep --sign - "$APP_DIR"
  fi
fi

codesign --verify --deep --strict "$APP_DIR"

# 准备 DMG 打包暂存目录
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

printf '[package] 正在生成 DMG 安装包: %s\n' "$(basename "$DMG_PATH")"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

# 清理暂存目录
rm -rf "$STAGING_DIR"

printf '[package] 构建完成:\n'
printf '  - App: %s\n' "$APP_DIR"
printf '  - DMG: %s\n' "$DMG_PATH"
