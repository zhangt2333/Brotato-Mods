#!/bin/bash

# Brotato Mod Packing Script
# This script packs mods into Steam Workshop format

echo "====================================="
echo "Brotato Mod Packing Script"
echo "====================================="

# Create build directory
BUILD_DIR="build"
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

# Counter for mods found
mod_count=0

# Find all directories with manifest.json
for mod_dir in */; do
    mod_name="${mod_dir%/}"
    
    # Skip build directory
    if [ "$mod_name" = "$BUILD_DIR" ]; then
        continue
    fi
    
    # Check if manifest.json exists
    if [ ! -f "$mod_dir/manifest.json" ]; then
        continue
    fi
    
    echo ""
    echo "Found mod: $mod_name"
    mod_count=$((mod_count + 1))
    
    # Create temp structure
    TEMP_DIR="$BUILD_DIR/temp_$mod_name"
    MOD_STRUCTURE="$TEMP_DIR/mods-unpacked/$mod_name"
    mkdir -p "$MOD_STRUCTURE"
    
    echo "  Packing mod files..."
    
    # Copy manifest.json
    if [ -f "$mod_dir/manifest.json" ]; then
        cp "$mod_dir/manifest.json" "$MOD_STRUCTURE/"
        echo "    + manifest.json"
    fi
    
    # Copy mod_main.gd
    if [ -f "$mod_dir/mod_main.gd" ]; then
        cp "$mod_dir/mod_main.gd" "$MOD_STRUCTURE/"
        echo "    + mod_main.gd"
    fi
    
    # Copy extensions directory
    if [ -d "$mod_dir/extensions" ]; then
        cp -r "$mod_dir/extensions" "$MOD_STRUCTURE/"
        echo "    + extensions/"
    fi
    
    # Copy other .gd files (excluding mod_main.gd which is already copied)
    for gd_file in "$mod_dir"*.gd; do
        if [ -f "$gd_file" ]; then
            filename=$(basename "$gd_file")
            if [ "$filename" != "mod_main.gd" ]; then
                cp "$gd_file" "$MOD_STRUCTURE/"
                echo "    + $filename"
            fi
        fi
    done
    
    # Copy other directories (excluding screenshots)
    for dir in "$mod_dir"*/; do
        if [ -d "$dir" ]; then
            dirname=$(basename "$dir")
            if [ "$dirname" != "screenshots" ] && [ "$dirname" != "extensions" ]; then
                cp -r "$dir" "$MOD_STRUCTURE/"
                echo "    + $dirname/"
            fi
        fi
    done
    
    # Create zip file
    ZIP_NAME="$mod_name.zip"
    echo "  Creating $ZIP_NAME..."
    
    cd "$TEMP_DIR"
    if command -v zip &> /dev/null; then
        zip -r "../$ZIP_NAME" "mods-unpacked" -q
    else
        # Fallback to PowerShell on Windows
        powershell.exe -Command "Compress-Archive -Path 'mods-unpacked' -DestinationPath '../$ZIP_NAME' -Force" 2>/dev/null
    fi
    cd - > /dev/null
    
    # Clean up temp
    rm -rf "$TEMP_DIR"
    
    echo "  ✓ Created: $BUILD_DIR/$ZIP_NAME"
done

echo ""
echo "====================================="
if [ $mod_count -gt 0 ]; then
    echo "Success! Packed $mod_count mod(s)"
    echo "Output: $BUILD_DIR/"
    echo "====================================="
    ls -lh "$BUILD_DIR"/*.zip 2>/dev/null
else
    echo "No mods found!"
    echo "Make sure directories contain manifest.json"
    echo "====================================="
fi

