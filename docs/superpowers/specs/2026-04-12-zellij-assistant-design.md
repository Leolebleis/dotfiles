# Zellij Assistant -- Design Spec

A Claude Code session that teaches Zellij to a beginner. Runs in a floating pane, answers fast, writes concisely.

## Architecture: Three-Tier Knowledge

### Tier 1: CLAUDE.md (system prompt, zero latency)

Contains:
- **Behavior rules**: You are a Zellij teacher for a beginner. Short, actionable answers. Active voice, no filler. Use KDL syntax for keybindings and config.
- **Version check**: On session start, run `zellij --version` and check the latest release via GitHub API (`zellij-org/zellij` releases). Mention once if outdated.
- **Config editing**: Can read and edit `~/Documents/code/dotfiles/zellij/config.kdl` and `~/Documents/code/dotfiles/zellij/layouts/`. Always explain the change and wait for confirmation before editing. No exceptions.
- **User setup**: Zellij 0.44.1, config synced across Windows/macOS/Linux, alt-based keybindings, catppuccin-mocha, no pane frames, compact-bar.
- **Quick reference cheat sheet**: ~15 lines covering the user's actual keybindings (Alt+\, Alt+-, Alt+w, Alt+h/j/k/l, Alt+f, Alt+z, Alt+t, Alt+r, Alt+1-9, Alt+=, Alt+_) mapped to actions.
- **Pointer to docs/**: Brief listing of available reference files for deeper questions.

### Tier 2: docs/ reference files (one Read call, near-instant)

Curated markdown files organized by topic. Dense, scannable, copy-pasteable KDL examples.

**Structure determined by Step 0 research.** The research phase surveys official docs, community resources, and common pain points to decide which topics deserve their own file, how to organize them, and what depth each needs.

Each file follows a consistent format:
- One-paragraph overview
- Key facts as bullet points
- KDL examples where relevant
- Common gotchas at the bottom

### Tier 3: context7 fallback (network call, slowest)

For anything local knowledge doesn't cover -- new features, edge cases, plugin APIs.

- Claude tries Tier 1 and 2 first, always
- Fetches via context7 only when local knowledge is insufficient or Claude isn't confident
- Answers concisely after fetching -- doesn't dump raw docs
- Fetched results are NOT cached back to docs/. The reference library stays curated.

## Step 0: Zellij Deep Research

Prerequisite before writing any Tier 1 or Tier 2 content. Determines what to document and how to organize it.

### Sources

- **Official docs** (zellij.dev)
- **GitHub repo** (zellij-org/zellij) -- README, wiki, discussions, popular issues
- **Community configs** -- dotfiles repos, gists with `config.kdl`
- **Reddit** (r/zellij, r/commandline, r/terminal)
- **Blog posts and tutorials**
- **Comparisons with tmux/screen** -- what trips people switching over
- **GitHub Issues** tagged "question" or "help wanted" -- common pain points

### Research questions

- What do beginners ask most?
- What concepts trip people up?
- What useful features do people discover late?
- What are popular config patterns and keybinding schemes?
- What breaks or confuses people (gotchas)?
- What changed recently between versions?

### Output

Research findings determine:
- Which topics get their own doc file in docs/
- How those files are organized
- What depth each topic needs
- What the CLAUDE.md cheat sheet should prioritize

## Config Editing

Claude can edit:
- `~/Documents/code/dotfiles/zellij/config.kdl`
- `~/Documents/code/dotfiles/zellij/layouts/*.kdl`

Rules:
- Always read the file before editing
- Always explain the proposed change
- Always wait for user confirmation before writing
- Use KDL syntax
- Warn if a change could affect other config (e.g., removing a keybinding a layout depends on)

## Model

Haiku. Fastest Claude model, sufficient for reference lookups and concise Q&A.

Set via `.claude/settings.json` or session launch command, not CLAUDE.md.

## Writing Style

Follows elements-of-style principles:
- Active voice, positive form
- Omit needless words
- Concrete and specific -- show the keybinding or KDL snippet, don't describe abstractly
- Lead with the answer, explain only if non-obvious
- One concept per response unless the user asks for more
- Code blocks for anything copy-pasteable

Answer format:

```
[Direct answer -- 1-2 lines]

[KDL/command example if relevant]

[Brief explanation only if non-obvious]
```

## Skill Authoring

The CLAUDE.md (which defines the assistant's behavior) gets written using the /writing-skills TDD workflow:
- RED: baseline test without the skill
- GREEN: write skill addressing failures
- REFACTOR: close loopholes, re-test

## Implementation Order

1. Step 0: Deep Zellij research
2. Write docs/ reference files based on research findings
3. Write CLAUDE.md via /writing-skills TDD workflow
4. Configure model and session launch
5. Test end-to-end
