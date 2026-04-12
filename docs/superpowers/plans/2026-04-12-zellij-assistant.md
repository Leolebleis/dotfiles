# Zellij Assistant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code session that teaches Zellij to a beginner, with three-tier local-first knowledge and concise answers.

**Architecture:** Three knowledge tiers -- CLAUDE.md cheat sheet (instant), curated docs/ reference files (one file read), context7 fallback (network). Research phase determines doc structure before any writing. CLAUDE.md authored via /writing-skills TDD.

**Tech Stack:** Markdown, KDL (Zellij config syntax), Claude Code settings, context7 MCP

---

## Task 1: Research -- Official Documentation

Scrape and synthesize the official Zellij docs. Save raw findings to a research file that later tasks reference.

**Files:**
- Create: `docs/superpowers/research/official-docs.md`

- [ ] **Step 1: Fetch Zellij documentation via context7**

Use context7 to resolve the Zellij library ID, then fetch documentation covering: core concepts (panes, tabs, sessions, floating panes, modes), configuration (KDL syntax, keybinds, themes, UI options), layouts (KDL layout syntax, templates, default layouts), plugins (built-in plugins, plugin system), CLI commands, and session management (attach, detach, resurrect).

- [ ] **Step 2: Fetch Zellij changelog and recent releases**

