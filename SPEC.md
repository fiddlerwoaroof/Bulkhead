# SPEC.md — Bulkhead

**Bulkhead** is a macOS-native Docker container management UI designed with clarity, performance, and an opinionated UX. This specification outlines the intended architecture, features, and behavior of the application, ensuring consistent implementation and guiding future development.

---

## Overview

Bulkhead is a SwiftUI-based macOS application for interacting with the local Docker daemon via the Docker Unix socket. It uses native Swift concurrency, custom socket handling, and minimal dependencies. The UI is built around a reusable generic `ListView` component providing consistent layout, selection, search, and focus management.

---

## Goals

- Provide a fast, responsive UI for managing Docker containers and images
- Allow inspection of logs, filesystem, metadata, and status
- Be visually clean and intuitive, styled like native Apple applications
- Avoid using Docker CLI or shelling out; use the HTTP API over UNIX socket
- Implement robust and conventional keyboard navigation and focus management

---

## Core Features

### Main Interface
- `TabView` for switching between primary sections (Containers, Images)
- Consistent master-detail layout provided by a generic `ListView` component within each tab

### Generic `ListView` Component
- Displays a list of items (`Identifiable`, `Equatable`)
- Renders items using a provided `content` view builder
- Displays details for the selected item using a provided `detail` view builder within a `NavigationSplitView`
- Integrated search field with filtering logic provided via `SearchConfiguration`
- Manages selection state (`selectedItem`)
- Manages focus state (`@FocusState`) between the search field and list items, persisting focus across view updates (e.g., tab switches) using an internal `@StateObject` (`ListViewState`)
- Handles keyboard navigation (Up/Down arrows, Escape, Enter) including interaction with the search field and list boundaries
- Debounces actions (scrolling, focus update) on selection change (100ms delay)

### Containers View (`ContainerListView`)
- Uses `ListView` to display all Docker containers
- Provides container-specific rendering for list items, including:
  - Name and image information
  - `StatusBadgeView` showing status (Up/Down)
  - `ContainerActionsView` with interactive buttons (Start / Stop / Logs)
- Provides `ContainerDetailView` for the detail pane
- Implements container-specific search filtering (name, image, status)

### Container Detail View (`ContainerDetailView`)
- Displays detailed metadata for the selected container
- Uses `@StateObject` (`ContainerDetailModel`) to load enriched details (command, ports, mounts, etc.) asynchronously using `.task(id: container.id)`
- *(Caching: Currently re-fetches details on selection; no explicit time-based caching implemented in view model.)*
- Integrates `FilesystemBrowserView`
- Logs are viewed in a separate window (`ContainerLogsView`) launched via the Logs button

### Images View (`ImageListView`)
- Uses `ListView` to display all Docker images
- Provides image-specific rendering for list items, including:
  - Repository/tags, size, created date, shortened ID
- Provides `ImageDetailView` for the detail pane
- Implements image-specific search filtering (tags, ID)

### Image Detail View (`ImageDetailView`)
- Displays detailed metadata for the selected image (Layers, Config, Labels, Parent ID, etc.)
- Uses `@StateObject` (`ImageDetailModel`) to load full image inspection details asynchronously using `.task(id: image.id)`
- Includes section for Raw Inspection Data (formatted JSON)

### Filesystem Browser (`FilesystemBrowserView`)
- Integrated into `ContainerDetailView`
- Requires the container to be running
- Uses `DockerExecutor.exec` to run `ls -AF` within the container
- Parses `ls` output to display `FileEntry` list (files, directories, symlinks)
- Supports directory navigation (clicking folders, `..` entry)
- Handles symbolic links (detects directory links before navigating)
- Debounces fetch operations on path changes (100ms delay)

### Logs View (`ContainerLogsView`)
- Presented in a separate window launched from `ContainerDetailView`
- Uses `SwiftTerm` library via `TerminalWrapper` (`NSViewRepresentable`)
- `LogFetcher` retrieves logs using `DockerExecutor.getContainerLogs` (tail only, no follow)
- Automatically selects raw or multiplexed log parsing based on container TTY status
- Displays historical logs; real-time streaming (`follow=true`) is not implemented

