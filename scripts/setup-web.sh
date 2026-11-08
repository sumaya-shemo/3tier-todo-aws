set -euo pipefail
sudo apt update && sudo apt install -y nginx
sudo mkdir -p /var/www/todo
sudo cp web/html/index.html /var/www/todo/
sudo cp web/nginx/todo.conf /etc/nginx/sites-available/todo
sudo ln -sf /etc/nginx/sites-available/todo /etc/nginx/sites-enabled/todo
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx
