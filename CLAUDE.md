# UrenReconstructie — Project Context

> Read this file at the start of every session. It defines the rules of the road.

## What this is

Native macOS app (Swift / SwiftUI) for reconstructing hour registrations at the end of consulting projects. Pulls from fragmented sources (Apple Calendar, supplier exports, manual entry, AI suggestions). Output is a set of PDF/Excel attachments that match the invoice.

Spec lives in `urenreconstructie-spec.md` at project root. Skills live in `.claude/skills/`.

## Hard privacy rules (non-negotiable)

These are the reason this is a native app instead of a web app. Violating any of these defeats the entire point of the project:

1. **All client data stays local.** SQLite database, files, exports — everything in `~/Library/Application Support/UrenReconstructie/` or user-chosen Documents folder.
2. **Claude API gets anonymized data only.** No client names, no person names, no email addresses. Use the `AnonymizationService` (see `claude-api-anonymized` skill).
3. **API keys live in Keychain.** Never plaintext, never in UserDefaults, never logged.
4. **No telemetry, no analytics, no crash reporters that send anywhere.** Local logs only.
5. **No iCloud sync of the database.** Time Machine and manual export are the backup story.

If you find yourself adding a network call that sends real customer data anywhere except an anonymized payload to `api.anthropic.com`, stop and ask.

## Tech stack

- Swift 5.9+, SwiftUI, macOS 14+ (Sonoma)
- GRDB.swift (SQLite) — see `grdb-database` skill
- EventKit for Apple Calendar — see `eventkit-calendar-import` skill
- PDFKit for export
- URLSession for Claude API — see `claude-api-anonymized` skill
- No third-party UI libraries; pure SwiftUI

## Skills (read before working in their domain)

| Skill | When to read |
|---|---|
| `swift-conventions` | Before writing any Swift file |
| `grdb-database` | Touching DB schema, models, queries, migrations |
| `claude-api-anonymized` | Anything involving Claude API or anonymization |
| `macos-styling` | UI work, styling, reusable components |
| `eventkit-calendar-import` | Calendar import features |

## Working style

- Direct and action-oriented. Don't over-explain things the developer already knows.
- Bias toward shipping. Working > perfect.
- Matrix/grid layouts over list-based UIs for planning screens.
- Small, focused commits. Don't refactor unrelated code while implementing a feature.
- When unsure between two approaches, propose both briefly and let the developer decide. Don't pick the "safe" one silently.

## File organization

```
UrenReconstructie/
├── App/                  # App entry point, root scene
├── Models/               # GRDB record types
├── Database/             # DB setup, migrations, repositories
├── Features/             # One folder per feature, contains Views + ViewModels
│   ├── Projects/
│   ├── Matrix/
│   ├── Import/
│   ├── Reconstruction/
│   └── Export/
├── Services/             # CalendarService, ClaudeService, AnonymizationService, ExportService
├── Styling/              # Colors, Fonts, reusable styled components
└── Resources/            # Assets, Info.plist
```

One feature folder owns its UI + view model. Cross-cutting concerns go in `Services/`. Database queries that span features go in `Database/Repositories/`.

## Conventions quickref

- `struct` over `class` unless reference semantics are needed
- `@Observable` for view models (Swift 5.9+)
- Async/await over completion handlers
- `Result` only at API/IO boundaries; throws inside the app
- No force unwraps (`!`) outside of compile-time guarantees
- `// MARK: -` for sectioning longer files
- Dutch in user-facing strings, English in code/comments

## Commit style

`<area>: <imperative description>` — examples:
- `db: add Activiteit migration v3`
- `matrix: highlight ai_voorstel cells with accent border`
- `import: handle CSV with semicolon delimiter`

## What "done" looks like for a feature

1. Code compiles with no warnings
2. Manual smoke test passes (described in commit message)
3. No new force unwraps, no new `print()` left in code
4. Strings in Dutch where user-facing
5. Styling applied consistently via the `macos-styling` skill conventions

## Things to never do

- Hardcode API keys (use Keychain)
- Send real names/emails to Claude API (anonymize first)
- Use `UserDefaults` for sensitive data (Keychain or DB)
- Add `@MainActor` to data layer types (only on UI)
- Mix business logic into Views (extract to view model)
- Commit `Pods/` or `.xcuserstate` (check `.gitignore`)
