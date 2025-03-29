# SPEC.md — Bulkhead

**Bulkhead** is a macOS-native Docker container management UI designed with clarity, performance, and an opinionated UX. This specification outlines the intended architecture, features, and behavior of the application, ensuring consistent implementation and guiding future development.

---

## Overview

Bulkhead is a SwiftUI-based macOS application for interacting with the local Docker daemon via the Docker Unix socket. It uses native Swift concurrency, custom socket handling, and minimal dependencies.

---

## Goals

- Provide a fast, responsive UI for managing Docker containers and images
- Allow inspection of logs, filesystem, metadata, and status
- Be visually clean and intuitive, styled like native Apple applications
- Avoid using Docker CLI or shelling out; use the HTTP API over UNIX socket
- Support efficient keyboard navigation and focus management

---

## Core Features

### Containers View
- Displays list of all Docker containers
- Each container card includes:
  - Name and image information
  - Status badge (combined state and health)
  - Action buttons (Start / Stop)
  - Logs button
- Supports selection to reveal a detail pane
- Real-time status updates
- Search and filter capabilities

### Container Detail View
- Loaded lazily on selection with metadata enrichment
- Includes:
  - Name, image, status
  - Created time
  - Executed command
  - Mounts and port bindings
  - Health status
- Details cached for 10 seconds (TTL)

### Filesystem Browser
- Visible in detail view for running containers
- Interactive browser of container's filesystem
- Supports:
  - Directory navigation
  - File inspection
  - Path normalization
  - Parent directory navigation

### Logs View
- Terminal-style log viewer
- Supports ANSI color sequences
- Uses multiplexed Docker log format
- Configurable log fetching options

### Images View
- List of all Docker images
- Basic detail includes:
  - Repository and tags
  - Size
  - Created date
- Search and filter capabilities

---

## Technical Architecture

### Swift Concurrency
- All network requests are `async` using `Task {}` blocks
- UI updates are dispatched on the main thread
- Efficient state management and updates

### Docker Connection
- Connects directly to Docker daemon over a Unix socket
- Defaults to checking common locations:
  - `~/.colima/docker.sock`
  - `~/.rd/docker.sock`
- Uses a custom `SocketConnection` for raw HTTP over UNIX socket

### Models
- `DockerContainer`, `DockerImage`, `MountInfo`, `PortBinding`, `FileEntry`
- Extendable via JSON decoding and enrichment logic
- Strong type safety and error handling

### UI
- `NavigationSplitView` for master-detail layout
- `TabView` for switching between containers and images
- Styling:
  - Monospaced fonts for technical data
  - Rounded cards with subtle shadows
  - Accent color used for selection and icon highlights

---

## UX Principles

- No modal dialogs or blocking behavior
- Detail is always visible in context
- Errors are surfaced inline in a friendly format
- Color and layout should suggest functionality
- Consistent keyboard navigation patterns
- Clear visual feedback for user actions

---

## Current Progress

### Completed Features
- Basic container and image listing
- Container status display
- Filesystem browser
- Log viewing
- Keyboard navigation
- Focus management
- Search functionality

### In Progress
- Container management (create, delete, restart)
- Advanced search and filtering
- Real-time log streaming
- Image management

### Planned Features
- Docker Compose integration
- Remote Docker host support
- Performance optimizations
- Documentation

---

## Limitations

- Requires Docker socket access (no remote support)
- Only reads container state; no creation or deletion
- Filesystem browsing limited to what the container user can access
- No support for Docker Compose
- Limited to local Docker daemon

---

## Future Directions

- Container creation and management
- Docker Compose integration
- Remote Docker hosts via SSH
- Advanced container configuration
- Performance optimizations
- Comprehensive documentation

---

## License & Attribution

Bulkhead is copyright (c) 2025. Source code is MIT licensed.

Name suggestions and product polish inspired by nautical terminology and professional tooling aesthetics.

---

End of SPEC.md

