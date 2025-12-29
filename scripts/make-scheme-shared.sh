#!/bin/bash
# Script to make Xcode schemes shared for CI/CD
# This script ensures that the MindSync scheme is marked as shared

set -e

PROJECT_DIR="MindSync/MindSync.xcodeproj"
SCHEME_NAME="MindSync"
SHARED_SCHEMES_DIR="${PROJECT_DIR}/xcshareddata/xcschemes"

echo "Making scheme '${SCHEME_NAME}' shared..."

# Create shared schemes directory if it doesn't exist
mkdir -p "${SHARED_SCHEMES_DIR}"

# Check if scheme already exists as shared
if [ -f "${SHARED_SCHEMES_DIR}/${SCHEME_NAME}.xcscheme" ]; then
    echo "✓ Scheme '${SCHEME_NAME}' is already shared"
    exit 0
fi

# Try to find the scheme in user data
USER_SCHEME_PATH=$(find "${PROJECT_DIR}/xcuserdata" -name "${SCHEME_NAME}.xcscheme" 2>/dev/null | head -1)

if [ -n "${USER_SCHEME_PATH}" ]; then
    echo "Found user scheme, copying to shared..."
    cp "${USER_SCHEME_PATH}" "${SHARED_SCHEMES_DIR}/${SCHEME_NAME}.xcscheme"
    echo "✓ Scheme '${SCHEME_NAME}' is now shared"
else
    echo "⚠️  Scheme not found in user data. Please mark it as shared in Xcode:"
    echo "   1. Open MindSync.xcodeproj in Xcode"
    echo "   2. Product → Scheme → Manage Schemes..."
    echo "   3. Check 'Shared' checkbox for 'MindSync' scheme"
    echo "   4. Close the dialog"
    exit 1
fi
