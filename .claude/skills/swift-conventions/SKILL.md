---
name: swift-conventions
description: Code style, file organization, and SwiftUI patterns for this project. Read before writing any Swift file. Covers naming, when to use struct vs class, @Observable view models, async/await usage, error handling, and common pitfalls to avoid.
---

# Swift & SwiftUI Conventions

## Naming

- **Types**: `PascalCase`. Suffix view models with `ViewModel`, services with `Service`, repositories with `Repository`.
- **Properties / functions**: `camelCase`. Boolean properties read as questions: `isLoading`, `hasUnsavedChanges`.
- **Files**: One primary type per file, filename matches the type. `ProjectListView.swift` contains `ProjectListView`.
- **Dutch in user-facing strings, English in code**: `Text("Nieuw project")` but `func createNewProject()`. Comments in English.

## Structs vs classes

Default to `struct`. Only use `class` for:
- Reference identity that must persist (rare)
- `@Observable` view models (Swift 5.9+ uses class under the hood)
- Bridging to Objective-C frameworks that require it

## View models with @Observable

```swift
import Observation

@Observable
final class ProjectListViewModel {
    private(set) var projects: [Project] = []
    private(set) var isLoading = false
    var searchQuery = ""

    private let repository: ProjectRepository

    init(repository: ProjectRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await repository.fetchAll()
        } catch {
            // log, show error state
        }
    }
}
```

Inject dependencies via `init`, never via singletons. `final class` for view models.

## State ownership in Views

- `@State` for view-local UI state (sheet visibility, text field input not yet committed)
- `@Bindable` for two-way binding to an `@Observable` model passed in
- `@Environment` for app-wide shared services (database, settings)
- Pass view models as `let` properties — the `@Observable` macro handles the reactivity

```swift
struct ProjectListView: View {
    @Bindable var viewModel: ProjectListViewModel
    @State private var showNewProjectSheet = false

    var body: some View { ... }
}
```

## Async / await

- All IO is async. Database calls, file reads, API calls.
- Top-level entry from UI: wrap in `Task { ... }` inside `.task` modifier or button action.
- Use `.task` over `.onAppear { Task { ... } }` — it cancels automatically on view disappear.
- `Task.detached` only when you specifically need to escape the current actor context.

## Error handling

- Throw inside the app. Convert to `Result` only at boundaries (e.g., when storing the last error in a view model).
- Define typed errors per service: `enum ImportError: Error { case invalidFormat, missingColumn(String) }`.
- Surface user-facing errors with Dutch messages via a `LocalizedError` conformance.
- Never silently `try?` away an error in production code paths. Log it at minimum.

## What to avoid

- Force unwrap (`!`) — use `guard let` or `if let`. Acceptable only for compile-time guarantees like `Bundle.main.url(forResource:...)!` for known assets.
- `print()` in committed code — use a logger (start with `os.Logger`, replace if needed).
- `@MainActor` on data layer types. Only put it on view models and views.
- Massive view bodies — extract subviews when one branch exceeds ~30 lines.
- `DispatchQueue.main.async` — use `await MainActor.run` or mark the function `@MainActor`.

## File structure within a feature folder

```
Features/Projects/
├── ProjectListView.swift
├── ProjectListViewModel.swift
├── ProjectDetailView.swift
├── ProjectDetailViewModel.swift
└── Components/
    └── ProjectRowView.swift
```

Subviews used by only one view stay in `Components/` next to it. Subviews reused across features go to a shared `UI/` folder.

## SwiftUI previews

Always provide previews for views. Use a stub repository that returns hardcoded data:

```swift
#Preview {
    ProjectListView(viewModel: ProjectListViewModel(repository: PreviewProjectRepository()))
}
```

Keep `PreviewProjectRepository` next to the real one in the Repositories folder, marked with `#if DEBUG`.

## Commit hygiene

- One logical change per commit
- Don't reformat code in the same commit as a feature change
- Don't fix lint warnings in unrelated files; do those in their own commit
