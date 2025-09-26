# ZAMN Half-Life: Cross Product Multiplayer Docker Server Quick Start

Use the provided `docker-compose.yml` and `start-server.sh` to get a ZAMN Half-Life: Cross Product Multiplayer server running quickly.

## Steps

1. **Edit environment variables**

- Copy `example.env` to `.env` and adjust paths and IDs as needed:
  - `SERVER_PATH` — base folder for server files and data
  - `PUID` / `PGID` — user and group IDs for permissions

2. **Ensure `start-server.sh` is executable**

```bash
chmod +x start-server.sh
```

3. **Launch the server**

- Using Docker Compose:

```bash
docker-compose up -d
```

- Or via Portainer, just deploy the stack with the provided `docker-compose.yml`.

4. **Server Details**

- Ports: UDP/TCP 27015
- Default map: `crossfire`
- Max players: 16
- Steam AppID is correctly set to `3416640`

5. Persistence

- Between reboots, your server.cfg, liblist.gam and metamod plugins.ini will be preserved. Everything else will be wiped and rebuilt.

## Notes

- Server data, mods, and configs are stored under the folder specified in `SERVER_PATH`.
- `start-server.sh` handles downloading/updating the ZAMN dedicated server (AppID 3807180).
- No Steam login is required; downloads are anonymous.

