#!/bin/zsh
# 念日 iOS —— 不安装模拟器，直接构建设备 IPA
#
# 无签名 IPA（需要 Sideloadly / AltStore 用自己的 Apple ID 签名后才能安装）：
#   zsh scripts/build-ipa.sh
#
# 已签名 IPA（需要 Apple Developer Team，Xcode 会自动处理开发签名）：
#   TEAM_ID=你的TeamID zsh scripts/build-ipa.sh
#
# 产物：
#   NianRi-1.2.0-unsigned.ipa
#   NianRi-1.2.0-signed.ipa
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 xcodegen。先执行：brew install xcodegen"
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild 不可用。请安装完整 Xcode，并执行 sudo xcodebuild -license accept"
  exit 1
fi

echo "==> 生成 Xcode 工程"
xcodegen generate

rm -rf build
BUILD_ARGS=(
  -project NianRi.xcodeproj
  -scheme NianRi
  -configuration Release
  -destination "generic/platform=iOS"
  -derivedDataPath build
)

if [[ -n "${TEAM_ID:-}" ]]; then
  echo "==> 构建已签名设备包（Team: $TEAM_ID）"
  xcodebuild "${BUILD_ARGS[@]}" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates \
    build
  SUFFIX="signed"
else
  echo "==> 构建无签名设备包"
  xcodebuild "${BUILD_ARGS[@]}" CODE_SIGNING_ALLOWED=NO build
  SUFFIX="unsigned"
fi

APP="build/Build/Products/Release-iphoneos/NianRi.app"
if [[ ! -d "$APP" ]]; then
  echo "没有找到构建产物：$APP"
  exit 1
fi

PAYLOAD="build/Payload"
rm -rf "$PAYLOAD"
mkdir -p "$PAYLOAD"
cp -R "$APP" "$PAYLOAD/NianRi.app"

IPA="NianRi-1.2.0-$SUFFIX.ipa"
rm -f "$IPA"
(cd build && zip -qry "../$IPA" Payload)

echo "==> 完成：$ROOT/$IPA"
if [[ "$SUFFIX" == "unsigned" ]]; then
  echo "无签名 IPA 不能直接双击安装；可用 Sideloadly / AltStore 用自己的 Apple ID 签名后安装。"
else
  echo "已签名 IPA 可用 Apple Configurator 安装；也可以连接 iPhone 后用："
  echo "  xcrun devicectl device install app --device <设备ID> \"$APP\""
fi
