# Contributing to Evo CRM Community

Welcome! We're glad you're interested in contributing. This project is open source under the [Apache 2.0 License](LICENSE), and we welcome contributions of all kinds.

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) in all interactions.

## How to Contribute

### Reporting Bugs

Found a bug? [Open a bug report](https://github.com/EvolutionAPI/evo-crm-community/issues/new?template=bug_report.yml) using our issue template. Include as much detail as possible — steps to reproduce, expected vs actual behavior, and environment info.

### Requesting Features

Have an idea? [Submit a feature request](https://github.com/EvolutionAPI/evo-crm-community/issues/new?template=feature_request.yml). Describe the problem you're solving and your proposed solution.

### Asking Questions

Not sure about something? Start a thread in [GitHub Discussions](https://github.com/EvolutionAPI/evo-crm-community/discussions).

## Development Setup

See the [Quick Start Guide](docs/QUICK-START.md) for one-command local setup using `make setup` and Docker Compose.

## Making Changes

### 1. Fork and Clone

```bash
git clone https://github.com/<your-username>/evo-crm-community.git
cd evo-crm-community
git submodule update --init --recursive
```

### 2. Create a Branch

Use the following naming convention:

- `feat/description` — new features
- `fix/description` — bug fixes
- `docs/description` — documentation changes

```bash
git checkout -b feat/my-feature
```

### 3. Commit Your Changes

We encourage [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add user profile endpoint
fix: resolve auth token refresh issue
docs: update setup instructions
```

### 4. Submit a Pull Request

Push your branch and open a PR against `main`. Our [PR template](.github/PULL_REQUEST_TEMPLATE.md) will guide you through providing the necessary context.

- Ensure your changes pass local testing
- Update documentation if your change affects setup or usage
- Keep PRs focused — one concern per PR

## Project Structure

This is a **monorepo** that uses Git submodules for each service:

```
evo-crm-community/
├── evo-auth-service-community/    # Authentication service (submodule)
├── evo-ai-crm-community/         # CRM backend service (submodule)
├── evo-ai-frontend-community/    # Frontend application (submodule)
├── evo-ai-processor-community/   # Message processor (submodule)
├── evo-ai-core-service-community/# Core service (submodule)
├── docker-compose.yml            # Local development orchestration
├── Makefile                      # Development commands
└── setup.sh                      # One-command setup script
```

Each submodule is an independent repository. Changes to a specific service should be submitted to that service's repository. The monorepo handles orchestration, CI/CD, and shared documentation.

## Style Guidelines

Each service may have its own coding standards and linters. Defer to the conventions established in the service you're modifying. When in doubt, follow the patterns you see in existing code.

## License

By contributing, you agree that your contributions will be licensed under the [Apache 2.0 License](LICENSE).
