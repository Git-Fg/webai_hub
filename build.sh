#!/bin/bash

# WebAI Hub Build Script
# This script helps set up and build the project

set -e  # Exit on error

echo "🚀 WebAI Hub Build Script"
echo "=========================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "Please install Flutter from https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"

# Step 1: Get dependencies
echo ""
echo "📦 Step 1: Installing dependencies..."
flutter pub get

# Step 2: Run code generation
echo ""
echo "⚙️  Step 2: Running code generation (build_runner)..."
echo "This will generate Isar schemas and other generated files..."
flutter pub run build_runner build --delete-conflicting-outputs

# Step 3: Analyze code
echo ""
echo "🔍 Step 3: Analyzing code..."
flutter analyze || echo "⚠️  Warning: Some analysis issues found"

# Done
echo ""
echo "✅ Build preparation complete!"
echo ""
echo "Next steps:"
echo "  - To run on Android: flutter run -d android"
echo "  - To run on iOS: flutter run -d ios"
echo "  - To build APK: flutter build apk"
echo "  - To build iOS: flutter build ios"
echo ""
echo "For more information, see BUILD_GUIDE.md"
