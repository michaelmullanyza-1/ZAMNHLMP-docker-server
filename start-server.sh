#!/bin/bash
set -e

DATA_DIR=/data
MOD_FOLDER="$DATA_DIR/zamnhlmp"
STEAM_APP_FILE="$DATA_DIR/steam_appid.txt"
CONFIG_FILE="$MOD_FOLDER/server.cfg"

# Backup config if it exists
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
fi

# Run SteamCMD updates
#steamcmd +force_install_dir "$DATA_DIR" +login anonymous +app_update 90 validate +quit
steamcmd +force_install_dir "$DATA_DIR" +login anonymous +app_update 3807180 validate +quit

# Restore config
if [ -f "$CONFIG_FILE.bak" ]; then
    mv "$CONFIG_FILE.bak" "$CONFIG_FILE"
fi

# Set correct AppID
echo "3416640" > "$STEAM_APP_FILE"
chmod 444 "$STEAM_APP_FILE"

# Launch HLDS with mod
exec "$DATA_DIR/hlds_run" -game zamnhlmp -port 27015 +map crossfire +maxplayers 16
