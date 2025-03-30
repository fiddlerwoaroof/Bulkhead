# ADR 20250330: Implement Keyboard Shortcuts Help Overlay

## Context

The application currently lacks a centralized interface for users to view and learn about available keyboard shortcuts. A command palette-style interface will enhance user experience by providing quick access to keyboard shortcuts and context-sensitive help.

## Decision

- Develop a new SwiftUI view component named `KeyboardShortcutsOverlay`.
- Integrate this component into the main application window, accessible via a dedicated keyboard shortcut (e.g., `Cmd + /`).
- The overlay will display a list of all available shortcuts, grouped by context (e.g., global, container management, image management).
- Implement a search bar within the overlay to filter shortcuts based on user input.
- Use `NotificationCenter` to manage the visibility of the overlay, allowing for decoupled communication between components.

## Consequences

- Users will have an improved understanding of available keyboard shortcuts, leading to more efficient navigation and operation within the application.
- The implementation will require additional UI components and state management logic, but it will significantly enhance the application's usability.

## Implementation Steps

1. **Create `KeyboardShortcutsOverlay` Component:**
   - [ ] Design the UI layout using SwiftUI, ensuring it is consistent with the application's existing design language.
   - [ ] Implement a list view to display shortcuts, with sections for different contexts.
   - [ ] Add a search bar to filter shortcuts dynamically.

2. **Integrate Overlay into Application:**
   - [ ] Add a new menu item or button to toggle the overlay's visibility.
   - [ ] Assign a global keyboard shortcut (e.g., `Cmd + /`) to open the overlay.

3. **Manage Overlay State with NotificationCenter:**
   - [ ] Use `NotificationCenter` to broadcast visibility changes of the overlay.
   - [ ] Ensure that components interested in the overlay's visibility can subscribe to these notifications and update accordingly.

4. **Document Shortcuts:**
   - [ ] Ensure all existing and new shortcuts are documented within the overlay.
   - [ ] Provide context-sensitive help for each shortcut, explaining its function and usage.

5. **Testing and Refinement:**
   - [ ] Test the overlay for usability and performance.
   - [ ] Gather user feedback and make necessary adjustments to improve the user experience. 