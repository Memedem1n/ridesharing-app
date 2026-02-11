#!/usr/bin/env bash
set -euo pipefail

APP_ID="${1:-com.yoliva.app}"
MAIN_ACTIVITY="${2:-.MainActivity}"

echo "[smoke] Waiting for emulator device..."
adb wait-for-device

echo "[smoke] Disabling window animations for stable startup checks..."
adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true

echo "[smoke] Unlocking emulator screen..."
adb shell input keyevent 82 || true

echo "[smoke] Launching ${APP_ID}/${MAIN_ACTIVITY} ..."
adb shell am start -W -n "${APP_ID}/${MAIN_ACTIVITY}"
sleep 6

FOCUSED_WINDOW="$(adb shell dumpsys window windows | tr -d '\r' | grep -m1 'mCurrentFocus' || true)"
echo "[smoke] Focused window: ${FOCUSED_WINDOW}"

if [[ "${FOCUSED_WINDOW}" != *"${APP_ID}"* ]]; then
  echo "[smoke] ERROR: App did not reach foreground." >&2
  exit 1
fi

echo "[smoke] Android emulator launch check passed."
