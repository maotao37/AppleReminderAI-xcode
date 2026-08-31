# 本地打包与 GitHub Release 自动构建指南

本项目支持在本地一键打包，以及在 GitHub 发布 Release 时自动构建 macOS 的 **Apple Silicon (arm64)** 和 **Intel (x86_64)** 双架构安装包。

---

## 1. 本地打包

在本地 macOS 机器上，可以通过终端命令快速打包出 `.app` 和 `.dmg` 文件。

### 方式一：使用 Makefile（推荐）

```bash
# 1. 查看所有可用指令
make help

# 2. 打包当前机器架构的 DMG（默认版本 1.0.0）
make package

# 3. 指定版本号打包当前架构
make package VERSION=1.2.0

# 4. 指定打包 Apple Silicon (arm64) 架构
make package-arm64 VERSION=1.2.0

# 5. 指定打包 Intel (x86_64) 架构
make package-x86_64 VERSION=1.2.0

# 6. 同时打包两个架构的 DMG
make package-all VERSION=1.2.0

# 7. 清理构建产物
make clean
```

### 方式二：直接执行脚本

```bash
# 打包当前架构
./scripts/package.sh

# 指定架构与版本号
ARCH=arm64 VERSION=1.2.0 ./scripts/package.sh
ARCH=x86_64 VERSION=1.2.0 ./scripts/package.sh
```

打包完成后，产物将存放在工程根目录的 `dist/` 下：
- `dist/AppleReminderAI.app`（macOS 应用程序）
- `dist/AppleReminderAI-1.2.0-arm64.dmg`（Apple Silicon 安装镜像）
- `dist/AppleReminderAI-1.2.0-x86_64.dmg`（Intel 安装镜像）

---

## 2. GitHub Release 自动构建与发布

### 触发方式

流水线（`.github/workflows/release.yml`）支持以下三种触发方式：

1. **在 GitHub 网页发布 Release**：
   - 进入 GitHub 仓库页面 -> 点击右侧 **Releases** -> 点击 **Draft a new release**；
   - 填写 Tag（如 `v1.0.0`）并点击 **Publish release**；
   - GitHub Actions 将自动开始编译 `arm64` 和 `x86_64` 两个架构的 DMG 并附加到该 Release 附件中。

2. **本地推送 Git Tag**：
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   推送后会自动触发构建并自动创建对应的 GitHub Release。

3. **Actions 页面手动触发 (workflow_dispatch)**：
   - 进入 GitHub 仓库 -> 点击 **Actions** -> 选择 **Release** 工作流 -> 点击 **Run workflow**，输入版本号即可。

---

## 3. GitHub 仓库权限配置

为确保 GitHub Actions 有权限创建 Release 并上传附件，请确认以下设置：

1. 打开 GitHub 仓库，进入 **Settings** -> **Actions** -> **General**。
2. 找到 **Workflow permissions** 区域。
3. 勾选 **Read and write permissions**。
4. 点击 **Save** 保存。
