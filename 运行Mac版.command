#!/bin/zsh
set -euo pipefail

项目目录=${0:A:h}
XCODE路径="/Applications/Xcode.app/Contents/Developer"

if [[ ! -d "$XCODE路径" ]]; then
  echo "没有找到完整的 Xcode，请先从 App Store 安装 Xcode。"
  read -k 1 "?按任意键关闭..."
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "没有找到 XcodeGen。请先在终端执行：brew install xcodegen"
  read -k 1 "?按任意键关闭..."
  exit 1
fi

cd "$项目目录"
export DEVELOPER_DIR="$XCODE路径"

echo "正在生成心塔工程..."
xcodegen generate

echo "正在构建 Mac 版..."
xcodebuild \
  -project SoulTower.xcodeproj \
  -scheme SoulTower \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "正在打开心塔..."
open "$项目目录/DerivedData/Build/Products/Debug/心塔.app"

echo "完成。可以关闭此窗口。"
