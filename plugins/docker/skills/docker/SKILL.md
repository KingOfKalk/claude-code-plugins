---
name: docker
description: Manage Docker containers. Detects devcontainer environment and protects it from destructive actions.
argument-hint: "<action> [target], e.g. 'ps', 'logs myapp 100', 'exec myapp sh', 'stop myapp'"
disable-model-invocation: true
allowed-tools: Bash(docker ps:*), Bash(docker logs:*), Bash(docker exec:*), Bash(docker stop:*), Bash(docker start:*), Bash(docker rm:*), Bash(docker images:*), Bash(docker pull:*), Bash(docker build:*), Bash(docker inspect:*), Bash(docker stats:*), Bash(docker system:*), Bash(cat /proc:*), Bash(hostname:*), Bash(test -f:*)
---

# Docker Container Manager

Manage Docker containers with automatic devcontainer detection and self-protection.

## Current State

- Container environment: !`cat /proc/self/cgroup 2>/dev/null | grep -oE '[a-f0-9]{64}' | head -1 || cat /proc/1/cpuset 2>/dev/null | grep -oE '[a-f0-9]{64}' | head -1 || ([ -f /.dockerenv ] && hostname || echo "NOT_IN_CONTAINER")`
- Running containers: !`docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "DOCKER_UNAVAILABLE"`

## Safety Rules

> [!IMPORTANT]
> **DEVCONTAINER PROTECTION — applies only when running inside a container.**
>
> If Current State shows a container ID (not `NOT_IN_CONTAINER`), this skill is running inside a devcontainer. Before any destructive action (`exec`, `stop`, `rm`), verify the target is **not** this container:
>
> ```bash
> docker inspect --format '{{.Id}}' <target>
> ```
>
> Compare the result prefix against the detected container ID. If they match → **refuse the action** and explain why.
>
> If Current State shows `NOT_IN_CONTAINER`, no safety restrictions apply.

## Workflow

### 1. Parse the action

Extract the action and optional target from `$ARGUMENTS`:

| Argument pattern           | Command                                                                                  | Devcontainer guard          |
| -------------------------- | ---------------------------------------------------------------------------------------- | --------------------------- |
| `ps [--all]`               | `docker ps [--all] --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"`     | No                          |
| `logs <container> [lines]` | `docker logs --tail <lines\|50> <container>`                                             | No                          |
| `exec <container> [cmd]`   | `docker exec <container> <cmd\|sh>`                                                      | Yes — refuse if self        |
| `stop <container>`         | `docker stop <container>`                                                                | Yes — refuse if self        |
| `start <container>`        | `docker start <container>`                                                               | No                          |
| `rm <container>`           | `docker rm <container>`                                                                  | Yes — refuse if self        |
| `images`                   | `docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"` | No                          |
| `pull <image>`             | `docker pull <image>`                                                                    | No                          |
| `build [context]`          | `docker build <context\|.>`                                                              | No                          |
| `inspect <container>`      | `docker inspect <container>`                                                             | No                          |
| `stats [container]`        | `docker stats --no-stream [container]`                                                   | No                          |
| `prune`                    | `docker system prune`                                                                    | Ask user confirmation first |

If `$ARGUMENTS` is empty or unclear, run `ps` and ask what the user wants to do.

### 2. Detect environment

Check the container environment from Current State:

- If it shows a 64-character hex ID → running inside a devcontainer, apply guards
- If it shows `NOT_IN_CONTAINER` → running on host, no guards needed

### 3. Guard check (if needed)

For guarded actions (`exec`, `stop`, `rm`) when inside a devcontainer:

```bash
docker inspect --format '{{.Id}}' <target>
```

Compare the output prefix against the detected container ID. If they match, **refuse** and tell the user: "Cannot perform this action — the target is the devcontainer itself."

### 4. Execute

Run the command from the action table.

### 5. Report

- Whether the action succeeded or failed
- Any error output from the command
- For `prune`: show the space reclaimed

## Examples

```
/docker ps
/docker ps --all
/docker logs myapp 100
/docker exec myapp sh
/docker stop myapp
/docker start myapp
/docker rm old-container
/docker images
/docker pull nginx:latest
/docker build ./app
/docker inspect myapp
/docker stats
/docker prune
```
