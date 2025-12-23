# MindSync - GitHub Copilot Instructions

## Project Overview

MindSync is an iOS application that synchronizes **stroboscopic light** (flashlight or screen) with personal music to induce altered states of consciousness through **neural entrainment**.

**Safety First**: This app uses stroboscopic light that can trigger seizures in people with photosensitive epilepsy. Safety features and warnings are critical.

### Core Features
- 🎵 **Music Synchronization**: Beat detection and tempo analysis from the user's music library
- 💡 **Dual Light Sources**: Flashlight (intense) or screen (precise, colored)
- 🧘 **Entrainment Modes**: Alpha (relaxation), Theta (trip), Gamma (focus)
- 🎤 **Microphone Mode**: Works with streaming services
- 🛡️ **Safety First**: Epilepsy warnings, thermal management, fall detection

## Technology Stack

| Area | Technology |
|------|-----------|
| Language | Swift 5.9+ (async/await, @Observable) |
| UI | SwiftUI |
| Audio Analysis | AVFoundation + Accelerate (vDSP/FFT) |
| Light Control | AVCaptureDevice (Torch) + CADisplayLink |
| Minimum iOS | 17.0 |
| Architecture | Feature-based, Protocol-oriented |

## Project Structure

```
mindsync/
├── .github/                     # GitHub configuration
├── .specify/                    # Speckit Framework
│   ├── memory/
│   │   └── constitution.md      # Project constitution (read this!)
│   ├── scripts/                 # Automation scripts
│   └── templates/               # Documentation templates
├── specs/                       # Feature specifications
│   └── 001-audio-strobe-sync/   # Current feature
│       ├── spec.md              # User stories & requirements
│       ├── plan.md              # Technical plan
│       ├── research.md          # API research
│       └── data-model.md        # Swift data models
├── MindSync/                    # iOS app source code
├── MindSyncTests/               # Unit tests
└── MindSyncUITests/             # UI tests
```

## Constitutional Principles

**IMPORTANT**: Read `.specify/memory/constitution.md` before making significant changes. Key principles:

### I. Mobile-First User Value
Every decision MUST demonstrably improve value for end users on iPhone. Features are delivered in clear, incrementally deliverable user journeys.

### II. iOS-Native Architecture & Quality
- MUST use modern, native iOS technology stack (Swift + SwiftUI + Swift Concurrency)
- MUST run stably on iOS 17+
- MUST consider Apple Human Interface Guidelines and accessibility
- Target 60fps interactions

### III. Test-First & Continuous Quality
- New functionality MUST be test-driven (TDD-like)
- Write acceptance/component tests first, then implementation
- Automated build/test workflow MUST exist before release
- App MUST feel stable; crashes frustrate users quickly on mobile

### IV. Privacy, Security & Data Minimization
- MUST work on data minimization principle
- Only collect data necessary for core functions
- Sensitive/personal data MUST be stored locally and securely (Keychain, protected containers)
- NO silent failures - errors MUST be clearly shown in UI

### V. Simplicity, Focus & Maintainability
- Feature scope MUST stay focused
- Each new feature MUST demonstrate clear value
- Architectural decisions only when solving concrete problems
- Small, maintainable codebase for small team

## Development Workflow

### Specification Before Implementation
- Create lightweight specification for new features (see `specs/` directory)
- MUST include: core user stories, acceptance criteria, success metrics
- User stories MUST be prioritized (P1, P2, P3)
- Each story MUST be independently testable

### Planning & Architecture
- Create brief plan (`plan.md`) before implementation
- Document iOS architecture (View/Feature modules, data flow, persistence)
- Explicitly document dependencies to existing features
- Minimize dependencies where possible

### Tasks & Implementation
- Group tasks by user story and phase (Setup/Foundation/User Stories/Polish)
- Each story should be independently completable and testable
- Tests (Unit/UI/Integration) SHOULD be explicit for P1 and P2 stories
- If tests intentionally omitted, MUST document and justify

### Quality Gates
- Every merge MUST pass automated build/test run
- Larger architecture or UX changes SHOULD be documented
- Target app start < 2 seconds to first usable view
- Core interactions MUST run at ~60fps

## Language & Documentation

- **Primary Language**: German (documentation and comments in specs)
- **Code**: English (Swift code, variable names, comments)
- User-facing strings should be in German

## Safety Considerations

This app deals with stroboscopic light which poses health risks:

1. **Epilepsy Warnings**: MUST show prominent warnings before first use
2. **Thermal Management**: Flashlight can overheat - MUST monitor and limit
3. **Fall Detection**: Users close eyes - MUST detect falls/drops
4. **Frequency Limits**: MUST enforce safe frequency ranges
5. **Emergency Stop**: MUST be easily accessible

When working on light control or audio synchronization features, always consider safety implications.

## Key Files to Review

Before making changes, review:
- `.specify/memory/constitution.md` - Project principles and governance
- `specs/001-audio-strobe-sync/spec.md` - Current feature requirements
- `specs/001-audio-strobe-sync/plan.md` - Technical architecture
- `specs/001-audio-strobe-sync/quickstart.md` - Developer setup

## Testing

```bash
# Unit Tests
xcodebuild test -scheme MindSync -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# UI Tests
xcodebuild test -scheme MindSyncUITests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Common Patterns

### Swift Concurrency
- Use async/await for asynchronous operations
- Prefer structured concurrency over raw Task creation
- Use actors for shared mutable state

### SwiftUI
- Use @Observable for view models (iOS 17+)
- Prefer composition over inheritance
- Keep views small and focused

### Error Handling
- Use Result types for operations that can fail
- Never fail silently - always provide user feedback
- Errors MUST be clearly displayed in UI with retry options

## What to Avoid

- ❌ Don't add cross-platform frameworks (React Native, Flutter)
- ❌ Don't add tracking/analytics without justification
- ❌ Don't compromise on safety features
- ❌ Don't create features without specifications
- ❌ Don't skip tests for core functionality
- ❌ Don't use UIKit unless SwiftUI is insufficient

## When in Doubt

1. Check the constitution (`.specify/memory/constitution.md`)
2. Review existing specifications in `specs/`
3. Maintain consistency with existing code patterns
4. Prioritize user safety and data privacy
5. Keep changes minimal and focused

## Helpful Commands

```bash
# Navigate to project
cd /path/to/mindsync

# Open documentation
open specs/001-audio-strobe-sync/quickstart.md
open .specify/memory/constitution.md

# View project in Xcode
open MindSync.xcodeproj  # or .xcworkspace if present
```

---

**Project Status**: In Development (v0.1.0-dev)  
**License**: Proprietary - All rights reserved
