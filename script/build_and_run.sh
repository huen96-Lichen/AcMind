#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"

APP_NAME="AcMind"
SCHEME="AcMind"
PROJECT="AcMind.xcodeproj"
BUNDLE_ID="com.acmind.app"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/run"
DERIVED_DATA="/private/tmp/AcMindDerivedData"
BUILD_DIR="$BUILD_ROOT/Debug"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

stop_existing_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
  mkdir -p "$BUILD_DIR"

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="-" \
    build
}

launch_binary() {
  nohup "$APP_BINARY" >/dev/null 2>&1 &
}

wait_for_launch() {
  local attempts=40
  while (( attempts > 0 )); do
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
    attempts=$((attempts - 1))
  done

  return 1
}

stream_logs() {
  local predicate="$1"
  /usr/bin/log stream --info --style compact --predicate "$predicate"
}

stop_existing_app
build_app

case "$MODE" in
  run)
    launch_binary
    wait_for_launch
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    launch_binary
    wait_for_launch
    stream_logs "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    launch_binary
    wait_for_launch
    stream_logs "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    launch_binary
    wait_for_launch
    ;;
  *)
    usage
    exit 2
    ;;
esac
