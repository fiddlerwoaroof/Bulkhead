# ADR 0003: Refactor DockerManager out of DockerExecutor

## Status
Accepted

## Date
2024-03-30

## Context
Currently, the `DockerManager` class, which is responsible for
managing application state (container list, image list, settings) and
coordinating high-level Docker actions (fetch, start, stop), is
implemented within the same file
(`Bulkhead/Docker/DockerExecutor.swift`) as the `DockerExecutor`
class.

`DockerExecutor` is responsible for low-level communication with the
Docker daemon via the Unix socket and executing specific Docker API
requests.

Placing both classes in the same file violates the principle of
Separation of Concerns (SoC). `DockerManager` represents
application-level state and logic, while `DockerExecutor` handles the
transport and API execution layer. Combining them makes the file
overly long and couples distinct responsibilities, hindering
maintainability and testability.

This refactoring is identified as a high-priority task within the
Release Polish plan (ADR 0002).

## Decision
We will refactor the `DockerManager` class into its own dedicated
file, `Bulkhead/Docker/DockerManager.swift`.

This decision involves:
1.  Creating the new file `DockerManager.swift`.
2.  Moving the entire `DockerManager` class definition from
    `DockerExecutor.swift` to `DockerManager.swift`.
3.  Ensuring all necessary imports (e.g., `Foundation`, `SwiftUI`,
    `Combine`) are present in the new file.
4.  Verifying that references to `DockerManager` from other parts of
    the application (e.g., `DockerUIApp`, Views using
    `@EnvironmentObject`) remain correct or are updated if necessary.
5.  Ensuring `DockerManager` continues to have access to
    `DockerExecutor` (likely via instantiation as it currently does).

## Consequences

### Positive
- **Improved Separation of Concerns:** Clearly separates application
  state management from low-level API execution.
- **Enhanced Maintainability:** Makes both `DockerManager.swift` and
  `DockerExecutor.swift` smaller, more focused, and easier to
  understand and modify independently.
- **Increased Readability:** Improves code organization and makes it
  easier to locate relevant logic.
- **Better Testability:** Facilitates unit testing of `DockerManager`
  and `DockerExecutor` in isolation (though current setup might still
  require further refinement for full testability).

### Negative
- **Minimal Risk:** This is primarily a code organization refactoring
  with low risk of introducing functional regressions if
  import/reference updates are handled correctly.

### Neutral
- No change in application functionality is expected.

## Implementation Checklist

- [x] Create new file `Bulkhead/Docker/DockerManager.swift`.
- [x] Add necessary imports (`Foundation`, `SwiftUI`, `Combine`, etc.) to `DockerManager.swift`.
- [x] Cut the entire `DockerManager` class definition from `Bulkhead/Docker/DockerExecutor.swift`.
- [x] Paste the `DockerManager` class definition into `Bulkhead/Docker/DockerManager.swift`.
- [x] Verify that `DockerManager.swift` compiles successfully.
- [x] Verify that `DockerExecutor.swift` compiles successfully.
- [x] Review files that reference `DockerManager` (e.g., `DockerUIApp.swift`, `ContainerListView.swift`, `ImageListView.swift`, `ContainerDetailView.swift`, `SettingsView.swift`) to ensure they still compile and correctly reference the manager.
- [x] Build and run the application.
- [x] Test core functionality related to `DockerManager`:
    - [x] Fetching containers and images on launch.
    - [x] Auto-refreshing container/image lists.
    - [x] Displaying details (which involves `enrichContainer`).
    - [x] Starting/Stopping containers.
    - [x] Reading/Writing settings (Socket Path, Refresh Interval).
- [x] Update `TODO.org`: Mark `Release Polish > Code Architecture Improvements > DockerManager Refactoring` subtasks as complete.
- [x] Update `adr/20250330-0002-bulkhead-release-polish.md`: Mark the `DockerManager Refactoring` checklist items as complete.
