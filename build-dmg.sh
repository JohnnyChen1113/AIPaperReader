#!/bin/bash

# AIPaperReader 一键打包脚本
# 用法: ./build-dmg.sh

set -e

# 配置
APP_NAME="AIPaperReader"
SCHEME="AIPaperReader"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
DMG_DIR="${BUILD_DIR}/dmg-contents"
OUTPUT_DIR="${PROJECT_DIR}/dist"
DMG_NAME="${APP_NAME}-v1.1.0.dmg"

echo "🔨 开始构建 ${APP_NAME}..."
echo "项目目录: ${PROJECT_DIR}"

# 清理旧的构建
echo "🧹 清理旧的构建文件..."
rm -rf "${BUILD_DIR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${OUTPUT_DIR}"

# 构建 Release 版本
echo "📦 构建 Release 版本..."
xcodebuild -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    -destination "generic/platform=macOS" \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | grep -E "(Build |Compiling|Linking|error:|warning:|\*\*)" || true

# 查找生成的 .app
APP_PATH=$(find "${BUILD_DIR}" -name "${APP_NAME}.app" -type d | head -1)

if [ -z "${APP_PATH}" ]; then
    echo "❌ 错误: 找不到构建的 ${APP_NAME}.app"
    exit 1
fi

echo "✅ 构建成功: ${APP_PATH}"

# 创建 DMG 内容目录
echo "📁 准备 DMG 内容..."
mkdir -p "${DMG_DIR}"
cp -R "${APP_PATH}" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

# 创建 DMG
echo "💿 创建 DMG 文件..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov \
    -format UDZO \
    "${OUTPUT_DIR}/${DMG_NAME}"

# 清理临时文件
echo "🧹 清理临时文件..."
rm -rf "${BUILD_DIR}"

# 完成
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)

echo ""
echo "=========================================="
echo "✅ 打包完成!"
echo "=========================================="
echo "DMG 文件: ${DMG_PATH}"
echo "文件大小: ${DMG_SIZE}"
echo ""
echo "双击 DMG 文件，将 ${APP_NAME} 拖到 Applications 文件夹即可安装"
echo ""

# 在 Finder 中显示
open -R "${DMG_PATH}"
