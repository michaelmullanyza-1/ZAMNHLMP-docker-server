#!/bin/bash
set -e

# Download/update HLDS base server (AppID 90) anonymously
steamcmd +force_install_dir /data \
        +login anonymous \
        +app_update 90 validate \
        +quit

# Download/update ZAMN dedicated server files (AppID 3807180) anonymously
steamcmd +force_install_dir /data \
        +login anonymous \
        +app_update 3807180 validate \
        +quit

# Ensure the mod folder exists
MOD_FOLDER="./zamnhlmp"
if [ ! -d "$MOD_FOLDER" ]; then
    echo "ERROR: ZAMN mod folder '$MOD_FOLDER' not found in /data."
    exit 1
fi

# Set the correct AppID for HLDS reporting
echo "3416640" > ./steam_appid.txt

# Launch HLDS with the ZAMN mod
exec ./hlds_run -game zamnhlmp -port 27015 +map crossfire +maxplayers 16
