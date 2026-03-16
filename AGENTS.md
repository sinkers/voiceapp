# AGENTS.md — Workflow Rules

All agents working on this repo must follow these rules. No exceptions.

## Branch Naming

Every task must be done on a feature branch named after the GitHub issue:

```
feature/issue-{number}-{short-description}
```

Examples:
- `feature/issue-2-tts-reset-fix`
- `feature/issue-9-swipe-navigation`

**Never commit directly to `main`.** PRs only.

## Before You Start

1. Check the GitHub issue for acceptance criteria — that's your definition of done
2. `git checkout main && git pull` — always branch from a fresh main
3. `git checkout -b feature/issue-{number}-{description}`

## Code Quality (required before pushing)

```bash
flutter analyze          # must be zero issues
flutter test             # all tests must pass
```

Fix all issues before opening a PR. Do not open a PR with failing tests or analyzer warnings.

## Tests

- Every bug fix must include a regression test
- Every new feature must include unit or widget tests covering the acceptance criteria
- Tests live in `test/` — mirror the `lib/` structure
- Run with `flutter test`
- **Test coverage must not decrease.** Check the test count before and after your changes. If your PR removes or skips tests, it will be rejected.

## Pull Requests

- Title: `[#issue-number] Brief description` — e.g. `[#2] Fix TTS reset() stopping active speech`
- Body must include:
  - What changed and why
  - How to test it
  - Checklist: `flutter analyze` ✅, `flutter test` ✅
- Link the issue: `Closes #N` in the PR body
- Keep PRs focused — one issue per PR

## Code Review

PRs are reviewed by a **different agent model** to the one that wrote the code:

| Author | Reviewer |
|--------|----------|
| Claude (any) | Gemini |
| Gemini | Claude |
| GPT / OpenAI | Claude or Gemini |
| Codex | Gemini or Claude |

Elysse coordinates review assignments. Do not merge your own PR.

## Merge

- Squash merge preferred for bug fixes and small features
- Merge commit acceptable for larger feature branches
- Delete the feature branch after merge

**A PR is not done until:**
1. CI is green (all checks passing)
2. All review comments are addressed (Gemini or human)
3. `mergeable` status is clean (no conflicts)

Do not consider a task complete, report it as finished, or move on to the next task until all three conditions are met. If CI is failing or comments are unaddressed, fix them before declaring done.

## Style

Follow the rules in `CLAUDE.md`:
- Zero `flutter analyze` issues
- No `print()` statements
- `const` constructors where possible
- `withValues(alpha: x)` not deprecated `withOpacity(x)`
