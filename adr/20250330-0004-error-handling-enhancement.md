# ADR 0004: Enhance Error Handling

## Status
Proposed

## Date
2024-03-30

## Context
Current error handling in Bulkhead, primarily within `DockerManager`
and surfaced in detail views, is basic. It relies on a simple
`DockerError` enum and often displays raw error descriptions to the
user (e.g., `Text("Error: \(error.localizedDescription)")`).

This approach has several drawbacks:
- Errors lack specificity (e.g., distinguishing network errors from
  API errors).
- User messages are often technical and unhelpful.
- No recovery suggestions are provided.
- Error presentation is inconsistent across the UI.

Improving error handling is a key task in the Release Polish plan (ADR
0002) and is also identified as technical debt in `TODO.org`.

## Decision
We will enhance the error handling system across the application by:

1.  **Expanding `DockerError`:** Add more specific error cases to
    distinguish between different failure modes (e.g., connection
    refused, API error with status code, command execution failure,
    timeout, parsing error).
2.  **Implementing `LocalizedError`:** Make `DockerError` conform to
    `LocalizedError` to provide user-friendly descriptions
    (`errorDescription`) and recovery suggestions
    (`recoverySuggestion`).
3.  **Creating a Reusable `ErrorView`:** Develop a SwiftUI view
    (`ErrorView`) for consistent presentation of errors, incorporating
    the localized description and recovery suggestion.
4.  **Integrating `ErrorView`:** Update relevant UI components (e.g.,
    `ContainerDetailView`, `ImageDetailView`, potentially `ListView`
    for fetch errors) to use the new `ErrorView` for displaying errors
    caught in their respective view models or data loading processes.
5.  **Refining `DockerManager.tryCommand`:** Update the error catching
    in `DockerManager.tryCommand` (or similar background task
    handlers) to potentially log the detailed error while storing the
    user-facing `DockerError` for UI display.

## Consequences

### Positive
- **Improved User Experience:** Users receive clearer, more
  understandable error messages.
- **Better Troubleshooting:** Specific error types and recovery
  suggestions aid users (and developers) in diagnosing problems.
- **Consistent UI:** Error presentation becomes uniform across the
  application.
- **Enhanced Robustness:** More granular error handling allows for
  more tailored responses to failures.

### Negative
- **Increased Complexity:** The `DockerError` enum and associated
  logic will become more complex.
- **Development Effort:** Requires modifying error definitions, adding
  localized strings, creating a new view, and updating existing views.

### Neutral
- The fundamental error-catching mechanisms (e.g., `do-catch` blocks)
  remain similar.

## Implementation Checklist

- [x] **Expand `DockerError` Enum (`DockerExecutor.swift`)**
    - [x] Add cases for connection errors (e.g., `connectionFailed(Error)`).
    - [x] Add cases for API errors (e.g., `apiError(statusCode: Int, message: String)`).
    - [x] Add cases for parsing errors (e.g., `responseParsingFailed(Error)`).
    - [x] Add cases for timeout errors (e.g., `timeoutOccurred`).
    - [x] Review existing cases (`noExecutor`, `execFailed`, `invalidResponse`, `containerNotRunning`) for clarity and specificity.
- [x] **Conform `DockerError` to `LocalizedError`**
    - [x] Implement `errorDescription` for each case, providing a user-friendly summary.
    - [x] Implement `recoverySuggestion` for relevant cases (e.g., check socket path, restart Docker, check container status).
- [ ] **Create `ErrorView.swift`**
    - [ ] Design a SwiftUI view to display an error.
    - [ ] Include parameters for title (optional), `errorDescription`,
          and `recoverySuggestion`.
    - [ ] Style the view appropriately (e.g., using standard alert
          colors/icons).
- [ ] **Update Error Catching Logic**
    - [ ] Modify `catch` blocks in `DockerManager`, detail view models (`ContainerDetailModel`, `ImageDetailModel`), and potentially `FilesystemBrowserView` to:
        - Catch specific error types where possible.
        - Log detailed underlying errors if needed.
        - Store the user-facing `DockerError` (conforming to `LocalizedError`) in a `@Published`    property for the UI.
        - [ ] Ensure error responses are not cached (e.g., in `DockerManager.enrichContainer`).
- [ ] **Integrate `ErrorView` into UI**
    - [ ] Replace generic `Text("Error: ...")` displays in detail
          views with `ErrorView(error: publishedErrorProperty)`.
    - [ ] Consider adding error display for list fetching failures
          (e.g., overlay on `ListView`).
- [ ] **Testing**
    - [ ] Manually trigger different error conditions (e.g., invalid
          socket path, stop Docker daemon, invalid API requests) to
          verify error display.
    - [ ] Check that user-friendly messages and recovery suggestions
          appear correctly.
- [ ] **Update `TODO.org`:** Mark `Release Polish > Code Architecture
      Improvements > Error Handling Enhancement` subtasks as complete.
- [ ] **Update `adr/20250330-0002-bulkhead-release-polish.md`:** Mark
      the `Error Handling Enhancement` checklist items as complete.
