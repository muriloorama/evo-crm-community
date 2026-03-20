<!-- TODO: Add banner image -->

# Evo AI Community

> Open-source, self-hosted AI-powered CRM platform for multi-channel customer engagement.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/EvolutionAPI/evo-crm-community)](https://github.com/EvolutionAPI/evo-crm-community/releases)
[![Docker Image](https://img.shields.io/badge/Docker-ghcr.io-blue)](https://github.com/EvolutionAPI/evo-crm-community/pkgs/container/evo-crm-community)
[![GitHub stars](https://img.shields.io/github/stars/EvolutionAPI/evo-crm-community)](https://github.com/EvolutionAPI/evo-crm-community/stargazers)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## What is Evo AI Community?

Evo AI Community is the open-source edition of the Evo AI platform — a complete suite for AI-assisted customer support and CRM. It brings together authentication, CRM, AI agents, message processing, and a modern web frontend into a unified, self-hostable stack. Deploy it on your own infrastructure and own your data.

## Key Features

- **Multi-channel messaging** — WhatsApp, Telegram, Facebook, and more
- **AI-powered agents** — Automated conversations with LLM-based agents
- **CRM pipeline management** — Contacts, conversations, and inboxes
- **Real-time conversations** — WebSocket-powered live messaging
- **Multi-language support** — Serve customers in any language
- **Self-hosted & open source** — Full control, no vendor lock-in

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (React/Vite)                     │
│                      localhost:5173                          │
└──────┬──────────┬──────────────┬───────────────┬────────────┘
       │          │              │               │
       ▼          ▼              ▼               ▼
┌──────────┐ ┌─────────┐ ┌────────────┐ ┌─────────────┐
│   Auth   │ │   CRM   │ │    Core    │ │  Processor  │
│  :3001   │ │  :3000  │ │   :5555   │ │    :8000    │
│ Ruby/    │ │ Ruby/   │ │  Go/Gin   │ │  Python/    │
│ Rails    │ │ Rails   │ │           │ │  FastAPI    │
└────┬─────┘ └────┬────┘ └─────┬─────┘ └──────┬──────┘
     │            │            │               │
     └────────────┴────────────┴───────────────┘
                       │
          ┌────────────┴────────────┐
          │  PostgreSQL (pgvector)  │
          │        + Redis         │
          └────────────────────────┘
```

## Quick Start

```bash
# 1. Clone the repository
git clone --recurse-submodules https://github.com/EvolutionAPI/evo-crm-community.git
cd evo-crm-community

# 2. Configure environment
cp .env.example .env

# 3. Start services
docker compose up -d

# 4. Seed databases (~2 minutes)
make seed

# 5. Open http://localhost:5173 and login
```

> **First run takes ~5 minutes** (Docker image builds + database seeding).

For detailed step-by-step instructions, see the [Quick Start Guide](docs/QUICK-START.md).

### Default Credentials

| Field    | Value                                     |
|----------|-------------------------------------------|
| Email    | `support@evo-auth-service-community.com`  |
| Password | `Password@123`                            |

### Service URLs

| Service      | URL                      |
|--------------|--------------------------|
| Frontend     | http://localhost:5173    |
| CRM API      | http://localhost:3000    |
| Auth Service | http://localhost:3001    |
| Processor    | http://localhost:8000    |
| Core Service | http://localhost:5555    |
| Mailhog      | http://localhost:8025    |

## Documentation

- [Quick Start Guide](docs/QUICK-START.md) — Get running in 5 minutes
- [Setup Guide](docs/SETUP-GUIDE.md) — Detailed configuration and customization
- [Troubleshooting](docs/TROUBLESHOOTING.md) — Common issues and solutions
- [Contributing](CONTRIBUTING.md) — How to contribute
- [Changelog](CHANGELOG.md) — Release history

## Community

- **Bug reports** — [Open an issue](https://github.com/EvolutionAPI/evo-crm-community/issues/new?template=bug_report.yml)
- **Feature requests** — [Request a feature](https://github.com/EvolutionAPI/evo-crm-community/issues/new?template=feature_request.yml)
- **Questions & discussions** — [GitHub Discussions](https://github.com/EvolutionAPI/evo-crm-community/discussions)
- **Contributing** — Read our [Contributing Guide](CONTRIBUTING.md)

## License

This project is licensed under the [Apache License 2.0](LICENSE).

## Trademarks

"Evo AI" and associated logos are trademarks of Evo AI. See [TRADEMARKS.md](TRADEMARKS.md) for usage guidelines.
