# Bulkhead

**Bulkhead** is a macOS-native UI for managing Docker containers. Built with SwiftUI, it offers a clean,
responsive interface for inspecting, starting, stopping, and exploring containers — no terminal required.

<img width="1908" alt="image" src="https://github.com/user-attachments/assets/ced6883a-54ca-4caf-8259-7dbfdec225f4" />


## Features

- **Visual Browsing:** Separate views for Docker Containers and Images using a consistent master-detail layout.
- **Inspection:** View detailed metadata, mounts, ports, environment variables, image layers, and raw JSON inspection results.
- **Historical Log Viewer:** Display past container logs (with ANSI color support) in a separate window. *Real-time streaming is planned.*
- **Filesystem Browser:** Navigate the filesystem of *running* containers (read-only).
- **Keyboard Navigation:** Robust focus management and keyboard shortcuts (arrows, escape, enter) for navigating lists and interacting with search, mimicking native macOS behavior.
- **Search:** Filter containers (by name, image, status) and images (by tag, ID).


<img width="1908" alt="image" src="https://github.com/user-attachments/assets/463905fe-6fd2-4608-ae1f-b04e7a8ba99f" />

<img width="600" alt="image" src="https://github.com/user-attachments/assets/4cb68a8c-6ed4-4e09-b834-80b118a97d6f" />

## Technical Highlights

- **Native macOS:** Built entirely with SwiftUI for a responsive, platform-integrated feel.
- **Direct Docker API Access:** Communicates directly with the Docker daemon via its Unix socket (no CLI dependency). Automatically detects and supports:
  - Docker Desktop (`/var/run/docker.sock`)
  - Colima (`~/.colima/docker.sock`)
  - Rancher Desktop (`~/.rd/docker.sock`)
- **Structured Error Handling:** Comprehensive `DockerError` system with localized descriptions and recovery suggestions.
- **Clean Architecture:** Separation of concerns with distinct `DockerExecutor` (low-level API), `DockerManager` (app state/coordination), and UI layers.

## Current Limitations

- **Management Actions Pending:** Creating, deleting, restarting, or renaming containers, and pulling or deleting images are not yet implemented.
- **Read-Only Filesystem:** The filesystem browser currently only allows viewing; file uploads/downloads are planned.
- **Historical Logs Only:** The log viewer shows past logs but does not yet stream logs in real-time.

## Planned Features

See [`TODO.org`](TODO.org) and [`SPEC.md`](SPEC.md) for a detailed breakdown of planned features and the current specification, including:
- Full container and image lifecycle management
- Real-time log streaming with search/filtering
- Filesystem modification capabilities
- Advanced search options
- Docker Compose integration
