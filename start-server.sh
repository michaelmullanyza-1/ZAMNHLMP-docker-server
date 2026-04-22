#!/bin/bash
set -e

echo "=== Script starting: HLDS setup and launch ==="

DATA_DIR=/data
CONFIG_FILE="$DATA_DIR/zamnhlmp/server.cfg"
STEAM_APP_FILE="$DATA_DIR/steam_appid.txt"

echo "DATA_DIR=$DATA_DIR"
echo "CONFIG_FILE=$CONFIG_FILE"
echo "STEAM_APP_FILE=$STEAM_APP_FILE"

# Backup server.cfg
echo "Checking for server.cfg..."
if [ -f "$CONFIG_FILE" ]; then
    echo "server.cfg found — backing up to $CONFIG_FILE.bak"
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    echo "Backup complete."
else
    echo "server.cfg not found, skipping backup."
fi

# SteamCMD update (anonymous)
echo "Running SteamCMD update for app 3807180..."
steamcmd +force_install_dir "$DATA_DIR" +login anonymous +app_update 3807180 validate +quit
echo "SteamCMD update complete."

# Restore server.cfg
echo "Checking for server.cfg.bak..."
if [ -f "$CONFIG_FILE.bak" ]; then
    echo "Restoring server.cfg from backup..."
    mv "$CONFIG_FILE.bak" "$CONFIG_FILE"
    echo "Restore complete."
else
    echo "No server.cfg.bak found, skipping restore."
fi

# Set AppID
echo "Writing AppID 3416640 to $STEAM_APP_FILE..."
echo "3416640" > "$STEAM_APP_FILE"
chmod 444 "$STEAM_APP_FILE"
echo "AppID written and permissions set to 444."

# Launch HLDS
echo "Exporting LD_LIBRARY_PATH..."
export LD_LIBRARY_PATH="$DATA_DIR:$LD_LIBRARY_PATH"
echo "LD_LIBRARY_PATH set."

echo "Launching HLDS: mod=zamnhlmp, port=27036, map=crossfire, maxplayers=16, timelimit=25"
exec "$DATA_DIR/hlds_run" -game zamnhlmp -port 27036 +map crossfire +maxplayers 16 +mp_timelimit 25
