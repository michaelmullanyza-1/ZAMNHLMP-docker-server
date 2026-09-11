# ZAMN (Half-Life: Cross Product Multiplayer) Docker Server

A Docker Compose setup for a ZAMN dedicated server that checks Steam for updates
**every time the container starts or restarts** — no SSH, no cron, no scheduler.

Restart the container from Portainer (or `docker restart`) and it will:

1. Check Steam for a new dedicated-server build (AppID `3807180`).
2. Download any update into a **separate release folder**, leaving the installed
   copy untouched while it works.
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
    persistent/     bans and game logs
    steam-home/     SteamCMD's own files
```

Only the active and previous releases are kept, plus any partially downloaded
one. Expect roughly 1.5 GB per retained release.

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
- **Disk usage is higher** than an in-place installer, because a whole previous
  release is retained.

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
