#!/bin/bash
set -e

DATA_DIR=/data
MOD_FOLDER="$DATA_DIR/zamnhlmp"
STEAM_APP_FILE="$DATA_DIR/steam_appid.txt"
CONFIG_FILE="$MOD_FOLDER/server.cfg"
LIBLIST_FILE="$MOD_FOLDER/liblist.gam"
METAMOD_PLUGINS_FILE="$MOD_FOLDER/addons/metamod/plugins.ini"

# Backup config if it exists
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
fi

# Backup liblist if it exists
if [ -f "$LIBLIST_FILE" ]; then
    cp "$LIBLIST_FILE" "$LIBLIST_FILE.bak"
fi

# Backup plugins if it exists
if [ -f "$METAMOD_PLUGINS_FILE" ]; then
    cp "$METAMOD_PLUGINS_FILE" "$METAMOD_PLUGINS_FILE.bak"
fi

# Run SteamCMD updates
#steamcmd +force_install_dir "$DATA_DIR" +login anonymous +app_update 90 validate +quit
steamcmd +force_install_dir "$DATA_DIR" +login anonymous +app_update 3807180 validate +quit

# Restore config
if [ -f "$CONFIG_FILE.bak" ]; then
    mv "$CONFIG_FILE.bak" "$CONFIG_FILE"
fi

# Restore liblist
if [ -f "$LIBLIST_FILE.bak" ]; then
    mv "$LIBLIST_FILE.bak" "$LIBLIST_FILE"
fi

# Restore PLUGINS
if [ -f "$METAMOD_PLUGINS_FILE.bak" ]; then
    mv "$METAMOD_PLUGINS_FILE.bak" "$METAMOD_PLUGINS_FILE"
fi

# Set correct AppID
echo "3416640" > "$STEAM_APP_FILE"
chmod 444 "$STEAM_APP_FILE"

# Launch HLDS with mod
export LD_LIBRARY_PATH="$DATA_DIR:$LD_LIBRARY_PATH"
exec "$DATA_DIR/hlds_run" -game zamnhlmp -port 27015 +map crossfire +maxplayers 16 +mp_timelimit 25
