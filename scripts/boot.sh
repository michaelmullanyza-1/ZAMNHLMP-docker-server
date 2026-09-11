#!/bin/bash
# Container entrypoint: check Steam for updates, then launch the game server.
set -Eeuo pipefail
umask 0027
cd /srv
rm -f /tmp/zamn-serving
mkdir -p releases persistent "$HOME"
: "${UPDATE_TIMEOUT_SECONDS:=600}"
[[ "$UPDATE_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] ||
    { echo "UPDATE_TIMEOUT_SECONDS must be a positive integer" >&2; exit 1; }

child=""
stop_child() {
    if [[ -n "$child" ]]; then
        if kill -0 "$child" 2>/dev/null; then
            kill -TERM "$child"
            for ((n=0; n<20; n++)); do
                if ! kill -0 "$child" 2>/dev/null; then break; fi
                sleep 1
            done
            if kill -0 "$child" 2>/dev/null; then
                echo "Child did not stop gracefully; terminating it." >&2
                kill -KILL "$child"
            fi
        fi
        if wait "$child"; then :; else echo "Stopped child (exit $?)."; fi
        child=""
    fi
}
shutdown() {
    trap - INT TERM
    rm -f /tmp/zamn-serving
    stop_child
    exit 0
}
trap shutdown INT TERM
trap 'rc=$?; trap - EXIT; rm -f /tmp/zamn-serving; stop_child; exit "$rc"' EXIT

exec 8>/srv/.lifecycle.lock
flock -n 8 || { echo "Another server is already using this installation" >&2; exit 1; }

get_release() {
    local value
    value="$(readlink "/srv/$1")"
    [[ "$value" =~ ^releases/r[0-9]+$ && -f "/srv/$value/.ready" ]] ||
        { echo "Invalid $1 release: $value" >&2; return 1; }
    printf '%s\n' "${value#releases/}"
}
set_release() {
    ln -sfn "releases/$1" "/srv/$2.next"
    mv -Tf "/srv/$2.next" "/srv/$2"
}
probe_child() {
    local good=0
    for ((n=0; n<40; n++)); do
        if ! kill -0 "$child" 2>/dev/null; then return 1; fi
        if /bin/bash /scripts/healthcheck.sh --probe >/dev/null 2>&1; then
            good=$((good+1))
            if [[ "$good" -ge 3 ]]; then return 0; fi
        else
            good=0
        fi
        sleep 2
    done
    echo "Game did not become responsive within the startup window." >&2
    return 1
}
start_game() {
    ZAMN_RELEASE="$1" ZAMN_PREFLIGHT="${2:-0}" SERVER_IP="${3:-0.0.0.0}" \
        /bin/bash /scripts/start-server.sh &
    child=$!
}
prune() {
    local path name
    for path in /srv/releases/r*; do
        [[ -d "$path" && ! -L "$path" && -f "$path/.managed-release" ]] || continue
        name="${path##*/}"
        [[ "$name" == "$active" || "$name" == "$previous" || "$name" == "$pending" ]] && continue
        rm -rf -- "$path"
    done
}

active="" previous="" pending="" candidate="" force=0 validate=0 manual_rollback=0
if [[ -L current ]]; then active="$(get_release current)"; fi
if [[ -L previous ]]; then previous="$(get_release previous)"; fi
if [[ -f pending ]]; then
    pending="$(<pending)"
    [[ "$pending" =~ ^r[0-9]+$ ]] || { echo "Invalid pending release" >&2; exit 1; }
    if [[ "$pending" == "$active" || "$pending" == "$previous" ]]; then
        rm pending
        pending=""
    fi
fi
if [[ -f .rollback-next-start ]]; then
    [[ -n "$previous" ]] || { echo "Rollback requested but no previous release exists" >&2; exit 1; }
    manual_rollback=1
    candidate="$previous"
    rm .rollback-next-start
    echo "Manual rollback requested; skipping Steam update on this start."
else
    if [[ -f .force-next-start ]]; then force=1; rm .force-next-start; fi
    if [[ -f .validate-next-start ]]; then validate=1; force=1; rm .validate-next-start; fi
fi

if [[ "$manual_rollback" == 0 && ( "${UPDATE_ON_START:-1}" == 1 || -z "$active" ) ]]; then
    if [[ -z "$pending" ]]; then
        pending="r$(date -u +%Y%m%d%H%M%S%N)"
        printf '%s\n' "$pending" > pending
    fi
    prune
    echo "Checking Steam for dedicated-server AppID ${SERVER_APPID:-3807180} updates on container start."
    RELEASE_ID="$pending" VALIDATE="$validate" \
        timeout --signal=TERM --kill-after=10 "$UPDATE_TIMEOUT_SECONDS" \
        /bin/bash /scripts/update-release.sh &
    child=$!
    if wait "$child"; then
        child=""
        printf '%s\n' "${RUNTIME_IMAGE:?RUNTIME_IMAGE is required}" > "releases/$pending/.image"
        build="$(<"releases/$pending/.build")"
        if [[ -n "$active" && "$build" == "$(<"releases/$active/.build")" &&
              "$RUNTIME_IMAGE" == "$(<"releases/$active/.image")" && "$force" == 0 ]]; then
            echo "Already current at build $build."
            rm -rf -- "releases/$pending"
            rm pending
            pending=""
        elif [[ -f rejected-build && "$(<rejected-build)" == "$build|$RUNTIME_IMAGE" && "$force" == 0 ]]; then
            echo "Build $build previously failed startup; keeping the known-good release." >&2
        else
            candidate="$pending"
        fi
    else
        result=$?
        child=""
        echo "WARNING: Steam update failed or timed out (exit $result); starting the installed release. Pending download is retained." >&2
    fi
elif [[ "$manual_rollback" == 0 ]]; then
    echo "Automatic updates explicitly disabled by UPDATE_ON_START."
fi

if [[ -n "$candidate" && "$manual_rollback" == 0 ]]; then
    echo "Preflight build $(<"releases/$candidate/.build") on loopback only."
    start_game "$candidate" 1 127.0.0.1
    if probe_child; then
        stop_child
        rm -rf -- "probes/$candidate"
    else
        echo "Candidate failed preflight; the installed release is unchanged." >&2
        stop_child
        printf '%s|%s\n' "$(<"releases/$candidate/.build")" "$RUNTIME_IMAGE" > rejected-build
        candidate=""
    fi
fi

old="$active"
old_previous="$previous"
if [[ -n "$candidate" ]]; then
    if [[ -n "$old" ]]; then set_release "$old" previous; previous="$old"; fi
    set_release "$candidate" current
    active="$candidate"
fi
[[ -n "$active" ]] || { echo "No usable release is installed; inspect the update failure above." >&2; exit 1; }

echo "Launching public server from $active."
start_game "$active"
if ! probe_child; then
    stop_child
    fallback="$previous"
    if [[ -z "$fallback" || "$fallback" == "$active" ]]; then
        echo "Server startup failed and no alternate release is available." >&2
        exit 1
    fi
    echo "WARNING: Public startup failed; rolling back to $fallback." >&2
    printf '%s|%s\n' "$(<"releases/$active/.build")" "$RUNTIME_IMAGE" > rejected-build
    set_release "$fallback" current
    active="$fallback"
    if [[ -n "$candidate" && -n "$old_previous" ]]; then
        set_release "$old_previous" previous
        previous="$old_previous"
    fi
    start_game "$active"
    if ! probe_child; then
        echo "Rollback also failed; server is not healthy." >&2
        exit 1
    fi
fi
touch "releases/$active/.healthy" /tmp/zamn-serving
if [[ "$pending" == "$active" ]]; then
    rm pending
    pending=""
fi
prune
echo "READY: build $(<"releases/$active/.build"), port ${SERVER_PORT:-27015}. Restart this container to check for updates again."
if wait "$child"; then result=0; else result=$?; fi
child=""
echo "Game process exited with status $result."
exit "$result"