### Other Implemented Views
- `SearchField`: Reusable search input component
- `StatusBadgeView`: Displays container status pills
- `ContainerActionsView`: Holds action buttons for container rows
- `LogManager`: Handles internal application logging (to console/OSLog), not container logs

---

## Technical Architecture

### Swift Concurrency
- All network requests are `async` using `Task {}` blocks
- UI updates are dispatched to the `MainActor`
- Task management for debouncing UI updates (e.g., selection changes)
- `.task(id:)` modifier used for asynchronous data loading tied to view identity (e.g., selected item ID)

### Docker Connection
- Connects directly to Docker daemon over a Unix socket
- Defaults to checking common locations:
  - `~/.colima/docker.sock`
  - `~/.rd/docker.sock`
- Uses a custom `SocketConnection` for raw HTTP over UNIX socket

### Models
- `DockerContainer`, `DockerImage`, `ImageInspection`, `PortBinding`, `MountInfo`, `FileEntry` etc.
- Extendable via JSON decoding and enrichment logic
- Strong type safety and error handling are prioritized

### Data Management
- `DockerManager` (`ObservableObject`): Likely central point for holding container/image lists, triggering fetches, and providing access to `DockerExecutor`
- `DockerExecutor`: Handles low-level socket communication and Docker API requests
- Detail Views (`ContainerDetailModel`, `ImageDetailModel`): Use `@StateObject` to manage loading/state for individual item details

### UI (SwiftUI)
- `TabView` as the root container
- Generic `ListView` providing `NavigationSplitView`, search, selection, focus, and keyboard navigation
- Specific views (`ContainerListView`, `ImageListView`) configure and use `ListView`
- Focus Management: Uses `@FocusState` within `ListView`, persisted via an internal `@StateObject` (`ListViewState`) to maintain focus across tab switches
- Keyboard events (`.onKeyPress`) handle transitions between search and list items
- Styling:
  - Monospaced fonts for technical data (e.g., IDs)
  - Rounded cards with subtle shadows for list items
  - Selection indicated by background change and subtle border
  - Focus indicated by system focus ring

### Error Handling
- `DockerExecutor` functions `throw` errors (network, Docker API, container state)
- Detail view models catch errors during data loading and expose them via `@Published var error: Error?`
- Basic error display (`Text("Error: ...")`) implemented in detail views
- *(User-friendly, inline error surfacing is a goal but needs refinement)*

### Code Organization
*(Note: Keep this section updated when adding/moving files)*
- **Core Logic:**
  - `Bulkhead/Docker/DockerExecutor.swift`: Low-level Docker socket communication and API requests. Also contains the `DockerManager` class that manages application state and coordinates Docker actions.
  - `Bulkhead/Docker/Model.swift`: Core data structures (`DockerContainer`, `DockerImage`, etc.).
  - `Bulkhead/UI/DockerUIApp.swift`: Main application entry point, window setup, and scene definitions.
- **UI Components:**
  - `Bulkhead/UI/ContentView.swift`: Root view containing the `TabView`.
  - `Bulkhead/UI/ListView.swift`: Generic reusable list view component (handles layout, search, focus, nav, selection).
  - `Bulkhead/UI/ContainerListView.swift`: Specific implementation using `ListView` for containers.
  - `Bulkhead/UI/ImageListView.swift`: Specific implementation using `ListView` for images.
  - `Bulkhead/UI/ContainerDetailView.swift`: Detail view for containers.
  - `Bulkhead/UI/ImageDetailView.swift`: Detail view for images.
  - `Bulkhead/UI/SearchField.swift`: Reusable search text field.
  - `Bulkhead/UI/FilesystemBrowserView.swift`: View for browsing container filesystem.
  - `Bulkhead/UI/ContainerLogsView.swift`: View for displaying container logs (`SwiftTerm`).
  - `Bulkhead/UI/LogTableView.swift`: View for displaying log entries in a tabular format.
  - `Bulkhead/UI/SettingsView.swift`: View for user configuration settings.
  - `Bulkhead/UI/SettingsWindow.swift`: Window definition for settings.
