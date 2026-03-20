# Setup Guide

Complete guide for installing, configuring, and customizing Evo AI Community.

---

## Prerequisites

### Required Software

| Tool              | Minimum Version | Download                                                                 |
|-------------------|-----------------|--------------------------------------------------------------------------|
| **Docker Desktop** | 4.x+           | [Windows](https://docs.docker.com/desktop/install/windows-install/) · [Mac](https://docs.docker.com/desktop/install/mac-install/) · [Linux](https://docs.docker.com/desktop/install/linux/) |
| **Docker Compose** | v2.x+          | Included with Docker Desktop                                            |
| **Git**           | 2.x+            | [git-scm.com/downloads](https://git-scm.com/downloads)                 |

### Minimum System Requirements

- **RAM:** 8 GB (Docker Desktop should be allocated at least 6 GB)
- **Disk:** 20 GB free space
- **OS:** Windows 10/11 (WSL2), macOS 12+, or Linux (Ubuntu 22.04+, Debian 12+)

---

## Step-by-Step Setup

### 1. Clone the Repository

```bash
git clone --recurse-submodules https://github.com/EvolutionAPI/evo-crm-community.git
cd evo-crm-community
```

The `--recurse-submodules` flag downloads all 5 services at once. If you already cloned without it:

```bash
git submodule update --init --recursive
```

### 2. Create Your Environment File

```bash
cp .env.example .env
```

This creates a local `.env` file with sensible defaults. All values work out of the box for local development.

### 3. Build and Start

```bash
make setup
```

This single command will:
1. Copy `.env.example` to `.env` (if not already done)
2. Initialize Git submodules
3. Build Docker images for all services
4. Start infrastructure (PostgreSQL, Redis, Mailhog)
5. Wait for the database to be ready
6. Run database migrations and seed data for Auth and CRM
7. Start all application services

---

## Configuration Guide

The `.env` file is divided into sections. Below is what each section controls.

### Database (PostgreSQL)

| Variable            | Default               | Description                      |
|---------------------|-----------------------|----------------------------------|
| `POSTGRES_HOST`     | `postgres`            | Database hostname (Docker service name) |
| `POSTGRES_PORT`     | `5432`                | Database port                    |
| `POSTGRES_USERNAME` | `postgres`            | Database superuser               |
| `POSTGRES_PASSWORD` | `evoai_dev_password`  | Database password — **change in production** |
| `POSTGRES_DATABASE` | `evo_community`       | Database name                    |

### Redis

| Variable         | Default              | Description                    |
|------------------|----------------------|--------------------------------|
| `REDIS_URL`      | `redis://:evoai_redis_pass@redis:6379` | Connection URL          |
| `REDIS_PASSWORD` | `evoai_redis_pass`   | Redis password — **change in production** |

### Shared Secrets

These keys **must be identical** across all services. Pre-generated for development.

| Variable            | Description                                    |
|---------------------|------------------------------------------------|
| `SECRET_KEY_BASE`   | Rails cookie signing and encryption            |
| `JWT_SECRET_KEY`    | JWT token signing (must match SECRET_KEY_BASE) |
| `ENCRYPTION_KEY`    | Fernet key for API key storage                 |
| `EVOAI_CRM_API_TOKEN` | Service-to-service authentication token     |

> **Production:** Generate new values for all secrets. Never use the development defaults.

### Auth Service (Port 3001)

| Variable                    | Default          | Description                   |
|-----------------------------|------------------|-------------------------------|
| `RAILS_ENV`                 | `development`    | Rails environment mode        |
| `FRONTEND_URL`              | `http://localhost:5173` | Frontend URL for CORS   |
| `MAILER_SENDER_EMAIL`       | `noreply@evoai-community.local` | Outgoing email sender |
| `SMTP_ADDRESS`              | `mailhog`        | SMTP server (Mailhog in dev)  |
| `SMTP_PORT`                 | `1025`           | SMTP port                     |

### CRM Service (Port 3000)

| Variable                    | Default          | Description                      |
|-----------------------------|------------------|----------------------------------|
| `BACKEND_URL`               | `http://localhost:3000` | Public-facing CRM API URL |
| `CORS_ORIGINS`              | `http://localhost:3000,http://localhost:5173,...` | Allowed CORS origins |
| `LOG_LEVEL`                 | `info`           | Log verbosity (debug/info/warn/error) |

### Core Service (Port 5555)

| Variable              | Default          | Description                          |
|-----------------------|------------------|--------------------------------------|
| `DB_HOST`             | `postgres`       | Database host                        |
| `DB_SSLMODE`          | `disable`        | SSL mode (disable/require/verify-full) |
| `EVOLUTION_BASE_URL`  | `http://evo-crm:3000` | CRM service internal URL        |

### Processor Service (Port 8000)

| Variable                      | Default          | Description                       |
|-------------------------------|------------------|-----------------------------------|
| `POSTGRES_CONNECTION_STRING`  | `postgresql://...` | Full PostgreSQL connection URI  |
| `DEBUG`                       | `false`          | Enable verbose logging            |
| `CORE_SERVICE_URL`            | `http://evo-core:5555/api/v1` | Core service URL       |

### Frontend (Port 5173)

These are **build-time** variables — baked into the frontend during Docker build. They use `localhost` because the browser accesses services directly.

| Variable                   | Default                    | Description                  |
|----------------------------|----------------------------|------------------------------|
| `VITE_API_URL`             | `http://localhost:3000`    | CRM API URL (browser)       |
| `VITE_AUTH_API_URL`        | `http://localhost:3001`    | Auth API URL (browser)      |
| `VITE_EVOAI_API_URL`      | `http://localhost:5555`    | Core API URL (browser)      |
| `VITE_AGENT_PROCESSOR_URL`| `http://localhost:8000`    | Processor URL (browser)     |
| `VITE_WS_URL`             | `ws://localhost:3000/cable` | WebSocket URL (browser)    |

---

## Service Architecture

| Service     | Stack              | Port   | Role                                      |
|-------------|--------------------|--------|-------------------------------------------|
| Auth        | Ruby 3.4 / Rails   | 3001   | Authentication, RBAC, OAuth2, tokens      |
| CRM         | Ruby 3.4 / Rails   | 3000   | Conversations, contacts, inboxes          |
| Core        | Go / Gin           | 5555   | Agent management, API keys, folders       |
| Processor   | Python / FastAPI   | 8000   | AI agent execution, sessions, tools, MCP  |
| Frontend    | React / Vite       | 5173   | Web interface                             |
| Auth Sidekiq | Ruby 3.4 / Sidekiq | —     | Background jobs for Auth service          |
| CRM Sidekiq | Ruby 3.4 / Sidekiq | —      | Background jobs for CRM service           |
| PostgreSQL  | pgvector/pg16      | 5432   | Shared database with vector extensions    |
| Redis       | Redis Alpine       | 6379   | Caching, job queues, pub/sub              |
| Mailhog     | Mailhog            | 8025   | Development email capture (no real emails) |

### Service Dependencies

- **Auth** depends on: PostgreSQL, Redis
- **CRM** depends on: PostgreSQL, Redis, Auth (must be healthy)
- **Core** depends on: PostgreSQL
- **Processor** depends on: PostgreSQL, Redis
- **Frontend** depends on: Auth, CRM (must be healthy)

All inter-service communication uses Bearer token authentication. The token issued by the Auth service is forwarded between services automatically.

---

## First Login

1. Open **http://localhost:5173** in your browser
2. You'll see the login page — enter the default credentials:
   - **Email:** `support@evo-auth-service-community.com`
   - **Password:** `Password@123`
3. After login, you'll land on the Evo AI dashboard with a default inbox already configured
4. From the dashboard you can:
   - View and manage conversations in the **Inbox**
   - Add contacts in the **Contacts** section
   - Configure AI agents through the **Agents** menu
   - Manage settings in the **Settings** panel

<!-- screenshot: Evo AI login page with credentials filled in -->

<!-- screenshot: Evo AI dashboard showing the default inbox and sidebar navigation -->

<!-- screenshot: Settings panel showing available configuration options -->

---

## Customization

### Changing Ports

Edit `.env` and update the corresponding `VITE_*` variables, then rebuild:

```bash
# Example: Move CRM to port 4000
# In .env, set: BACKEND_URL=http://localhost:4000
# In .env, set: VITE_API_URL=http://localhost:4000
# In docker-compose.yml, change evo-crm ports to "4000:3000"

docker compose down
docker compose build evo-frontend
docker compose up -d
```

### Adding SSL (HTTPS)

For production, place a reverse proxy (nginx, Traefik, Caddy) in front of the services:

1. Update all `VITE_*` URLs in `.env` to use `https://yourdomain.com`
2. Update `FRONTEND_URL`, `BACKEND_URL`, and `CORS_ORIGINS`
3. Rebuild the frontend: `docker compose build evo-frontend`
4. Configure your reverse proxy to forward traffic to the appropriate ports

### Connecting a WhatsApp Channel

1. Uncomment the WhatsApp variables in `.env` (`WP_APP_ID`, `WP_VERIFY_TOKEN`, etc.)
2. Fill in your WhatsApp Cloud API credentials from [Meta for Developers](https://developers.facebook.com/)
3. Restart services: `make restart`
4. Configure the channel in the Evo AI dashboard

### Configuring SMTP (Real Emails)

By default, Mailhog captures all outgoing emails (no real emails sent). For production:

```env
SMTP_ADDRESS=smtp.yourprovider.com
SMTP_PORT=587
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
SMTP_USERNAME=your-email@example.com
SMTP_PASSWORD=your-smtp-password
MAILER_SENDER_EMAIL=noreply@yourdomain.com
```

Restart the Auth service after changes: `docker compose restart evo-auth evo-auth-sidekiq`

---

## Updating

To pull the latest changes:

```bash
# Pull monorepo updates
git pull

# Update all submodules to latest
git submodule update --remote

# Stop, rebuild, and restart
docker compose down
docker compose build
docker compose up -d
```

> **Tip:** Check the [CHANGELOG](../CHANGELOG.md) before updating to review what changed and whether there are breaking changes.

If there are database migrations, run seeds again:

```bash
make seed
```

---

## Stopping and Cleaning Up

```bash
# Stop all services (data preserved)
make stop

# Start again
make start

# Stop and remove all data (database, redis, etc.)
make clean
```

> **Warning:** `make clean` will delete all your data including the database. This cannot be undone.
