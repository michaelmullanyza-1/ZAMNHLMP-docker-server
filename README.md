# ZAMN (Half-Life: Cross Product Multiplayer) Docker Server

A Docker Compose setup for a ZAMN dedicated server that checks Steam for updates
**every time the container starts or restarts** — no SSH, no cron, no scheduler.

Restart the container from Portainer (or `docker restart`) and it will:

1. Check Steam for a new dedicated-server build (AppID `3807180`).
2. Update **separate Steam-managed staging**, then snapshot a successful download
   into a release folder, leaving the installed copy untouched while it works.
3. Start the new build privately on loopback and wait for it to answer a real
   game query before it is allowed to serve players.
4. Promote it, keeping the previous release for rollback.

If Steam is slow, broken, or the new build fails to start, the server falls back
to the last release that actually worked and says so in the container log.

## Quick start

```bash
git clone https://github.com/michaelmullanyza-1/ZAMNHLMP-docker-server.git
cd ZAMNHLMP-docker-server
cp example.env .env          # set SERVER_PATH, PUID/PGID, SERVER_PORT
mkdir -p "$SERVER_PATH"/{data,config}
cp config/server.example.cfg "$SERVER_PATH/config/server.cfg"
docker compose up -d
docker compose logs -f
```

The first start downloads roughly 1.5 GB, so it takes a while. Watch for
`READY: build <id>, port <port>` in the log.

In Portainer, deploy this repository as a stack and set the same variables in
the stack's environment section.

### Permissions

The container runs as `PUID:PGID` (default `1000:1000`) and never as root.
Make sure that user owns `$SERVER_PATH`:

```bash
sudo chown -R 1000:1000 "$SERVER_PATH"
```

## Configuration

`$SERVER_PATH/config/server.cfg` lives **outside** the Steam installation and is
copied into the game on every start, so updates cannot overwrite it.
Start from `config/server.example.cfg`.

Keep `rcon_password` in `$SERVER_PATH/config/rcon.cfg` (git-ignored), not in
`server.cfg`.

Custom game files go in `$SERVER_PATH/config/overrides/`, mirroring the game's
own layout, and are reapplied after every update:

```
config/overrides/zamnhlmp/gamemodes/ffa.cfg
config/overrides/zamnhlmp/mapcycles/custom.txt
```

Prefer small, deliberate overrides. Copying an entire upstream folder freezes
its defaults and you will silently miss future changes to those files.
Note that game-mode configs can override values such as `mp_timelimit`.

Bans and game logs are stored in `$SERVER_PATH/data/persistent`, so they survive
updates and rollbacks.

## Layout

```
$SERVER_PATH/
  config/           your settings (server.cfg, rcon.cfg, overrides/)
  data/
    releases/rNNN/  versioned game installs
    current -> releases/rNNN
    previous -> releases/rNNN
    staging/        Steam-managed install; never used to run the game
    persistent/     bans and game logs
    steam-home/     SteamCMD's own files
```

The active and previous releases are kept, plus a pending snapshot when needed.
Downloads resume in `staging/`, separate from those releases. Allow at least
**6 GB free** for staging, current, previous, and a candidate snapshot
(roughly 1.5 GB each), plus headroom for Steam's temporary download files.

## Update safeguards

- SteamCMD updates a stable `staging/` directory rather than a copy of a running
  release. Runtime configuration, logs, and ban-file links do not enter staging.
- Attempts escalate from incremental update to `validate`, then discard staging
  for a clean install. All attempts share `UPDATE_TIMEOUT_SECONDS` (default 600).
  Reinstalling is a recovery attempt, not a guarantee against Steam/network/disk
  failures. Keep unrelated files out of `staging/`.
- Success requires a zero exit status (including log capture), a fresh confirmation
  for `SERVER_APPID`, and a complete manifest with `StateFlags == 4`. An old complete
  manifest cannot turn a failed Steam check into "already current."
- If the checked build and runtime image match the active release, snapshotting is
  skipped unless forced. The first start after upgrading an older stack downloads
  pristine staging once; later unchanged starts avoid copying the whole game.
- Only directories marked `.managed-release` can be replaced or cleaned up.
  Files, symlinks, unmarked targets, and the current/previous releases are protected.
  New snapshots are marked before copying so interrupted copies can be retried.
- Preflight, public-startup rollback, forced validation, and manual rollback remain
  unchanged. Existing active/previous releases and persistent settings are retained.

The staging design was adopted after a related copied-install update failed with
SteamCMD `state is 0x6`, while a clean install with refreshed metadata succeeded.
That observation does **not** prove copied Steam installations can never update,
nor that Steam universally binds installs to exact paths. Staging keeps downloaded
content separate from runtime changes; `+app_info_update 1` requests fresh metadata.

### Regression checks

Run the dependency-free Bash checks in an isolated container. They substitute
SteamCMD responses; they do not download games, publish ports, or mount live data:

```bash
docker run --rm --network none --user 1000:1000 \
  --tmpfs /srv:exec,uid=1000,gid=1000,mode=0700 \
  --tmpfs /scripts:exec,uid=1000,gid=1000,mode=0700 \
  -e ZAMN_TEST_CONTAINER=1 -v "$PWD:/repo:ro" \
  --entrypoint /bin/bash \
  gameservermanagers/steamcmd@sha256:223bf8691bd2662bfa05ed5e3112651fc0f86491ca4590afc0e362983a3e1e6d \
  /repo/tests/update-release.sh
```

## Optional commands

Normal updates need none of these — a container restart is enough.

```bash
./manage.sh status      # container state and release/build info
./manage.sh logs
./manage.sh update      # same as a restart
./manage.sh update --force   # re-promote even a previously rejected build
./manage.sh validate    # ask Steam to verify/repair files on next start
./manage.sh rollback    # switch back to the previous release
./manage.sh restart
./manage.sh stop
```

`manage.sh` is a thin wrapper: it stops the container, drops a flag file, and
starts it again. All the real logic runs inside the container.

## Trade-offs worth knowing

- **Updates happen at startup.** Players cannot connect during the check and
  download. The container reports `starting` until the game answers queries.
  There is no rolling or zero-downtime update.
- **A failed first install has nothing to fall back to.** Fallback only helps
  once at least one release is installed.
- **Health means "answers A2S queries".** It does not prove every gameplay
  feature works.
- **Rollback restores game files only** — not your config, not the container
  image, not SteamCMD's shared files.
- **Disk usage is higher** than an in-place installer: staging, release snapshots,
  and Steam scratch files coexist. See the layout above for capacity planning.

## Notes

- Downloads are anonymous; no Steam login or credentials are needed.
- Dedicated server AppID is `3807180`; the game AppID (`3416640`) is read from
  the installed mod's `steam.inf` automatically.
- The SteamCMD image is pinned by digest so a routine restart cannot silently
  change the Linux runtime underneath the server. `cm2network/steamcmd` works
  too — set `STEAMCMD_IMAGE` in `.env`.
- Docker restarts the container after crashes and host reboots unless you
  explicitly stopped it.
- Portainer shows stacks created outside its UI as externally managed, with
  limited stack editing. Start/Restart/Stop and Logs work normally.
