#!/bin/bash

echo "🔍 Checking device connection..."
flutter devices | grep CPH2613
if [ $? -ne 0 ]; then
    echo "❌ Device not found. Restarting ADB..."
    adb kill-server
    adb start-server
    sleep 2
fi

echo ""
echo "📱 Device found: CPH2613"
echo "🚀 Starting Flutter build..."
echo "⏱️  This may take 5-10 minutes on first build"
echo ""

flutter run -d 7619e6fb --verbose
