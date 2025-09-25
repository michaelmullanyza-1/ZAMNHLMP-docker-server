# ZAMN Docker Server

Docker Compose setup for Zombies Ate My Neighbors HLMP multiplayer mod (HLDS-based).

## Quickstart

1. Clone the repository:

```bash
git clone https://github.com/your-username/zamn-docker-server.git
cd zamn-docker-server
Copy the environment template and edit paths/IDs:
cp example.env .env
# Edit .env to set SERVER_PATH, PUID, PGID

Make the launcher executable:
chmod +x start-server.sh
start the server
docker-compose up -d

Runs on UDP/TCP port 27015

Default map: crossfire

Max players: 16
