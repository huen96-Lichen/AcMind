#!/bin/bash
set -euo pipefail

# =============================================================================
# AcMind Native Build Script
# =============================================================================
#
# 用途：Swift 原生构建、签名、公证、打包为 DMG
# 前置：Xcode 15+, macOS 14+, Developer ID 证书（发布时）
#
# 用法：
#   ./scripts/build.sh                  # Debug 构建
#   ./scripts/build.sh --release        # Release 构建
#   ./scripts/build.sh --release --sign # Release + 代码签名
#   ./scripts/build.sh --release --package # Release + 签名 + DMG 打包
#   ./scripts/build.sh --release --notarize # Release + 签名 + 公证 + DMG
#   ./scripts/build.sh --clean          # 清理构建产物
#
# 环境变量：
#   DEVELOPER_ID         - Developer ID Application 证书名称
#   APPLE_ID             - Apple ID（公证用）
#   TEAM_ID              - Team ID（公证用）
#   APP_SPECIFIC_PASSWORD - App 专用密码（公证用）
#   OUTPUT_DIR           - 输出目录（默认：./build）
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
APP_NAME="AcMind"
SCHEME="AcMind"
PROJECT="AcMind.xcodeproj"
BUNDLE_ID="com.acore.acmind"
HELPER_NAME="com.acmind.systemstatus.helper"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_DIR/build}"

# 解析参数
CONFIGURATION="Debug"
DO_SIGN=false
DO_PACKAGE=false
DO_NOTARIZE=false
DO_CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            CONFIGURATION="Release"
            shift
            ;;
        --sign)
            DO_SIGN=true
            shift
            ;;
        --package)
            DO_SIGN=true
            DO_PACKAGE=true
            shift
            ;;
        --notarize)
            DO_SIGN=true
            DO_PACKAGE=true
            DO_NOTARIZE=true
            shift
            ;;
        --clean)
            DO_CLEAN=true
            shift
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            echo "用法: $0 [--release] [--sign] [--package] [--notarize] [--clean]"
            exit 1
            ;;
    esac
done

cd "$PROJECT_DIR"

# =============================================================================
# 清理
# =============================================================================
if [ "$DO_CLEAN" = true ]; then
    echo -e "${BLUE}🧹 清理构建产物...${NC}"
    rm -rf "$OUTPUT_DIR"
    rm -rf "$PROJECT_DIR/.build"
    rm -rf "$PROJECT_DIR/DerivedData"
    echo -e "${GREEN}✅ 清理完成${NC}"
    exit 0
fi

# =============================================================================
# 前置检查
# =============================================================================
echo -e "${BLUE}🔍 前置检查...${NC}"

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ xcodebuild 未安装，请安装 Xcode${NC}"
    exit 1
fi

if ! command -v swift &> /dev/null; then
    echo -e "${RED}❌ swift 未安装，请安装 Xcode Command Line Tools${NC}"
    exit 1
fi

if ! command -v codesign &> /dev/null; then
    echo -e "${RED}❌ codesign 未找到${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Xcode 工具链就绪${NC}"

# =============================================================================
# 解析 Swift 依赖
# =============================================================================
echo -e "${BLUE}📦 解析 Swift 依赖...${NC}"
swift package resolve
echo -e "${GREEN}✅ 依赖解析完成${NC}"

echo -e "${BLUE}🧩 构建 system status helper...${NC}"
HELPER_SWIFT_CONFIGURATION="$(printf '%s' "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')"
swift build -c "$HELPER_SWIFT_CONFIGURATION" --product AcMindSystemStatusHelper
echo -e "${GREEN}✅ helper 构建完成${NC}"

# =============================================================================
# 构建
# =============================================================================
echo -e "${BLUE}🔨 构建 $APP_NAME ($CONFIGURATION)...${NC}"

BUILD_DIR="$OUTPUT_DIR/$CONFIGURATION"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$OUTPUT_DIR/DerivedData" \
    build \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | tail -20

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ 构建失败：未找到 $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 构建完成: $APP_PATH${NC}"

# =============================================================================
# 注入 helper 二进制
# =============================================================================
echo -e "${BLUE}🧷 注入 helper 到 App Bundle...${NC}"
HELPER_BUILD_DIR="$PROJECT_DIR/.build/$([[ "$CONFIGURATION" == "Release" ]] && echo "release" || echo "debug")"
HELPER_BINARY="$HELPER_BUILD_DIR/AcMindSystemStatusHelper"
HELPER_DEST_DIR="$APP_PATH/Contents/Library/LaunchServices"
HELPER_DEST="$HELPER_DEST_DIR/$HELPER_NAME"

