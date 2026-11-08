#!/usr/bin/env bash
# Database tier: run on the DB server from the repo root
set -euo pipefail
sudo apt update && sudo apt install -y mysql-server
sudo systemctl enable --now mysql
sudo mysql < database/schema.sql
echo "Now copy database/create-user.sql.example to database/create-user.sql,"
echo "set a real password, and run: sudo mysql < database/create-user.sql"