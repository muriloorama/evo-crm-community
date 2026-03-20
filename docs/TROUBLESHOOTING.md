# Troubleshooting

Common problems and their solutions. Each entry follows the format: **Problem** → **Cause** → **Solution**.

---

## Port Already in Use

**Problem:** `Error: Bind for 0.0.0.0:3000 failed: port is already allocated`

**Cause:** Another application is using the same port.

**Solution:**

```bash
# Find what's using the port (example: port 3000)
lsof -i :3000    # Mac/Linux
netstat -ano | findstr :3000    # Windows

# Either stop the other application, or change the port in docker-compose.yml
# e.g., change "3000:3000" to "3100:3000"
```

---

## Docker Daemon Not Running

**Problem:** `Cannot connect to the Docker daemon` or `docker: command not found`

**Cause:** Docker Desktop is not running or not installed.

**Solution:**

1. Install Docker Desktop from [docker.com](https://docs.docker.com/desktop/)
2. Open Docker Desktop and wait for it to fully start (check the system tray icon)
3. Verify with: `docker info`

---

## Permission Denied on setup.sh

**Problem:** `bash: ./setup.sh: Permission denied` (if running `setup.sh` directly instead of `make setup`)

**Cause:** The script doesn't have execute permissions.

**Solution:**

```bash
# Preferred: use make instead
make setup

# Or fix permissions and run directly
chmod +x setup.sh
./setup.sh
```

---

## Database Connection Refused

**Problem:** Services fail with `PG::ConnectionBad: could not connect to server` or similar database errors.

**Cause:** PostgreSQL hasn't finished starting, or there's a configuration mismatch.

**Solution:**

```bash
# Check if postgres is running
docker compose ps postgres

# Check postgres logs
docker compose logs postgres

# Restart just the database
docker compose restart postgres

# Wait for it to be healthy, then restart dependent services
docker compose restart evo-auth evo-crm evo-core evo-processor
```

---

## Frontend Shows Blank Page

**Problem:** Navigating to http://localhost:5173 shows a blank white page.

**Cause:** The `VITE_*` environment variables weren't set correctly during the frontend Docker build.

**Solution:**

```bash
# Verify .env has the VITE_* variables
grep VITE_ .env

# Rebuild the frontend with the correct variables
docker compose build evo-frontend
docker compose up -d evo-frontend
```

> The `VITE_*` variables are baked in at **build time**, not runtime. You must rebuild the frontend image after changing them.

---

## Cannot Login

**Problem:** Login page appears but credentials are rejected.

**Cause:** Database seeds haven't been run (the default user doesn't exist).

**Solution:**

```bash
# Run the seed commands
make seed

# Or manually:
docker compose run --rm evo-auth bash -c "bundle exec rails db:create db:migrate db:seed"
docker compose run --rm evo-crm bash -c "bundle exec rails db:create db:migrate db:seed"
```

Default credentials: `support@evo-auth-service-community.com` / `Password@123`

---

## Submodules Empty After Clone

**Problem:** Service directories exist but are empty (no source code).

**Cause:** The repository was cloned without the `--recurse-submodules` flag.

**Solution:**

```bash
git submodule update --init --recursive
```

---

## Docker Compose Version Error

**Problem:** `docker-compose: command not found` or syntax errors in docker-compose.yml.

**Cause:** You have Docker Compose v1 (standalone `docker-compose`) instead of v2 (integrated `docker compose`).

**Solution:**

```bash
# Check your version
docker compose version

# If you get an error, you have v1. Upgrade Docker Desktop to get v2.
# As a workaround, some systems support:
docker-compose up -d    # v1 syntax (hyphen)
docker compose up -d    # v2 syntax (space) — preferred
```

Update Docker Desktop to the latest version to get Docker Compose v2.

---

## Out of Memory

**Problem:** Services crash, restart repeatedly, or Docker becomes unresponsive.

**Cause:** Docker Desktop doesn't have enough RAM allocated. The full stack needs ~4–6 GB.

**Solution:**

1. Open Docker Desktop → Settings → Resources
2. Set Memory to at least **6 GB** (8 GB recommended)
3. Click "Apply & Restart"
4. Restart services: `make restart`

---

## Services Keep Restarting

**Problem:** `docker compose ps` shows services in a restart loop.

**Cause:** Various — usually a configuration error or dependency issue.

**Solution:**

```bash
# Check which service is failing
docker compose ps

# Read the logs of the failing service
docker compose logs <service-name>

# Common culprits:
# - Database not ready → restart after postgres is healthy
# - Missing environment variables → check .env
# - Port conflicts → see "Port Already in Use" above
```

---

## Redis Connection Refused

**Problem:** `Redis::CannotConnectError` or `Error: NOAUTH Authentication required`

**Cause:** Redis password mismatch between `.env` and what Redis is configured with.

**Solution:**

```bash
# Verify the password in .env matches
grep REDIS_PASSWORD .env

# Restart Redis with the correct password
docker compose restart redis

# If the issue persists, stop everything, clear data, and restart
docker compose down -v
docker compose up -d
```

---

## CORS Errors in Browser

**Problem:** Browser console shows `Access-Control-Allow-Origin` errors.

**Cause:** The `CORS_ORIGINS` variable in `.env` doesn't include the URL you're accessing from.

**Solution:**

Edit `.env` and add your URL to `CORS_ORIGINS`:

```env
CORS_ORIGINS=http://localhost:3000,http://localhost:5173,http://127.0.0.1:5173
```

Then restart the CRM service:

```bash
docker compose restart evo-crm
```

---

## Still Stuck?

If your problem isn't listed here:

1. Search [existing issues](https://github.com/EvolutionAPI/evo-crm-community/issues)
2. Ask in [GitHub Discussions](https://github.com/EvolutionAPI/evo-crm-community/discussions)
3. [Open a bug report](https://github.com/EvolutionAPI/evo-crm-community/issues/new?template=bug_report.yml)
