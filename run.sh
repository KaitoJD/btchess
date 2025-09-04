#!/bin/bash

# BTChess - Bluetooth Chess Game Launcher
# Multi-platform Flutter chess application with Bluetooth connectivity

set -e

echo "🏁 BTChess Launcher"
echo "=================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "Please install Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Set up Android environment if available
if [ -d "$HOME/Android/Sdk" ]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
    echo "✅ Android SDK configured"
fi

# Function to build for specific platform
build_platform() {
    local platform=$1
    local mode=${2:-debug}
    
    echo "� Building for $platform ($mode)..."
    
    case $platform in
        "android")
            if [ "$mode" = "release" ]; then
                flutter build apk --release
            else
                flutter build apk --debug
            fi
            echo "📱 APK built: build/app/outputs/flutter-apk/app-$mode.apk"
            ;;
        "linux")
            if [ "$mode" = "release" ]; then
                flutter build linux --release
            else
                flutter build linux --debug
            fi
            echo "🐧 Linux executable: build/linux/x64/$mode/bundle/bt_chess"
            ;;
        "ios")
            if [ "$mode" = "release" ]; then
                flutter build ios --release --no-codesign
            else
                flutter build ios --debug --no-codesign
            fi
            echo "📱 iOS app built: build/ios/iphoneos/Runner.app"
            ;;
        "macos")
            if [ "$mode" = "release" ]; then
                flutter build macos --release
            else
                flutter build macos --debug
            fi
            echo "🍎 macOS app built: build/macos/Build/Products/$mode/bt_chess.app"
            ;;
        "windows")
            if [ "$mode" = "release" ]; then
                flutter build windows --release
            else
                flutter build windows --debug
            fi
            echo "🪟 Windows executable: build/windows/x64/runner/$mode/bt_chess.exe"
            ;;
        *)
            echo "❌ Unsupported platform: $platform"
            echo "Supported platforms: android, ios, linux, macos, windows"
            return 1
            ;;
    esac
}

# Function to run the application
run_app() {
    local platform=${1:-linux}
    
    echo "🚀 Running BTChess on $platform..."
    
    case $platform in
        "linux")
            if [ ! -f "build/linux/x64/debug/bundle/bt_chess" ]; then
                echo "Building Linux version first..."
                build_platform linux debug
            fi
            ./build/linux/x64/debug/bundle/bt_chess
            ;;
        "android")
            echo "📱 Use 'flutter run' for Android development or install the APK"
            echo "APK location: build/app/outputs/flutter-apk/app-debug.apk"
            ;;
        *)
            echo "❌ Unsupported platform for running: $platform"
            return 1
            ;;
    esac
}

# Parse command line arguments
case ${1:-run} in
    "build")
        platform=${2:-linux}
        mode=${3:-debug}
        build_platform $platform $mode
        ;;
    "run")
        platform=${2:-linux}
        run_app $platform
        ;;
    "clean")
        echo "🧹 Cleaning build artifacts..."
        flutter clean
        echo "✅ Clean complete"
        ;;
    "deps")
        echo "📦 Getting dependencies..."
        flutter pub get
        echo "✅ Dependencies updated"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command] [platform] [mode]"
        echo ""
        echo "Commands:"
        echo "  run [platform]     - Run the application (default: linux)"
        echo "  build [platform] [mode] - Build for specific platform (default: linux debug)"
        echo "  clean              - Clean build artifacts"
        echo "  deps               - Get/update dependencies"
        echo "  help               - Show this help message"
        echo ""
        echo "Platforms: linux, android"
        echo "Modes: debug, release"
        echo ""
        echo "Examples:"
        echo "  $0                    # Run on Linux"
        echo "  $0 build android      # Build Android debug APK"
        echo "  $0 build linux release  # Build Linux release"
        echo "  $0 run android        # Info about running on Android"
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac