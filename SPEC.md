# SPEC.md — Bulkhead

**Bulkhead** is a macOS-native Docker container management UI designed with clarity, performance, and an opinionated UX. This specification outlines the intended architecture, features, and behavior of the application, ensuring consistent implementation and guiding future development.

---

## Overview

Bulkhead is a SwiftUI-based macOS application for interacting with the local Docker daemon via the Docker Unix socket. It uses native Swift concurrency, custom socket handling, and minimal dependencies.

---

## Goals

- Provide a fast, responsive UI for managing Docker containers and images.
- Allow inspection of logs, filesystem, metadata, and status.
- Be visually clean and intuitive, styled like native Apple applications.
- Avoid using Docker CLI or shelling out; use the HTTP API over UNIX socket.

---

## Core Features

### Containers View
- Displays list of all Docker containers (`GET /containers/json?all=true`).
- Each container card includes:
  - Name (first of `.Names[]`)
  - Image
  - Status
  - Action buttons (Start / Stop)
  - Logs button (opens new window)
- Supports selection to reveal a detail pane.

### Container Detail View
- Loaded lazily on selection with metadata enrichment (`GET /containers/{id}/json`).
- Includes:
  - Name, image, status
  - Created time
  - Executed command
  - Mounts (with source/destination)
  - Port bindings (host:port -> container:port)
  - Health status (if present)
- Details cached for 10 seconds (TTL).

### Filesystem Browser (inside container)
- Visible in detail view only for running containers.
- Interactive browser of container's filesystem via `exec`:
  - Commands run via `POST /containers/{id}/exec`
  - Default `ls -AF --color=never`
- Uses a custom `FileEntry` model:
  - Name
  - isDirectory
  - isSymlink
  - isExecutable
- Normalized paths and '..' navigation supported.

### Logs View
- Terminal-style log viewer using `SwiftTerm`.
- Supports ANSI color sequences (raw byte passthrough).
- Uses multiplexed Docker log format with stream decoding.
- Fetches logs with:
  - `GET /containers/{id}/logs?stdout=true&stderr=true&tail=100&follow=false`

### Images View
- List of all images (`GET /images/json`).
- Basic detail includes:
  - Repo tag (first of `.RepoTags[]`)
  - Size
  - Created date

---

## Technical Architecture

### Swift Concurrency
- All network requests are `async` using `Task {}` blocks.
- UI updates are dispatched on the main thread.

### Docker Connection
- Connects directly to Docker daemon over a Unix socket.
- Defaults to checking common locations:
  - `~/.colima/docker.sock`
  - `~/.rd/docker.sock`
- Uses a custom `SocketConnection` for raw HTTP over UNIX socket.

### Models
- `DockerContainer`, `DockerImage`, `MountInfo`, `PortBinding`, `FileEntry`.
- Extendable via JSON decoding and enrichment logic.

### UI
- `NavigationSplitView` for master-detail layout.
- `TabView` for switching between containers and images.
- Styling:
  - Monospaced fonts for technical data.
  - Rounded cards with subtle shadows.
  - Accent color used for selection and icon highlights.

---

## UX Principles

- No modal dialogs or blocking behavior.
- Detail is always visible in context.
- Errors are surfaced inline in a friendly format.
- Color and layout should suggest functionality (e.g., folders vs. symlinks).

---

## Limitations

- Requires Docker socket access (no remote support).
- Only reads container state; no creation or deletion.
- Filesystem browsing limited to what the container user can access.

---

## Future Directions

- Search/filter for containers/images.
- Real-time log streaming.
- Container creation & deletion.
- Compose file integration.
- Remote Docker hosts via SSH.

---

## License & Attribution

Bulkhead is copyright (c) 2025. Source code is MIT licensed.

Name suggestions and product polish inspired by nautical terminology and professional tooling aesthetics.

---

End of SPEC.md

