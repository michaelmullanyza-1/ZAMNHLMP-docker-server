#!/bin/bash
# Apply configuration to a release and run the game engine in the foreground.
set -Eeuo pipefail
umask 0027

if [[ -n "${ZAMN_RELEASE:-}" ]]; then
    [[ "$ZAMN_RELEASE" =~ ^r[0-9]+$ ]] || { echo "Invalid release ID" >&2; exit 1; }
    release="/srv/releases/$ZAMN_RELEASE"
else
    [[ -L /srv/current ]] || { echo "No installed release; start the container to install one" >&2; exit 1; }
    release="$(readlink -f /srv/current)"
fi
[[ "$release" == /srv/releases/r* && -f "$release/.ready" ]] ||
    { echo "Release is not ready: $release" >&2; exit 1; }

cd "$release"
if [[ -s /config/server.cfg ]]; then
    cp /config/server.cfg zamnhlmp/server.cfg
else
    echo "WARNING: /config/server.cfg is missing; using the game's packaged server.cfg." >&2
fi
if [[ -d /config/overrides ]]; then
    cp -r /config/overrides/. ./
fi
if [[ -f /config/rcon.cfg ]]; then
    cp /config/rcon.cfg zamnhlmp/rcon.cfg
fi

state=/srv/persistent
extra=()
if [[ "${ZAMN_PREFLIGHT:-0}" == 1 ]]; then
    state="/srv/probes/$(basename "$release")"
    printf '\nsv_lan 1\n' >> zamnhlmp/server.cfg
    extra=(+sv_lan 1)
fi
mkdir -p "$state/logs"
for file in banned.cfg listip.cfg; do
    touch "$state/$file"
    ln -sfn "$state/$file" "zamnhlmp/$file"
done
if [[ -d zamnhlmp/logs && ! -L zamnhlmp/logs ]]; then
    # Valve's packaged logs directory is not authoritative runtime state.
    mv zamnhlmp/logs "zamnhlmp/logs.packaged.$(date +%s)"
fi
ln -sfn "$state/logs" zamnhlmp/logs

appid="$(awk -F= 'tolower($1)=="appid" {gsub(/[[:space:]]/,"",$2);print $2;exit}' zamnhlmp/steam.inf)"
[[ "$appid" =~ ^[0-9]+$ ]] || { echo "Game AppID missing from steam.inf" >&2; exit 1; }
printf '%s\n' "$appid" > steam_appid.txt
export SteamAppId="$appid"
export SteamGameId="$appid"
export LD_LIBRARY_PATH="$release:$HOME/.steam/sdk32:${LD_LIBRARY_PATH:-}"
echo "Starting ZAMN build $(<.build): map=${START_MAP:-crossfire}, port=${SERVER_PORT:-27015}, players=${MAX_PLAYERS:-16}"
# Run the engine directly: Docker, not the legacy hlds_run loop, owns restarts.
exec ./hlds_linux -console -game zamnhlmp -ip "${SERVER_IP:-0.0.0.0}" \
    -port "${SERVER_PORT:-27015}" +map "${START_MAP:-crossfire}" \
    +maxplayers "${MAX_PLAYERS:-16}" "${extra[@]}"
