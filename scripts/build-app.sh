#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
APP_NAME="MOV to MP4.app"
EXECUTABLE_NAME="MOVtoMP4"
OUTPUT_DIRECTORY="${PROJECT_DIRECTORY}/dist"
APP_BUNDLE="${OUTPUT_DIRECTORY}/${APP_NAME}"
STAGING_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/mov-to-mp4-build.XXXXXX")"

cleanup() {
    rm -rf "${STAGING_DIRECTORY}"
}
trap cleanup EXIT

cd "${PROJECT_DIRECTORY}"
swift build -c release --product "${EXECUTABLE_NAME}"
BIN_DIRECTORY="$(swift build -c release --show-bin-path)"

mkdir -p "${STAGING_DIRECTORY}/${APP_NAME}/Contents/MacOS"
mkdir -p "${STAGING_DIRECTORY}/${APP_NAME}/Contents/Resources"
cp "${BIN_DIRECTORY}/${EXECUTABLE_NAME}" "${STAGING_DIRECTORY}/${APP_NAME}/Contents/MacOS/${EXECUTABLE_NAME}"
cp "${PROJECT_DIRECTORY}/Resources/Info.plist" "${STAGING_DIRECTORY}/${APP_NAME}/Contents/Info.plist"

codesign --force --sign - "${STAGING_DIRECTORY}/${APP_NAME}"

mkdir -p "${OUTPUT_DIRECTORY}"
rm -rf "${APP_BUNDLE}"
mv "${STAGING_DIRECTORY}/${APP_NAME}" "${APP_BUNDLE}"

echo "Built: ${APP_BUNDLE}"
