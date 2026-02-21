#!/bin/bash
# install.sh - Installation script for BluPlan Focus extension

set -e

EXTENSION_UUID="bluplan-focus@lab_gek.github.io"
INSTALL_DIR="$HOME/.local/share/gnome-shell/extensions/$EXTENSION_UUID"

echo "Installing BluPlan Focus GNOME Shell Extension..."

# Compile schemas
echo "Compiling GSettings schemas..."
if [ -d "schemas" ]; then
    glib-compile-schemas schemas/
else
    echo "Error: schemas directory not found"
    exit 1
fi

# Create installation directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying extension files..."
cp -r ./* "$INSTALL_DIR/"

# Remove installation scripts from target
rm -f "$INSTALL_DIR/install.sh"
rm -f "$INSTALL_DIR/README.md"

echo ""
echo "Extension installed successfully!"
echo ""
echo "Next steps:"
echo "1. Restart GNOME Shell:"
echo "   - On X11: Press Alt+F2, type 'r', and press Enter"
echo "   - On Wayland: Log out and log back in"
echo ""
echo "2. Enable the extension:"
echo "   gnome-extensions enable $EXTENSION_UUID"
echo ""
echo "3. Configure the extension (optional):"
echo "   gnome-extensions prefs $EXTENSION_UUID"
echo ""
