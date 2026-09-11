#!/bin/bash
# Optional helper. Everything here can also be done from Docker or Portainer:
# a plain container start/restart already checks Steam for updates.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT"
if [[ -f .env ]]; then set -a; . ./.env; set +a; fi
: "${SERVER_PATH:?SERVER_PATH must be set in .env}"
DATA="$SERVER_PATH/data"
compose=(docker compose --project-directory "$ROOT" -f "$ROOT/docker-compose.yml")

flag() {
    install -m 640 -o "${PUID:-1000}" -g "${PGID:-1000}" /dev/null "$DATA/.$1-next-start"
}
restart() {
    "${compose[@]}" stop server
    case "${1:-normal}" in
        validate|force|rollback) flag "$1" ;;
    esac
    "${compose[@]}" up -d --no-deps server
}

case "${1:-status}" in
    update)
        [[ "$#" -le 2 && "${2:---force}" == --force ]] ||
            { echo "Usage: $0 update [--force]" >&2; exit 1; }
        if [[ "${2:-}" == --force ]]; then restart force; else restart normal; fi
        ;;
    restart) restart normal ;;
    validate) restart validate ;;
    rollback)
        [[ -L "$DATA/previous" ]] || { echo "No previous healthy release exists" >&2; exit 1; }
        restart rollback
        ;;
    stop) "${compose[@]}" stop server ;;
    status)
        "${compose[@]}" ps -a
        for label in current previous; do
            if [[ -L "$DATA/$label" ]]; then
                echo "$label: $(readlink "$DATA/$label") / build $(<"$DATA/$label/.build")"
            fi
        done
        ;;
    logs) "${compose[@]}" logs --tail 100 server ;;
    *)
        echo "Usage: $0 {update [--force]|validate|rollback|restart|stop|status|logs}" >&2
        exit 1
        ;;
esac
