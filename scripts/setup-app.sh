#!/usr/bin/env bash
# Application tier: run on the API server from the repo root
set -euo pipefail
sudo apt update && sudo apt install -y nodejs npm
sudo mkdir -p /opt/todo-api
sudo cp app/server.js app/package.json /opt/todo-api/
(cd /opt/todo-api && sudo npm install --omit=dev)

if [ ! -f /etc/todo-api.env ]; then
  sudo cp app/.env.example /etc/todo-api.env
  echo "Created /etc/todo-api.env - edit it and set DB_PASSWORD, then re-run this script."
fi
sudo chown root:www-data /etc/todo-api.env
sudo chmod 640 /etc/todo-api.env
sudo chown -R www-data:www-data /opt/todo-api

sudo cp app/todo-api.service /etc/systemd/system/todo-api.service
sudo systemctl daemon-reload
sudo systemctl enable todo-api
sudo systemctl restart todo-api
sudo systemctl status todo-api --no-pager