#!/bin/zsh
# 念日 iOS —— 终端构建 / 启动模拟器
# 用法：
#   zsh scripts/run-simulator.sh
#   zsh scripts/run-simulator.sh "iPhone 15"
#   TEAM_ID=你的TeamID zsh scripts/run-simulator.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVICE="${1:-iPhone 16}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 xcodegen。先执行：brew install xcodegen"
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild 不可用。请安装完整 Xcode，并执行 sudo xcodebuild -license accept"
  exit 1
fi

if ! xcrun simctl list devices available | grep -q "$DEVICE ("; then
  echo "没有找到模拟器：$DEVICE"
  echo "可用模拟器："
  xcrun simctl list devices available
  exit 1
fi

echo "==> 生成 Xcode 工程"
xcodegen generate

echo "==> 启动模拟器：$DEVICE"
xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
open -a Simulator
xcrun simctl bootstatus "$DEVICE" -b

echo "==> 清理旧构建"
rm -rf .build

BUILD_ARGS=(
  -project NianRi.xcodeproj
  -scheme NianRi
  -configuration Debug
  -destination "platform=iOS Simulator,name=$DEVICE"
  -derivedDataPath .build
)

echo "==> xcodebuild"
if [[ -n "${TEAM_ID:-}" ]]; then
  xcodebuild "${BUILD_ARGS[@]}" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates \
    build
else
  # 模拟器通常可以使用 ad hoc 签名；如果本机签名环境不完整，
  # 自动退回无签名构建（App 可运行；锁屏组件可能没有共享数据）。
  if ! xcodebuild "${BUILD_ARGS[@]}" build; then
    echo "==> 签名构建失败，尝试无签名模拟器构建"
    xcodebuild "${BUILD_ARGS[@]}" CODE_SIGNING_ALLOWED=NO build
  fi
fi

APP=".build/Build/Products/Debug-iphonesimulator/NianRi.app"
if [[ ! -d "$APP" ]]; then
  echo "没有找到构建产物：$APP"
  exit 1
fi

echo "==> 安装和启动"
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.nianri.app

mkdir -p screenshots
xcrun simctl io "$DEVICE" screenshot screenshots/launch.png >/dev/null
echo "==> 完成"
echo "截图：$ROOT/screenshots/launch.png"
echo "查看日志：xcrun simctl spawn \"$DEVICE\" log stream --predicate 'process == \"NianRi\"'"
echo "添加锁屏小组件：在 Simulator 中长按锁屏 → 自定义 → 添加组件 → 搜索「念日」"