if [ ! -f "$HELPER_BINARY" ]; then
    echo -e "${RED}❌ helper 二进制未找到: $HELPER_BINARY${NC}"
    exit 1
fi

mkdir -p "$HELPER_DEST_DIR"
cp -f "$HELPER_BINARY" "$HELPER_DEST"
chmod 755 "$HELPER_DEST"
echo -e "${GREEN}✅ helper 已注入: $HELPER_DEST${NC}"

# =============================================================================
# 复制 Info.plist
# =============================================================================
echo -e "${BLUE}📄 复制 Info.plist...${NC}"
cp -f "$PROJECT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
echo -e "${GREEN}✅ Info.plist 已复制${NC}"

# =============================================================================
# 代码签名
# =============================================================================
if [ "$DO_SIGN" = true ]; then
    echo -e "${BLUE}🔐 代码签名...${NC}"

    # 查找 Developer ID 证书
    if [ -z "${DEVELOPER_ID:-}" ]; then
        DEVELOPER_ID=$(security find-identity -v -p codesigning | \
            grep "Developer ID Application" | \
            head -1 | \
            sed 's/.*"\(.*\)".*/\1/')
    fi

    if [ -z "$DEVELOPER_ID" ]; then
        echo -e "${YELLOW}⚠️ 未找到 Developer ID 证书，使用 ad-hoc 签名${NC}"
        DEVELOPER_ID="-"
    fi

    echo "   证书: $DEVELOPER_ID"

    # 移除旧签名
    xattr -cr "$APP_PATH" 2>/dev/null || true

    # 签名
    codesign \
        --sign "$DEVELOPER_ID" \
        --options runtime \
        --deep \
        --force \
        --timestamp \
        --entitlements "$PROJECT_DIR/AcMind.entitlements" \
        "$APP_PATH"

    # 验证签名
    codesign --verify --deep --strict "$APP_PATH" 2>&1
    echo -e "${GREEN}✅ 签名完成${NC}"
fi

# =============================================================================
# DMG 打包
# =============================================================================
if [ "$DO_PACKAGE" = true ]; then
    echo -e "${BLUE}📦 打包 DMG...${NC}"

    DMG_DIR="$OUTPUT_DIR/dmg"
    DMG_PATH="$OUTPUT_DIR/$APP_NAME.dmg"
    STAGING_DIR="$DMG_DIR/staging"

    rm -rf "$DMG_DIR"
    mkdir -p "$STAGING_DIR"

    # 复制 App 到 staging
    cp -R "$APP_PATH" "$STAGING_DIR/"

    # 创建 Applications 符号链接
    ln -s /Applications "$STAGING_DIR/Applications"

    # 创建 DMG
    rm -f "$DMG_PATH"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDZO \
        "$DMG_PATH"

    echo -e "${GREEN}✅ DMG 已创建: $DMG_PATH${NC}"
fi

# =============================================================================
# 公证
# =============================================================================
if [ "$DO_NOTARIZE" = true ]; then
    echo -e "${BLUE}📋 提交公证...${NC}"

    if [ -z "${APPLE_ID:-}" ] || [ -z "${TEAM_ID:-}" ] || [ -z "${APP_SPECIFIC_PASSWORD:-}" ]; then
        echo -e "${YELLOW}⚠️ 缺少公证环境变量 (APPLE_ID, TEAM_ID, APP_SPECIFIC_PASSWORD)，跳过公证${NC}"
    else
        # 提交公证
        xcrun notarytool submit \
            "$DMG_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_SPECIFIC_PASSWORD" \
            --wait

        # 装订票据
        xcrun stapler staple "$DMG_PATH"

        echo -e "${GREEN}✅ 公证完成${NC}"
    fi
fi

# =============================================================================
# 摘要
# =============================================================================
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🎉 构建完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo "   配置:    $CONFIGURATION"
echo "   App:     $APP_PATH"
if [ "$DO_PACKAGE" = true ]; then
    echo "   DMG:     $DMG_PATH"
fi
if [ "$DO_SIGN" = true ]; then
    echo "   签名:    $DEVELOPER_ID"
fi
echo -e "${BLUE}========================================${NC}"
