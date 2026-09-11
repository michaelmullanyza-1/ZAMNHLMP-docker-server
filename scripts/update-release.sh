#!/bin/bash
# Download or update the dedicated server into a staging release directory.
set -Eeuo pipefail
umask 0027

: "${RELEASE_ID:?RELEASE_ID must be supplied by boot.sh}"
: "${SERVER_APPID:=3807180}"
[[ "$RELEASE_ID" =~ ^r[0-9]+$ ]] || { echo "Invalid release ID" >&2; exit 1; }
[[ "$SERVER_APPID" =~ ^[0-9]+$ ]] || { echo "Invalid SERVER_APPID" >&2; exit 1; }
mkdir -p /srv/releases "$HOME"
exec 9>/srv/.download.lock
flock -n 9 || { echo "Another download is already running" >&2; exit 1; }
target="/srv/releases/$RELEASE_ID"
for link in current previous; do
    if [[ -L "/srv/$link" && "$(readlink -f "/srv/$link")" == "$target" ]]; then
        echo "Refusing to update the $link release in place" >&2
        exit 1
    fi
done
if [[ -e "$target" ]]; then
    [[ -d "$target" && ! -L "$target" && -f "$target/.managed-release" ]] ||
        { echo "Cannot resume an unrecognized release" >&2; exit 1; }
    echo "Resuming staged download $RELEASE_ID."
else
    mkdir "$target"
    touch "$target/.managed-release"
fi

if [[ ( ! -f "$target/.seeded" || -f "$target/.copying" ) && -L /srv/current ]]; then
    active="$(readlink -f /srv/current)"
    [[ "$active" == /srv/releases/r* && -f "$active/.managed-release" ]] ||
        { echo "Invalid active release" >&2; exit 1; }
    touch "$target/.copying"
    cp -a --reflink=auto "$active/." "$target/"
    rm "$target/.copying"
fi
touch "$target/.seeded"
rm -f "$target/.ready" "$target/.image" "$target/.build" "$target/.healthy"
# Do not let SteamCMD follow runtime links into the persistent state.
rm -f "$target/zamnhlmp/banned.cfg" "$target/zamnhlmp/listip.cfg"
if [[ -L "$target/zamnhlmp/logs" ]]; then
    rm "$target/zamnhlmp/logs"
fi

args=(+force_install_dir "$target" +login anonymous +app_update "$SERVER_APPID")
if [[ "${VALIDATE:-0}" == 1 ]]; then
    args+=(validate)
fi
args+=(+quit)
if command -v steamcmd >/dev/null; then
    steam=(steamcmd)
elif [[ -x /home/steam/steamcmd/steamcmd.sh ]]; then
    steam=(/home/steam/steamcmd/steamcmd.sh)
else
    echo "SteamCMD executable not found in this image" >&2
    exit 1
fi
success=0
for attempt in 1 2 3; do
    echo "SteamCMD attempt $attempt of 3."
    if "${steam[@]}" "${args[@]}" 2>&1 | tee "$target/.steam-update.log"; then
        if grep -Eq "Success! App '$SERVER_APPID' (fully installed|already up to date)" "$target/.steam-update.log"; then
            success=1
            break
        fi
        echo "SteamCMD returned without confirming success." >&2
    else
        echo "SteamCMD attempt $attempt failed; downloaded data is retained." >&2
    fi
    if [[ "$attempt" -lt 3 ]]; then sleep 15; fi
done
[[ "$success" == 1 ]] || { echo "Download failed; the next container start will resume it." >&2; exit 1; }

manifest="$target/steamapps/appmanifest_$SERVER_APPID.acf"
[[ -s "$manifest" && -x "$target/hlds_linux" ]] ||
    { echo "Download did not produce a complete server" >&2; exit 1; }
flags="$(awk '$1=="\"StateFlags\"" {gsub(/"/,"",$2); print $2}' "$manifest")"
build="$(awk '$1=="\"buildid\"" {gsub(/"/,"",$2); print $2}' "$manifest")"
[[ "$flags" == 4 && "$build" =~ ^[0-9]+$ ]] ||
    { echo "Steam reports an incomplete installation (state $flags, build $build)" >&2; exit 1; }
printf '%s\n' "$build" > "$target/.build"

client="$(find "$HOME" -path '*/linux32/steamclient.so' -type f -print -quit)"
if [[ -n "$client" ]]; then
    mkdir -p "$HOME/.steam/sdk32"
    ln -sfn "$client" "$HOME/.steam/sdk32/steamclient.so"
else
    echo "32-bit Steam client library is missing after SteamCMD installation" >&2
    exit 1
fi
touch "$target/.ready"
echo "Staged build $build in $RELEASE_ID; the running server was not changed."
