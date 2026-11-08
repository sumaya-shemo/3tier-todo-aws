# 3-Tier To-Do Application on AWS: Project Explanation

This document explains **what was built, why each step was done, and how the pieces fit together**.
For the commands and full source code, see [README.md](README.md).

---

## 1. Project Goal

Deploy a To-Do application where a user can add, view, complete and delete tasks, and the data is saved permanently in a database.

The application is split into three tiers, each on its own EC2 server:

| Tier | Job | Where it lives |
|------|-----|----------------|
| Web | Shows the page to the user and forwards API requests | Public subnet |
| Application | Business logic; talks to the database | Private subnet |
| Database | Stores the tasks permanently | Private subnet |

**Main security idea:** only the web server is reachable from the internet. The application and database servers have no public IP and cannot be reached directly.

![Architecture Diagram Here](docs/architecture.png)

### Screenshots for Architecture Diagram Here
(The diagram above is the architecture screenshot.)

---

## 2. How a Request Travels

When a user adds a task, this is what happens:

1. The browser sends the request to `https://<web-public-ip>`.
2. **Nginx** (web tier) receives it. If it is the page itself, Nginx serves `index.html`. If the URL starts with `/api/`, Nginx forwards it to one of the two app servers.
3. The **Node.js API** (application tier) receives the request and runs a SQL query.
4. **MySQL** (database tier) saves the row and returns the result.
5. The answer goes back the same path to the browser.

At no point does the browser talk to the app or database server directly. Nginx is the only door.

---

## 3. Network Foundation (VPC)

### What is a VPC?
A VPC is your own private network inside AWS. Everything in this project lives inside one VPC (`10.0.0.0/16`), so we control which servers can see each other.

### Screenshots for VPC Here
![Screenshots for VPC Here](docs/screenshots/01-vpc.png)

### Why three subnets?
A subnet is a smaller section of the VPC.

- **public-subnet (10.0.1.0/24):** for the web server. Its route table sends internet traffic to the Internet Gateway.
- **private-app-subnet (10.0.2.0/24):** for the API servers. No direct route from the internet.
- **private-db-subnet (10.0.3.0/24):** for the database. Kept separate from the app tier so it can be locked down independently.

What makes a subnet "public" or "private" is **only its route table**, not its name.

### Screenshots for Subnets Here
![Screenshots for Subnets Here](docs/screenshots/02-subnets.png)

### Internet Gateway (IGW)
The IGW is the door between the VPC and the internet. It is attached to the VPC, and only the public route table points to it.

### Screenshots for Internet Gateway Here
![Screenshots for Internet Gateway Here](docs/screenshots/03-internet-gateway.png)

### NAT Gateway
Private servers need the internet **only to download software** (apt, Node.js, npm packages). The NAT Gateway sits in the public subnet and lets private servers make **outgoing** connections, while still blocking anyone on the internet from starting a connection **into** them.

### Screenshots for NAT Gateway Here
![Screenshots for NAT Gateway Here](docs/screenshots/04-nat-gateway.png)

### Route Tables

| Route table | Key route | Effect |
|-------------|-----------|--------|
| public-rt | `0.0.0.0/0 → Internet Gateway` | Public subnet can send and receive internet traffic |
| private-rt | `0.0.0.0/0 → NAT Gateway` | Private subnets can only go out, never be reached from outside |

Both tables also have the default `10.0.0.0/16 → local` route, which lets all subnets in the VPC talk to each other (access is then controlled by security groups).

### Screenshots for Public Route Table Here
![Screenshots for Public Route Table Here](docs/screenshots/05-public-route-table.png)

### Screenshots for Private Route Table Here
![Screenshots for Private Route Table Here](docs/screenshots/06-private-route-table.png)

---

## 4. Security Groups (Instance Firewalls)

A security group is a firewall attached to an EC2 instance. It only needs **allow** rules; everything not allowed is blocked.

The important design choice: app-sg and db-sg use **another security group as the source** instead of an IP address. That means "allow only servers that belong to that group", which is stricter and does not break if IPs change.

| Security group | Allows | From | Why |
|----------------|--------|------|-----|
| web-sg | 80, 443 | Anywhere | Users must reach the website |
| web-sg | 22 | My IP only | Admin access, not open to the world |
| app-sg | 3000 | web-sg | Only Nginx may call the API |
| app-sg | 22 | web-sg | SSH through the jump host |
| db-sg | 3306 | app-sg | Only the API may query the database |
| db-sg | 22 | web-sg | SSH through the jump host |

This gives the chain **Internet → web → app → db**, where each tier accepts traffic only from the tier before it.

### Screenshots for web-sg Here
![Screenshots for web-sg Here](docs/screenshots/07-web-sg.png)

### Screenshots for app-sg Here
![Screenshots for app-sg Here](docs/screenshots/08-app-sg.png)

### Screenshots for db-sg Here
![Screenshots for db-sg Here](docs/screenshots/09-db-sg.png)

---

## 5. EC2 Instances

Four Ubuntu 22.04 instances were launched: `web-server`, `app-server-1`, `app-server-2` and `db-server`.