- **Log Handling:**
  - `Bulkhead/Docker/LogFetcher.swift`: Logic to fetch logs using `DockerExecutor`.
  - `Bulkhead/Docker/DockerLogStreamParser.swift`: Parses multiplexed log streams.
  - `Bulkhead/Docker/DockerRawLogParser.swift`: Parses raw TTY log streams.
  - `Bulkhead/Docker/LogManager.swift`: Handles internal application logging.

---

## UX Principles

- No modal dialogs or blocking behavior
- Detail is always visible in context (master-detail)
- Errors are surfaced inline in a friendly format (Partially implemented)
- Color and layout should suggest functionality
- Consistent keyboard navigation patterns mimicking standard macOS apps (arrow keys, tab, escape, enter)
- Clear visual feedback for selection and focus

---

## Current Progress (Based on recent work & file review)

### Completed Features
- Basic container and image listing via generic `ListView`
- Container status display (`StatusBadgeView`)
- Container row actions (`ContainerActionsView` - buttons present, actions depend on `DockerManager`)
- Image row display
- Basic container and image detail view presentation (loading data via models)
- Filesystem browser (directory listing, navigation)
- Log viewer window (`SwiftTerm` based, displays historical logs)
- `NavigationSplitView` for master-detail presentation
- `TabView` for Containers/Images sections
- Integrated Search functionality within lists
- Keyboard navigation (Up/Down/Escape/Enter) between search and list items, respecting list boundaries
- Focus management, including persistence across tab switches
- Visual distinction between selected and focused items
- Debounced selection actions

### In Progress / To Verify
- `DockerManager` implementation details (caching strategy, detailed error handling, background refresh?)
- Container management actions (Start/Stop actual implementation and feedback)
- Log viewer real-time streaming
- Refined error display

### Planned Features (From TODO)
- Container creation, deletion, restart, rename
- Image pulling, deletion, tag management
- Advanced search/filtering
- Real-time log streaming, search, filtering, export
- Filesystem browser enhancements (upload/download)
- Docker Compose integration
- Performance optimizations (caching, background refresh)
- Documentation

---

## Refinements / Deviations from Initial Spec/Implementation

- **Generic `ListView`:** The UI architecture was refactored significantly to use a highly reusable generic `ListView` component, centralizing layout, search, selection, focus, and keyboard navigation logic. This wasn't explicitly detailed initially but emerged as a good practice.
- **Focus Persistence:** Achieving reliable focus persistence across tab switches required managing state within an `@StateObject` (`ListViewState`) internal to the `ListView`.
- **Row Focusability:** Making custom list rows focusable for keyboard navigation involved using the `.focusable(true)` modifier on the row's main layout container (`HStack`), coupled with the `.focused()` state binding.
- **Detail Loading:** Detail views use `@StateObject` view models and `.task(id:)` for asynchronous loading, rather than potentially simpler direct loading mentioned in early specs.
- **Log Viewing:** Implemented using `SwiftTerm` in a separate window, rather than potentially integrated into the detail view.

---

## Limitations

- Requires Docker socket access (no remote support yet)
- Container/Image *management* actions (create, delete, pull, etc.) are mostly pending implementation in `DockerManager`
- Log viewing does not yet support real-time streaming
- Filesystem browser is read-only (no upload/download/permission changes)
- Error reporting to the user is basic

---

## Future Directions

- *(Largely unchanged - see Planned Features)*
- Implement features outlined in `TODO.org`
- Refine error handling and reporting UI
- Add real-time log streaming
- Add filesystem modification capabilities
- Add comprehensive user documentation

---

## License & Attribution

Bulkhead is copyright (c) Edward Langley 2025. Source code is ApacheV2 licensed.

Name suggestions and product polish inspired by nautical terminology and professional tooling aesthetics.

---

End of SPEC.md

