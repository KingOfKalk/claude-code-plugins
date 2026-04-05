---
name: docker-compose
description: Manage Docker Compose services. Detects devcontainer environment and applies safety constraints to protect the dev stack.
argument-hint: "<action> [service], e.g. 'status', 'rebuild backend', 'logs api 100', 'health'"
disable-model-invocation: true
allowed-tools: Bash(docker compose:*), Bash(docker inspect:*), Bash(cat /proc:*), Bash(hostname:*), Bash(test -f:*)
---

# Docker Compose Service Manager

Manage Docker Compose services with automatic devcontainer detection and safety constraints.

## Current State

- Container environment: !`cat /proc/self/cgroup 2>/dev/null | grep -oE '[a-f0-9]{64}' | head -1 || cat /proc/1/cpuset 2>/dev/null | grep -oE '[a-f0-9]{64}' | head -1 || ([ -f /.dockerenv ] && hostname || echo "NOT_IN_CONTAINER")`
- Compose services: !`docker compose ps --format "table {{.Name}}\t{{.Service}}\t{{.Status}}\t{{.Health}}\t{{.Ports}}" 2>/dev/null || echo "NO_COMPOSE_PROJECT"`
- Available services: !`docker compose config --services 2>/dev/null || echo "NO_COMPOSE_PROJECT"`

## Safety Rules

> [!IMPORTANT]
> **DEVCONTAINER PROTECTION — applies only when running inside a container.**
>
> If Current State shows a container ID (not `NOT_IN_CONTAINER`), this skill is running inside a devcontainer.
>
> **When inside a devcontainer:**
>
> - `docker compose down` — **BLOCKED**. Refuse and explain: this tears down the entire stack including the devcontainer network.
> - `docker compose up` — **must** use `--no-deps -d` and specify a service name. Never run bare `up`.
> - `docker compose restart` / `stop` — **must** specify an explicit service name. Never restart/stop all.
> - Before `stop`, `restart`, or `rebuild` — verify the target service's container is **not** the devcontainer:
>   ```bash
>   docker inspect --format '{{.Id}}' <service-container>
>   ```
>   Compare prefix against the detected container ID. If match → **refuse**.
> - `--follow` on logs — **forbidden** (blocks terminal). Always use `--tail`.
>
> **When outside a devcontainer (`NOT_IN_CONTAINER`):**
>
> No safety restrictions apply. All commands run normally.

## Workflow

### 1. Check for compose project

If Current State shows `NO_COMPOSE_PROJECT`:
- For `status`: Report no Docker Compose project found in the current directory.
- For any other action: Tell the user there is no compose project and suggest checking the directory.
- Do not run any compose commands.

### 2. Parse the action

Extract the action and optional service from `$ARGUMENTS`:

| Argument pattern | Inside devcontainer | Outside devcontainer |
|---|---|---|
| `status` | `docker compose ps` | Same |
| `up [service]` | Require `--no-deps -d` + service name | `docker compose up -d [service]` |
| `down` | **BLOCKED** — refuse, explain risk | `docker compose down` |
| `rebuild <service>` | `docker compose up -d --no-deps --build <service>` | `docker compose up -d --build [service]` |
| `restart <service>` | Require explicit service, verify not self | `docker compose restart [service]` |
| `stop <service>` | Require explicit service, verify not self | `docker compose stop [service]` |
| `logs <service> [lines]` | `docker compose logs --tail <lines\|50> <service>` | Same |
| `pull [service]` | `docker compose pull [service]` | Same |
| `config` | `docker compose config` | Same |
| `health [service]` | Health status via `docker inspect` | Same |

If `$ARGUMENTS` is empty or unclear, show `status` and ask what the user wants to do.

### 3. Validate service

If the action targets a specific service, verify it exists against the Available services list from Current State. If not found, show the list of valid services.

### 4. Detect environment

Check the container environment from Current State:
- 64-character hex ID → inside devcontainer, apply safety rules
- `NOT_IN_CONTAINER` → on host, no restrictions

### 5. Guard check (if needed)

For destructive actions (`stop`, `restart`, `rebuild`) when inside a devcontainer:

```bash
docker inspect --format '{{.Id}}' <service-container>
```

Compare prefix against detected container ID. If match → **refuse** and explain.

### 6. Execute

Run the appropriate command from the action table.

For `health [service]`:
```bash
docker inspect --format '{{.State.Health.Status}}' <container>
docker inspect --format '{{range .State.Health.Log}}{{.Output}}{{end}}' <container>
```

### 7. Verify and report

- Whether the action succeeded or failed
- Current status of the affected service(s)
- Any error output

On failure: show last 50 lines of service logs:
```bash
docker compose logs --tail 50 <service>
```

If a health check exists and status is unhealthy, show the health check log via `docker inspect`.

## Notes

- **`restart` does NOT pick up config changes.** If the user mentions config or environment changes, suggest `rebuild` instead — it rebuilds the image and recreates the container.

## Examples

```
/docker-compose status
/docker-compose rebuild backend
/docker-compose logs api 100
/docker-compose restart worker
/docker-compose stop redis
/docker-compose up frontend
/docker-compose down
/docker-compose pull
/docker-compose config
/docker-compose health api
```
