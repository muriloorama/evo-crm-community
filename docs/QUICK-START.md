# Quick Start — Running Evo AI in 5 Minutes

This guide will get Evo AI Community running on your machine. No prior Docker or terminal experience needed — just copy and paste each command.

## Prerequisites

Before you begin, install these two tools:

| Tool             | Download Link                                      |
|------------------|----------------------------------------------------|
| **Docker Desktop** | [Windows](https://docs.docker.com/desktop/install/windows-install/) · [Mac](https://docs.docker.com/desktop/install/mac-install/) · [Linux](https://docs.docker.com/desktop/install/linux/) |
| **Git**          | [git-scm.com/downloads](https://git-scm.com/downloads) |

> **Tip:** After installing Docker Desktop, make sure it is **running** before continuing (look for the Docker icon in your system tray).

---

## Step 1: Clone the Repository

Open a terminal (Terminal on Mac/Linux, PowerShell on Windows) and run:

```bash
git clone --recurse-submodules https://github.com/EvolutionAPI/evo-crm-community.git
cd evo-crm-community
```

**What to expect:** You'll see Git downloading the project and all its services. This may take 1–2 minutes depending on your internet speed.

```
Cloning into 'evo-crm-community'...
remote: Enumerating objects: ...
Submodule 'evo-auth-service-community' (...) registered for path ...
Submodule 'evo-ai-crm-community' (...) registered for path ...
...
```

**Success looks like:** The command finishes with no errors and you're inside the `evo-crm-community` folder.

---

## Step 2: Configure Environment

```bash
cp .env.example .env
```

**What this does:** Creates your local configuration file from the provided template. The default values work out of the box — no edits needed.

**Success looks like:** No output (silence means success).

---

## Step 3: Start Services

```bash
docker compose up -d
```

**What to expect:** Docker will download base images and build each service. First run takes approximately **3–5 minutes**.

```
[+] Running 10/10
 ✔ Container evo-crm-community-postgres-1    Healthy
 ✔ Container evo-crm-community-redis-1       Healthy
 ✔ Container evo-crm-community-mailhog-1     Started
 ...
```

**Success looks like:** All services listed as "running" when you check with `docker compose ps`.

---

## Step 4: Wait and Seed Databases

The database needs initial data (default user and inbox). This takes **~2 minutes**.

**Option A — Using Make (recommended):**

```bash
make seed
```

**Option B — Manual Docker commands (if you don't have `make`):**

```bash
# Seed Auth service (creates default user)
docker compose run --rm evo-auth bash -c "bundle exec rails db:create db:migrate db:seed"

# Seed CRM service (creates default inbox)
docker compose run --rm evo-crm bash -c "bundle exec rails db:create db:migrate db:seed"
```

**What to expect:** You'll see database migration and seed output. This takes approximately **~2 minutes**.

**Success looks like:** Both commands finish without errors. You can verify services are healthy:

```bash
docker compose ps
```

Wait until all services show as **healthy**. You can watch logs in real time:

```bash
docker compose logs -f
```

Press `Ctrl+C` to stop watching logs (services keep running in the background).

---

## Step 5: Open the Application

Open your browser and go to:

**http://localhost:5173**

Log in with:

| Field    | Value                                    |
|----------|------------------------------------------|
| Email    | `support@evo-auth-service-community.com` |
| Password | `Password@123`                           |

**Success looks like:** You see the Evo AI dashboard after logging in.

---

## Stopping and Restarting

```bash
# Stop all services
make stop

# Start again later
make start

# View logs
make logs
```

---

## Next Steps

- [Setup Guide](SETUP-GUIDE.md) — Customize configuration, change ports, add SSL, connect WhatsApp
- [Troubleshooting](TROUBLESHOOTING.md) — Solutions for common problems
- [Contributing](../CONTRIBUTING.md) — Help improve Evo AI
