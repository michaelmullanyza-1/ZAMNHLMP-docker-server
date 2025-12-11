#!/bin/bash
set -e

echo "=== Script starting: HLDS setup and launch ==="
echo "Current working directory: $(pwd)"
echo "Initializing variables..."

DATA_DIR=/data
MOD_FOLDER="$DATA_DIR/zamnhlmp"
STEAM_APP_FILE="$DATA_DIR/steam_appid.txt"
CONFIG_FILE="$MOD_FOLDER/server.cfg"
LIBLIST_FILE="$MOD_FOLDER/liblist.gam"
METAMOD_PLUGINS_FILE="$MOD_FOLDER/addons/metamod/plugins.ini"
METAMOD_DLL_FILE="$MOD_FOLDER/addons/metamod/dlls/metamod.so"
USERNAME="example@website.com"
PASSWORD="password"

echo "Variables set:"
echo "  DATA_DIR=$DATA_DIR"
echo "  MOD_FOLDER=$MOD_FOLDER"
echo "  STEAM_APP_FILE=$STEAM_APP_FILE"
echo "  CONFIG_FILE=$CONFIG_FILE"
echo "  LIBLIST_FILE=$LIBLIST_FILE"
echo "  METAMOD_PLUGINS_FILE=$METAMOD_PLUGINS_FILE"
echo "  METAMOD_DLL_FILE=$METAMOD_DLL_FILE"
echo "=== Starting backup phase ==="

# Backup config if it exists
echo "Checking for CONFIG_FILE..."
if [ -f "$CONFIG_FILE" ]; then
    echo "CONFIG_FILE exists, backing up to $CONFIG_FILE.bak"
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    echo "Backup complete: CONFIG_FILE"
else
    echo "CONFIG_FILE not found, skipping backup"
fi

# Backup liblist if it exists
echo "Checking for LIBLIST_FILE..."
if [ -f "$LIBLIST_FILE" ]; then
    echo "LIBLIST_FILE exists, backing up to $LIBLIST_FILE.bak"
    cp "$LIBLIST_FILE" "$LIBLIST_FILE.bak"
    echo "Backup complete: LIBLIST_FILE"
else
    echo "LIBLIST_FILE not found, skipping backup"
fi

# Backup plugins if it exists
echo "Checking for METAMOD_PLUGINS_FILE..."
if [ -f "$METAMOD_PLUGINS_FILE" ]; then
    echo "METAMOD_PLUGINS_FILE exists, backing up to $METAMOD_PLUGINS_FILE.bak"
    cp "$METAMOD_PLUGINS_FILE" "$METAMOD_PLUGINS_FILE.bak"
    echo "Backup complete: METAMOD_PLUGINS_FILE"
else
    echo "METAMOD_PLUGINS_FILE not found, skipping backup"
fi

# Backup DLL if it exists
echo "Checking for METAMOD_DLL_FILE..."
if [ -f "$METAMOD_DLL_FILE" ]; then
    echo "METAMOD_DLL_FILE exists, backing up to $METAMOD_DLL_FILE.bak"
    cp "$METAMOD_DLL_FILE" "$METAMOD_DLL_FILE.bak"
    echo "Backup complete: METAMOD_DLL_FILE"
else
    echo "METAMOD_DLL_FILE not found, skipping backup"
fi

echo "=== Backup phase complete ==="
echo "=== Starting SteamCMD update phase ==="

# Run SteamCMD updates
echo "Running SteamCMD update for app 3807180..."
steamcmd +force_install_dir "$DATA_DIR" +login $USERNAME $PASSWORD +app_update 3807180 validate +quit
echo "SteamCMD update for app 3807180 complete."

echo "Running SteamCMD update for app 3416640..."
steamcmd +force_install_dir "$DATA_DIR" +login $USERNAME $PASSWORD +app_update 3416640 validate +quit
echo "SteamCMD update for app 3416640 complete."

echo "=== SteamCMD update phase complete ==="
echo "=== Starting restore phase ==="

# Restore config
echo "Checking for CONFIG_FILE.bak..."
if [ -f "$CONFIG_FILE.bak" ]; then
    echo "Restoring CONFIG_FILE from backup"
    mv "$CONFIG_FILE.bak" "$CONFIG_FILE"
    echo "Restore complete: CONFIG_FILE"
else
    echo "No CONFIG_FILE.bak found, skipping restore"
fi

# Restore liblist
echo "Checking for LIBLIST_FILE.bak..."
if [ -f "$LIBLIST_FILE.bak" ]; then
    echo "Restoring LIBLIST_FILE from backup"
    mv "$LIBLIST_FILE.bak" "$LIBLIST_FILE"
    echo "Restore complete: LIBLIST_FILE"
else
    echo "No LIBLIST_FILE.bak found, skipping restore"
fi

# Restore PLUGINS
echo "Checking for METAMOD_PLUGINS_FILE.bak..."
if [ -f "$METAMOD_PLUGINS_FILE.bak" ]; then
    echo "Restoring METAMOD_PLUGINS_FILE from backup"
    mv "$METAMOD_PLUGINS_FILE.bak" "$METAMOD_PLUGINS_FILE"
    echo "Restore complete: METAMOD_PLUGINS_FILE"
else
    echo "No METAMOD_PLUGINS_FILE.bak found, skipping restore"
fi

# Restore DLL
echo "Checking for METAMOD_DLL_FILE.bak..."
if [ -f "$METAMOD_DLL_FILE.bak" ]; then
    echo "Restoring METAMOD_DLL_FILE from backup"
    mv "$METAMOD_DLL_FILE.bak" "$METAMOD_DLL_FILE"
    echo "Restore complete: METAMOD_DLL_FILE"
else
    echo "No METAMOD_DLL_FILE.bak found, skipping restore"
fi

echo "=== Restore phase complete ==="
echo "=== Setting AppID ==="

# Set correct AppID
echo "Writing AppID 3416640 to $STEAM_APP_FILE"
echo "3416640" > "$STEAM_APP_FILE"
chmod 444 "$STEAM_APP_FILE"
echo "AppID written and permissions set."

echo "=== Preparing to launch HLDS ==="

# Launch HLDS with mod
echo "Exporting LD_LIBRARY_PATH with DATA_DIR included"
export LD_LIBRARY_PATH="$DATA_DIR:$LD_LIBRARY_PATH"
echo "Launching HLDS with mod zamnhlmp on port 27015, map crossfire, maxplayers 16, timelimit 25"
exec "$DATA_DIR/hlds_run" -game zamnhlmp -port 27015 +map crossfire +maxplayers 16 +mp_timelimit 25
