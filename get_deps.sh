#!/bin/bash
set -e

# Create addons directory
mkdir -p src/addons

echo "Downloading Godot XR Tools..."
curl -L -o godot-xr-tools.zip https://github.com/GodotVR/godot-xr-tools/archive/refs/heads/master.zip
unzip -q -o godot-xr-tools.zip
# Remove existing directory if it exists to avoid conflicts
rm -rf src/addons/godot-xr-tools
# Move only the addon folder to the correct location
mv godot-xr-tools-master/addons/godot-xr-tools src/addons/
rm -rf godot-xr-tools-master godot-xr-tools.zip
echo "Installed Godot XR Tools."

echo "Downloading Godot OpenXR Vendors..."
curl -L -o godot_openxr_vendors.zip https://github.com/GodotVR/godot_openxr_vendors/releases/download/3.0.0/godot_openxr_vendors_v3.0.0.zip
unzip -q -o godot_openxr_vendors.zip -d temp_vendors
rm -rf src/addons/godotopenxrvendors
mv temp_vendors/addons/godotopenxrvendors src/addons/
rm -rf temp_vendors godot_openxr_vendors.zip
echo "Installed Godot OpenXR Vendors."

echo "Downloading Pre-shipped Levels..."
mkdir -p src/Levels/a908 src/Levels/a907

# a908 - TheFatRat - Unity (ExpertPlus)
curl -sL "https://r2cdn.beatsaver.com/296946437e2194823129d88e7c457202e4c7f281.zip" -o /tmp/a908.zip
unzip -j /tmp/a908.zip ExpertPlusStandard.dat cover.jpg song.egg info.dat -d src/Levels/a908/
mv src/Levels/a908/song.egg src/Levels/a908/song.ogg
python3 scripts/patch_level_info.py src/Levels/a908/info.dat

# a907 - TheFatRat - Monody (ExpertPlus)
curl -sL "https://r2cdn.beatsaver.com/8e82872941abe8c99e9ac86d9c063fc5aee57d52.zip" -o /tmp/a907.zip
unzip -j /tmp/a907.zip ExpertPlusStandard.dat cover.jpg song.egg info.dat -d src/Levels/a907/
mv src/Levels/a907/song.egg src/Levels/a907/song.ogg
python3 scripts/patch_level_info.py src/Levels/a907/info.dat

echo "Pre-shipped levels installed (ExpertPlus only)."

echo "Dependencies installed successfully!"

