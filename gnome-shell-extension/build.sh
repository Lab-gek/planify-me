#!/bin/bash
# build.sh - Build script for creating distributable extension package

set -e

EXTENSION_UUID="bluplan-focus@lab_gek.github.io"
BUILD_DIR="build"
PACKAGE_NAME="bluplan-focus-extension.zip"

echo "Building BluPlan Focus extension package..."

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

# Compile schemas
echo "Compiling GSettings schemas..."
glib-compile-schemas schemas/

# Copy extension files
echo "Copying extension files..."
cp extension.js "$BUILD_DIR/"
cp dbusClient.js "$BUILD_DIR/"
cp panelButton.js "$BUILD_DIR/"
cp settingsManager.js "$BUILD_DIR/"
cp prefs.js "$BUILD_DIR/"
cp metadata.json "$BUILD_DIR/"
cp stylesheet.css "$BUILD_DIR/"

# Copy schemas
mkdir -p "$BUILD_DIR/schemas"
cp schemas/*.xml "$BUILD_DIR/schemas/"
cp schemas/*.compiled "$BUILD_DIR/schemas/"

# Create package
echo "Creating package..."
cd "$BUILD_DIR"
zip -r "../$PACKAGE_NAME" ./*
cd ..

echo ""
echo "Package created: $PACKAGE_NAME"
echo ""
echo "To install:"
echo "  gnome-extensions install $PACKAGE_NAME"
echo ""
echo "Or manually extract to:"
echo "  ~/.local/share/gnome-shell/extensions/$EXTENSION_UUID"
echo ""
