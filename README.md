# ZAMN Docker Server

Docker Compose setup for Zombies Ate My Neighbors HLMP multiplayer mod (HLDS-based).

## Quickstart

1. Clone the repository:

```bash
git clone https://github.com/your-username/zamn-docker-server.git
cd zamn-docker-server
```

2. Copy the environment template and edit paths/IDs:

```bash
cp example.env .env
# Edit .env to set SERVER_PATH, PUID, PGID
```

3. Make the launcher executable:

```bash
chmod +x start-server.sh
```

4. Start the server:

```bash
docker-compose up -d
```

## Server Details

* Runs on UDP/TCP port 27037
* Default map: crossfire
* Max players: 16