Use GitHub API to fetch releases from `zellij-org/zellij`. Focus on:
- What changed between 0.40 and 0.44.1 (user's version)
- Breaking changes
- New features users should know about

```bash
gh api repos/zellij-org/zellij/releases --paginate --jq '.[0:10] | .[] | "## " + .tag_name + "\n" + .body + "\n"'
```

- [ ] **Step 3: Write official-docs.md**

Synthesize findings into `docs/superpowers/research/official-docs.md` with these sections:

```markdown
# Zellij Official Docs -- Research Notes

## Core Concepts
[bullet points: panes, tabs, sessions, modes, floating vs tiled]

## Configuration
[KDL syntax patterns, keybind structure, theme system, UI options]

## Layouts
[KDL layout syntax, pane templates, tab sections, startup commands]

## Plugins
[built-in plugins, plugin system, how they work]

## CLI Commands
[key commands: attach, detach, list-sessions, setup, etc.]

## Recent Changes (0.40-0.44.1)
[breaking changes, new features, deprecations]
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/research/official-docs.md
git commit -m "research: scrape official Zellij docs and changelog"
```

---

## Task 2: Research -- Community Knowledge

Gather pain points, tips, popular configs, and beginner questions from community sources.

**Files:**
- Create: `docs/superpowers/research/community.md`

- [ ] **Step 1: Search Reddit for beginner questions and pain points**

Search these subreddits for Zellij-related posts:
- r/zellij -- dedicated subreddit
- r/commandline -- "zellij" posts
- r/terminal -- "zellij" posts

Look for:
- "How do I..." questions (beginner gaps)
- "I switched from tmux" posts (transition pain)
- "TIL" or tip posts (late-discovered features)
- Config-sharing posts (popular patterns)

- [ ] **Step 2: Search GitHub Issues for common questions**

```bash
gh search issues --repo zellij-org/zellij --label "question" --sort "reactions-+1" --limit 30 --json title,url,labels,body
```

Also search discussions:
```bash
gh api repos/zellij-org/zellij/discussions --jq '.[0:20] | .[] | "## " + .title + "\n" + .body[0:200] + "\n"'
```

Look for: frequently asked questions, confusion about modes, keybinding issues, layout questions, session management confusion.

- [ ] **Step 3: Search for popular Zellij configs**

Web search for:
- "zellij config.kdl" site:github.com
- "zellij dotfiles" popular repos
- "best zellij keybindings"
- "zellij tmux comparison keybindings"

Capture: common keybinding schemes, popular theme setups, layout patterns, plugin configurations.

- [ ] **Step 4: Search for blog posts and tutorials**

Web search for:
- "zellij tutorial beginner"
- "getting started with zellij"
- "zellij tips and tricks"
- "switching from tmux to zellij"

Capture: what tutorials cover first (priority topics), what they warn about (gotchas), what gets the most engagement.

- [ ] **Step 5: Write community.md**

Synthesize all findings into `docs/superpowers/research/community.md`:

```markdown
# Zellij Community Research

## Top Beginner Questions
[ranked list of most-asked questions with sources]

## Common Pain Points
[what confuses or frustrates new users]

## Late-Discovered Features
[features people wish they knew about sooner]

## Popular Config Patterns
[keybinding schemes, theme setups, layout patterns with examples]

## tmux Migration Gotchas
[what trips people switching from tmux]

## Gotchas and Warnings
[things that break, confuse, or have unexpected behavior]
```

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/research/community.md
git commit -m "research: gather Zellij community knowledge and pain points"
```

---

## Task 3: Determine docs/ Structure

Analyze research findings and decide which topics deserve their own reference file.

**Files:**
- Read: `docs/superpowers/research/official-docs.md`
- Read: `docs/superpowers/research/community.md`
- Create: `docs/superpowers/research/structure-decision.md`

- [ ] **Step 1: Read both research files**

Read `docs/superpowers/research/official-docs.md` and `docs/superpowers/research/community.md` in full.

- [ ] **Step 2: Identify topic clusters**

Group research findings into topic clusters. For each potential topic, note:
- How often it appeared in beginner questions (frequency)
- How complex the topic is (depth needed)
- Whether it has KDL syntax the user will need to reference (copy-paste value)

- [ ] **Step 3: Write structure-decision.md**

Document the decision in `docs/superpowers/research/structure-decision.md`:

```markdown
# docs/ Structure Decision

## Topic Analysis

| Topic | Beginner Frequency | Depth Needed | KDL Examples | Verdict |
|-------|-------------------|--------------|--------------|---------|
| [topic] | high/medium/low | shallow/medium/deep | yes/no | own file / merge into X / skip |

## Chosen Structure

docs/
  [filename].md -- [one-line description of what it covers]
  [filename].md -- ...

## CLAUDE.md Cheat Sheet Priorities

Top items for the ~15-line cheat sheet (most-asked, most-useful):
1. [item]
2. ...

## Rationale

[Why this structure, what was merged, what was cut]
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/research/structure-decision.md
git commit -m "research: decide docs/ structure from findings"
```

---

## Task 4: Write docs/ Reference Files

Create each reference file determined by Task 3. Each file follows the same format.

**Files:**
- Read: `docs/superpowers/research/structure-decision.md` (for file list)
- Read: `docs/superpowers/research/official-docs.md` (for content)
- Read: `docs/superpowers/research/community.md` (for gotchas and priorities)
- Create: `docs/[each file determined by Task 3]`

- [ ] **Step 1: Read structure-decision.md for the file list**

Get the exact filenames and topic scopes from the structure decision.

- [ ] **Step 2: Write each reference file**

For each file in the structure decision, create it in `docs/` following this format:

```markdown
# [Topic Name]

[One-paragraph overview of the topic.]

## Key Facts

- [Bullet point facts, dense and scannable]
- [Prefer concrete over abstract]

## Examples

[KDL code blocks where relevant, copy-pasteable]

## Gotchas

- [Things that break, confuse, or behave unexpectedly]
- [Sourced from community research]
```

Content sourced from `official-docs.md` for accuracy, `community.md` for gotchas and priorities. Write in elements-of-style: active voice, omit needless words, concrete and specific.

- [ ] **Step 3: Cross-reference check**

Read all docs/ files and verify:
- No topic is covered in two files (no duplication)
- No topic from the structure decision is missing
- KDL examples use syntax consistent with the user's Zellij 0.44.1
- Every gotcha from community research landed somewhere

- [ ] **Step 4: Commit**

```bash
git add docs/*.md
git commit -m "docs: write Zellij reference files from research"
```

---

## Task 5: Write CLAUDE.md via /writing-skills TDD

Author the CLAUDE.md (the assistant's behavior definition) using the /writing-skills RED-GREEN-REFACTOR workflow.

**Files:**
- Modify: `CLAUDE.md`
- Read: `docs/superpowers/research/structure-decision.md` (for cheat sheet priorities)
- Read: `~/Documents/code/dotfiles/zellij/config.kdl` (for actual keybindings)

- [ ] **Step 1: RED -- Define pressure scenarios**

Write 3+ test scenarios that a beginner Zellij user would ask. These are the "failing tests" -- run them against a blank/minimal CLAUDE.md to establish baseline behavior.

Scenarios must cover:
1. **Basic question**: "How do I split a pane?" -- should answer with the user's actual keybinding (Alt+\ or Alt+-), not generic Zellij defaults
2. **Config editing**: "Can you add a keybinding for X?" -- should explain the change and wait for confirmation, not just edit
3. **Deep topic**: "How do sessions work?" -- should read a docs/ file, not hallucinate or give a vague answer
4. **Version check**: First message in a session -- should check `zellij --version` and compare to latest
5. **Out-of-scope**: Question not covered locally -- should fall back to context7, not guess

- [ ] **Step 2: RED -- Run baseline test**

Dispatch a subagent with only the current minimal CLAUDE.md. Give it each scenario. Document verbatim:
- What the agent answered
- What it got wrong
- What rationalizations it used (e.g., guessed keybindings, skipped version check, edited without asking)

- [ ] **Step 3: GREEN -- Write CLAUDE.md**

Write the full CLAUDE.md addressing every baseline failure. Structure:

```markdown
# Zellij Help

[Behavior rules section -- addresses failures from baseline]

## On Session Start

[Version check instructions]

## User's Setup

[Current setup details from config.kdl]

## Quick Reference

[~15 line cheat sheet from structure-decision.md priorities, using actual keybindings from config.kdl]

## Config Editing

[Rules: read first, explain, wait for confirmation]

## Reference Files

[List of docs/ files and what each covers]

## Fallback

[context7 instructions for questions not covered locally]
```

- [ ] **Step 4: GREEN -- Run scenarios with new CLAUDE.md**

Dispatch a subagent with the new CLAUDE.md and all docs/ files available. Run the same scenarios. Verify the agent now:
- Uses the user's actual keybindings
- Checks version on first message
- Reads docs/ for deep topics
- Asks before editing config
- Falls back to context7 for unknown topics

- [ ] **Step 5: REFACTOR -- Close loopholes**

If the agent found new ways to violate the rules (new rationalizations), add explicit counters to CLAUDE.md. Re-test until solid.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "feat: write CLAUDE.md via TDD -- Zellij teaching assistant"
```

---

## Task 6: Configure Model and Settings

Set up haiku as the default model for this project.

**Files:**
- Create: `.claude/settings.json`

- [ ] **Step 1: Create .claude/settings.json**

```json
{
  "model": "haiku"
}
```

- [ ] **Step 2: Verify the setting works**

Start a new Claude session in this directory and confirm it uses haiku. Check with a simple question like "what model are you?"

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "config: set haiku as default model for fast answers"
```

---

## Task 7: End-to-End Test

Test the complete assistant with realistic beginner questions.

**Files:**
- Read: all docs/ files
- Read: `CLAUDE.md`
- Read: `.claude/settings.json`

- [ ] **Step 1: Test Tier 1 (cheat sheet) answers**

Start a fresh session. Ask questions the cheat sheet covers:
- "How do I split a pane to the right?"
- "How do I close this pane?"
- "How do I switch tabs?"

Verify: answers are instant (no tool calls), use the user's actual keybindings, concise format.

- [ ] **Step 2: Test Tier 2 (docs/) answers**

Ask deeper questions:
- "Explain how sessions work"
- "How do I write a layout file?"
- "What are Zellij modes?"

Verify: Claude reads the right docs/ file, answers are thorough but concise, KDL examples are correct.

- [ ] **Step 3: Test Tier 3 (context7) fallback**

Ask something the local docs don't cover:
- A question about a niche plugin
- A question about a feature added after the docs were written

Verify: Claude recognizes the gap, fetches via context7, answers concisely.

- [ ] **Step 4: Test config editing**

Ask: "Can you add a keybinding for detaching the session?"

Verify: Claude reads config.kdl, explains the proposed change, waits for confirmation before editing.

- [ ] **Step 5: Test version check**

Start a fresh session and send a first message.

Verify: Claude checks `zellij --version` and mentions whether it's current or outdated.

- [ ] **Step 6: Test writing style**

Review all answers from steps 1-5 against elements-of-style criteria:
- Active voice throughout
- No filler words
- Answers lead with the answer, not preamble
- Code blocks for copy-pasteable content
- One concept per response

- [ ] **Step 7: Fix any issues found and commit**

If any tests revealed problems, fix the relevant file (CLAUDE.md or docs/) and re-test that scenario.

```bash
git add -A
git commit -m "test: end-to-end validation and fixes"
```
