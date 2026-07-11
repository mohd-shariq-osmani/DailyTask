#!/bin/bash
set -e

ICON_SRC="/Users/shariq/Downloads/d.png"

if [ ! -f "$ICON_SRC" ]; then
    echo "Error: Source icon $ICON_SRC not found."
    exit 1
fi

echo "Creating launcher icon resource directories..."
mkdir -p app/src/main/res/mipmap-mdpi
mkdir -p app/src/main/res/mipmap-hdpi
mkdir -p app/src/main/res/mipmap-xhdpi
mkdir -p app/src/main/res/mipmap-xxhdpi
mkdir -p app/src/main/res/mipmap-xxxhdpi

echo "Resizing launcher icons using sips..."
sips -z 48 48 "$ICON_SRC" --out app/src/main/res/mipmap-mdpi/ic_launcher.png
sips -z 48 48 "$ICON_SRC" --out app/src/main/res/mipmap-mdpi/ic_launcher_round.png

sips -z 72 72 "$ICON_SRC" --out app/src/main/res/mipmap-hdpi/ic_launcher.png
sips -z 72 72 "$ICON_SRC" --out app/src/main/res/mipmap-hdpi/ic_launcher_round.png

sips -z 96 96 "$ICON_SRC" --out app/src/main/res/mipmap-xhdpi/ic_launcher.png
sips -z 96 96 "$ICON_SRC" --out app/src/main/res/mipmap-xhdpi/ic_launcher_round.png

sips -z 144 144 "$ICON_SRC" --out app/src/main/res/mipmap-xxhdpi/ic_launcher.png
sips -z 144 144 "$ICON_SRC" --out app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png

sips -z 192 192 "$ICON_SRC" --out app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
sips -z 192 192 "$ICON_SRC" --out app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png

echo "Icons generated successfully!"
