# Claude Code Setup — UrenReconstructie

Drop-in setup for the UrenReconstructie macOS project.

## Files

```
CLAUDE.md                                          # Project context, read at session start
.claude/skills/
├── swift-conventions/SKILL.md                     # Swift & SwiftUI patterns
├── grdb-database/SKILL.md                         # GRDB database patterns
├── claude-api-anonymized/SKILL.md                 # Anthropic API + privacy layer
├── toyness-macos-styling/SKILL.md                 # Brand colors, fonts, components
└── eventkit-calendar-import/SKILL.md              # Apple Calendar import
```

## How to use

1. Unzip into your project root (alongside `urenreconstructie-spec.md`)
2. Open the project in Claude Code
3. Claude Code reads `CLAUDE.md` automatically at session start
4. Skills are referenced from `CLAUDE.md` and loaded when relevant

## When to add more skills

Don't write skills upfront for code you haven't built yet. Add a skill when:
- Claude Code makes the same mistake twice in a domain you haven't covered
- A pattern emerges in your code that should be consistent everywhere
- You add a major dependency with non-obvious idioms (e.g., when you wire up PDFKit for export, write a `pdf-export` skill)

## When to update existing skills

When a convention in a skill turns out to be wrong or incomplete, update the skill file *first*, then have Claude Code apply it. Don't fix the same issue inline twice.