Key launch settings:
- `web-server`: **auto-assign public IP enabled** (this is the only server with one).
- The other three: **auto-assign public IP disabled**.
- All use the same key pair, and each gets its tier's security group.

This satisfies the rule "only the web server may have a public IP".

### Screenshots for EC2 Instances Here
![Screenshots for EC2 Instances Here](docs/screenshots/10-ec2-instances.png)

---

## 6. Managing Private Servers Without SSM

Private servers have no public IP, and SSM Session Manager is not allowed, so the **web server acts as a jump host (bastion)**:

```
My laptop ──SSH──► web-server (public) ──SSH──► private server
```

With `ProxyJump` in the local `~/.ssh/config`, one command (`ssh app1`) connects through the web server automatically.

The `.pem` key stays on the laptop and is **never copied to AWS**. If the web server were compromised, the key would not be exposed.

### Screenshots for SSH Jump Host Login Here
![Screenshots for SSH Jump Host Login Here](docs/screenshots/11-ssh-jump-host.png)

---

## 7. Database Tier (db-server)

**What runs here:** MySQL.

**Why it is configured this way:**
- MySQL listens only on the server's **private IP** (`bind-address`). By default it listens only on localhost, which would stop the app servers from connecting.
- A dedicated user `todo` is created with access to only one database (`tododb`), instead of using the root account.
- The user is defined as `'todo'@'10.0.2.%'`, so even with the right password it can only log in from the app subnet. This is a second layer of protection on top of the security group.
- The `tasks` table has an `id`, `title`, `done` flag and timestamp. Two seed rows are inserted so the page shows data from the start.

Data persists because MySQL writes to disk on the db-server. Restarting the API or the web server never deletes tasks.

### Screenshots for MySQL Installation and Tasks Table Here
![Screenshots for MySQL Installation and Tasks Table Here](docs/screenshots/12-mysql-db.png)

---

## 8. Application Tier (app-server-1 and app-server-2)

**What runs here:** a Node.js (Express) REST API on port 3000.

| Endpoint | Purpose |
|----------|---------|
| `GET /api/tasks` | List all tasks |
| `POST /api/tasks` | Add a task |
| `PUT /api/tasks/:id` | Toggle done / not done |
| `DELETE /api/tasks/:id` | Delete a task |
| `GET /api/health` | Health check; also returns the server hostname |

**Design choices:**
- **Credentials in an environment file** (`/etc/todo-api.env`, permission 600), not hard-coded in the source. The code in GitHub contains no passwords.
- **Parameterized SQL queries** (`?` placeholders), which protects against SQL injection.
- **systemd service** with `Restart=always` and `WantedBy=multi-user.target`. The assignment requires the API to survive a reboot. systemd starts it on boot and restarts it if it crashes, unlike running `node server.js` by hand.
- The API returns its **hostname**, so we can prove which server answered (used for the load-balancing demo).

Two identical servers are used so Nginx can balance between them.

### Screenshots for App Server 1 API Running Here
![Screenshots for App Server 1 API Running Here](docs/screenshots/13-app1-api.png)

### Screenshots for App Server 2 API Running Here
![Screenshots for App Server 2 API Running Here](docs/screenshots/14-app2-api.png)

---

## 9. Web Tier (web-server)

**What runs here:** Nginx, which does two jobs:

1. **Serves the frontend:** a single `index.html` page with JavaScript that calls the API using relative URLs (`/api/tasks`).
2. **Reverse proxy:** any request starting with `/api/` is passed to the application servers.

**Why a reverse proxy?**
- The browser only ever sees one address, so the private IPs stay hidden.
- No CORS problems, because the page and API share the same origin.
- It is the single entry point where HTTPS and load balancing are handled.

### Screenshots for Nginx Running Here
![Screenshots for Nginx Running Here](docs/screenshots/16-nginx-status.png)

### Screenshots for Working Application in Browser Here
![Screenshots for Working Application in Browser Here](docs/screenshots/17-app-in-browser.png)

### Screenshots for Data Persisting in Database Here
![Screenshots for Data Persisting in Database Here](docs/screenshots/18-data-persist.png)

---

## 10. Bonus 1: Load Balancing with Nginx

Nginx's `upstream` block lists both app servers. By default it uses **round-robin**: request 1 goes to app-server-1, request 2 to app-server-2, and so on.

Benefits:
- Traffic is shared between servers.
- If one app server goes down, Nginx automatically sends requests to the other one, so the site stays up.

**Proof:** the page shows "Served by: <hostname>", and the hostname changes as you refresh.

### Screenshots for Load Balancing (Alternating Servers) Here
![Screenshots for Load Balancing Here](docs/screenshots/19-load-balancing.png)



## 15. What I Learned

- How a VPC, subnets, route tables, an IGW and a NAT Gateway work together.
- Why security groups should reference other security groups instead of IP ranges.
- How to reach private servers safely with a jump host.
- How to run a service reliably with systemd.
- How Nginx works as a reverse proxy, a load balancer and an HTTPS terminator.
- Why scripting a setup makes deployments repeatable.








