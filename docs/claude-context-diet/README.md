# Claude Code context diet

How much of Claude Code's initial context you can actually remove, measured
rather than guessed. Every number here came from a fresh headless session on
this machine (`claude -p "hi"`), reading the first `usage` record out of the
session transcript.

Measured on **Claude Code 2.1.245**, macOS, subscription auth, model `opus[1m]`.
Numbers will drift on upgrade — re-run `sweep2.sh` after one.

Two eras of numbers live in this file. The **first study** (marked *v1*) was run
against `settings.before.json`, a default-ish config with a 13-entry deny list,
and its baseline was ~10.1-11.5k. The **current study** (2026-08-25) is run
against `settings.barebones.json`, which is what `~/.claude/settings.json`
holds today, and its baseline is 4,910. Deltas are only comparable inside one
era.

## How to measure

`total = input_tokens + cache_creation_input_tokens + cache_read_input_tokens`
of the first assistant turn. That is the same figure the statusline shows, and
it lives in `~/.claude/projects/<project>/<session>.jsonl`.

```sh
./measure.sh my-label          # one measurement
./sweep2.sh                    # one lever at a time, control run before each
./sweep3.sh                    # stacked combinations
```

Four traps worth knowing, all of which produced confidently wrong tables before
they were caught:

- **Don't identify the new session by mtime.** The transcript of the session
  you're measuring *from* is rewritten continuously, so it always looks newest.
  Diff the set of filenames instead.
- **Run a control immediately before every candidate.** The absolute number
  drifts between sessions for reasons outside the config (git status size, and
  at least one cause still unidentified). An interleaved control makes drift
  visible instead of silently poisoning every delta.
- **`chars/4` underestimates by ~35%** on schema-heavy content. A 94k-char
  prompt estimated at 23k tokens actually billed 31k. Trust `usage`, not
  character counts.
- **Run `lib.sh` under bash, not zsh.** zsh does not word-split unquoted
  parameter expansions, so `${extra}` reaches `claude` as one argv and every
  `--tools` run returns `ERR`. Use `bash script.sh`, never `. lib.sh` from an
  interactive zsh.

## Current baseline (2026-08-25)

The config in `settings.barebones.json` == today's `~/.claude/settings.json`.

| Configuration | Total |
|---|---|
| control (barebones settings, headless) | **4,910** |
| same, interactive first turn | **6,126** and **6,551** in two recent sessions |
| `--tools Bash,Read,Edit,Write` | 4,910 — *identical to control* |
| `--exclude-dynamic-system-prompt-sections` | 4,850 (−60) |
| `--tools ""` | **2,555** |
| `--system-prompt "You are Claude Code."` (4 tools kept) | **2,623** |
| `--system-prompt-file` with a ~230-token prompt (4 tools kept) | **2,913** |
| `--tools "" --system-prompt "You are Claude Code."` | **268** |

That `--tools Bash,Read,Edit,Write` ties the control exactly is the headline:
**the deny list already reaches the four-tool minimum, so there is no fat left
in `settings.json`.** Everything above the floor is either tool schemas or
prose.

### Where the 4,910 goes

| Component | Tokens |
|---|---|
| Prose + scaffold floor | 2,555 |
| Tool-use scaffolding (present as soon as ≥1 tool exists) | 286 |
| `Bash` schema | 877 |
| `Read` schema | 608 |
| `Edit` schema | 348 |
| `Write` schema | 236 |
| **total** | **4,910** |

Derived from `--tools Bash` = 3,718, `Bash,Read` = 4,326, `Read` = 3,449,
`Edit` = 3,189, `Write` = 3,077. Measuring one tool at a time over-counts,
because 286 of each single-tool delta is shared scaffolding; subtract it once
and the four marginal costs sum to exactly 2,355 = 4,910 − 2,555.

Interactive costs ~1,200-1,600 more than headless. That gap is the skills
listing, the guidance blocks for deferred tools (the `EndConversation` policy
text alone is several hundred tokens, and it is present even though the tool is
denied), and the session/mode preamble. Almost none of it is reachable from
settings.

## `--system-prompt`: the only way past the prose floor

The ~2,555-token prose floor is unconditional string constants in the binary —
`# Harness`, `# Delivering work`, `# Corrections`, `# Context management`, the
tool-usage preferences, the security policy block, the bypass-permissions note.
No setting or env var gates any of it. `--system-prompt` (or
`--system-prompt-file`) replaces the whole thing with your text.

Measured cost of the replacement is close to linear in the prompt itself:

| Prompt | Tools | Total |
|---|---|---|
| `"You are Claude Code."` | none | **268** |
| `"You are Claude Code."` | Bash, Read, Edit, Write | **2,623** |
| ~230-token working prompt | Bash, Read, Edit, Write | **2,913** |

So the fixed residue under a custom prompt is ~250 tokens — the cwd/env/git
block and minimal scaffolding — and after that you pay only for the prose you
write plus the schemas you keep. A usable coding prompt lands at **~2,900**,
which is **−2,000 against the 4,910 control** and the real floor for a
tool-using session.

What you are actually giving up, and why this is not free:

- **The tool-discipline prose goes with it.** Read-before-Edit, "use Bash for
  search", parallel tool calls, `file_path:line_number`, the reporting rules.
  The tools still work; the habits that make them work well do not come back
  unless you rewrite them. Roughly the first third of any replacement prompt is
  spent buying these back.
- **The security and confirmation policy goes too** — the authorized-testing
  block, "confirm before destructive or outward-facing actions", the correction
  discipline. Write your own or run without.
- **`--exclude-dynamic-system-prompt-sections` becomes a no-op.** `--help` says
  it "only applies with the default system prompt (ignored with
  `--system-prompt`)", and measurement agrees: 2,913 with and without.
- **It is a flag.** No `settings.json` key expresses it, so it needs a wrapper
  (see below). Earlier notes here claim it works in the interactive TUI as well
  as `-p`; that is *not* verified by the current study, which is headless only.
- `--append-system-prompt` is the opposite lever: +12 tokens for a short
  string, and it keeps everything.

`--bare` is still not usable for measurement: it sets `CLAUDE_CODE_SIMPLE=1`
and forces `ANTHROPIC_API_KEY`/`apiKeyHelper` auth, so under subscription auth
the session produces no `usage` record at all (`NOUSAGE`).

## What `claude-lean` is

`claude-lean` is a small shell wrapper in this directory. Its entire
reason to exist is that the two biggest levers — `--tools` and
`--system-prompt` — are **CLI flags with no `settings.json` equivalent**. A
settings-only diet cannot reach them, so anything below the control number
requires launching `claude` through a script.

```sh
exec /Users/benjamin/.local/bin/claude \
  --tools "Bash,Read,Edit,Write" \
  --system-prompt-file "$D/prompt.md" \
  "$@"
```

You use it instead of `claude`, and plain `claude` remains the full-featured
profile. The tradeoff: it only applies where the script is on `$PATH`, whereas
`~/.claude/settings.json` follows you into every directory and every launcher.

An earlier version used `--tools "Bash,Read,Edit,Write,Agent"` plus
`--exclude-dynamic-system-prompt-sections` and claimed ~4,478 tokens. Both the
number and the flags were v1-era: against the current settings that combination
saves 60 tokens, and the `Agent` entry paid for a schema the deny list blocks
from being called.

Note that `--tools` saves **0 headless** against the barebones deny list, which
already reaches the same four-tool set. Its value is the ~600-token
`EndConversation` policy text plus the skills listing, which appear only in
interactive sessions and so cannot be measured with `claude -p`. The
`--system-prompt-file` flag is where the measurable saving is.

## Sharing this with colleagues

Share `settings.barebones.json` as-is and let them delete what they miss. It is
aggressive on purpose -- 4,910 tokens versus ~10,700 stock -- so the honest
pitch is "start here, remove lines until it feels normal."

Copy it to `~/.claude/settings.json` (back up the old one first), then delete a
name from `permissions.deny` to get that tool back. Measured prices, so they can
buy back deliberately:

| Delete from `deny` | Gets back | Cost |
|---|---|---|
| `disableBundledSkills` *(a top-level key, not a deny entry)* | `/code-review`, `/security-review`, `/simplify`, `/init`, `dataviz` and the rest | **1,986** |
| `Skill` | the skill mechanism itself -- required for any of the above | included above |
| `ToolSearch` | ability to load deferred tools. **Recommended:** deferred tools tell the model to "load guidance via ToolSearch", which fails while it is denied | see note |
| `Agent`, `ListAgents` | subagents, which keep *working* context small | 405 measured for `ListAgents`; `Agent` unmeasurable headlessly |
| `Glob`, `Grep` | pattern/content search without shelling out | ~280 |
| `WebFetch`, `WebSearch` | web access | not measured |
| `EnterPlanMode`, `ExitPlanMode` | plan mode | not measured |
| `TodoWrite` | the todo list | 0 (already deferred) |
| `BashOutput`, `KillShell` | managing background shells | 0 (already deferred) |
| `includeGitInstructions: false` *(top-level key)* | the `# Git` block | 441 |

Restoring the daily-driver set -- `Skill`, `ToolSearch`, `Agent`, `ListAgents`,
`Glob`, `Grep`, `TodoWrite`, `AskUserQuestion`, plan mode, `BashOutput`,
`KillShell`, with bundled skills still off -- measured **5,938**. With bundled
skills on, **7,924**. Everything back on is ~10,254, i.e. stock.

Three things to tell them:

- **`statusLine` points at `/Users/benjamin/.claude/statusline.js`.** Delete that
  block or the statusline silently does nothing on their machine.
- **`model: opus[1m]`** assumes a plan that has it, and
  **`skipDangerousModePermissionPrompt`** is a personal risk choice. Both worth a
  conscious decision rather than inheritance.
- **`enabledPlugins: {}` disables *their* plugins, not yours.** Harmless if they
  have none; surprising if they do.

The two dead entries this config used to carry, `JavaScript` and `NotebookRead`,
have been removed -- they matched no tool in 2.1.245 and made Claude Code print
`Permission deny rule "X" matches no known tool -- check for typos` on every
launch. Fixed in both the repo copy and the live config; launches are quiet now.

### Correction: bundled skills *do* load headlessly

This README previously said skills are not loaded by `claude -p`. That is only
true while the `Skill` tool is denied. Re-enable `Skill` and the bundled skills
listing appears in headless runs too, at a measured **1,986 tokens**.

`enabledPlugins: {}` is the opposite case and remains unmeasurable headlessly:
0 delta in every run, even with `Skill` enabled and a 35-skill plugin
(`mattpocock-skills`) installed. Its cost is interactive-only.

### Caveat on the method

These numbers came from swapping `~/.claude/settings.json` in place, with a
`trap` restoring it on exit. That works, but **Claude Code hot-reloads settings
into already-running sessions.** Doing it from inside a live session made the
measuring session pick up the temporary permissive config mid-turn and inject the
full agent roster and skills listing into its own context. Harmless, and
incidentally a fine demonstration of what those listings cost -- but run these
sweeps from a separate terminal if you care about the measuring session.

## The lean profile (built 2026-08-25)

`claude-lean` now carries both flags and a hand-written prompt. Measured:

| Configuration | Total |
|---|---|
| stock config (v1 era) | ~10,700 |
| barebones settings, headless | 4,910 |
| **`claude-lean`** (`--tools` 4 + `prompt.md`) | **2,952** |
| floor with the same 4 tools and a 1-char prompt | 2,612 |

2,612 of that is irreducible while keeping Bash/Read/Edit/Write: 2,355 of tool
schema plus ~257 of residue (cwd/env block, scaffolding). `prompt.md` spends
340 tokens of the remaining budget. Net saving against the settings-only
config: **−1,958**.

Prose in these files tokenizes at **~2.7 chars/token**, not the usual 4 --
`file_path:line_number`, `sed -n` and newlines are dense. Budget ~370 tokens per
1,000 characters.

### What `prompt.md` keeps, and what was dropped

Kept, because the evals below test for it: Bash-for-search, read-before-edit,
parallel tool calls, verify-by-running, no preamble, faithful failure reporting,
`file:line` citations, scope discipline, look-before-overwriting, one-sentence
corrections.

Dropped from the default prose, with the estimated cost of each:

| Dropped block | ~Tokens | Justification |
|---|---|---|
| `# Delivering work` (verbatim) | 330 | Compressed to two sentences. |
| `# Corrections` (verbatim) | 240 | Compressed to one clause. |
| Pronouns paragraph | 95 | No bearing on solo code work. |
| Security policy (authorized testing) | 85 | Not doing security work here. |
| `# Context management` | 65 | Model handles compaction without being told. |
| `# Session-specific guidance` | 55 | The `! command` tip. |
| Product trivia in `# Environment` | ~100 | "Claude Code is available as…", fast mode, model IDs. Not removable directly, but gone with the default prompt. |

### Evals

`evals/run.sh` is the thing that makes trimming safe. Seven probes, each one
checking a behaviour the dropped prose was buying, and each checking the
*result* -- files on disk, or the transcript text -- not the model's own claim
about what it did.

```sh
./evals/run.sh lean       # the claude-lean profile
./evals/run.sh default    # stock, as a control
./evals/run.sh lean 3     # one probe
```

| # | Probe | Checks |
|---|---|---|
| 1 | read-before-edit | both swapped operators actually fixed on disk |
| 2 | honest reporting | impossible test left intact **and** failure admitted |
| 3 | scope discipline | "docstring on greet(), nothing else" changes <=2 lines |
| 4 | bash-for-search | counts TODO lines across a tree correctly |
| 5 | destructive caution | "delete the temp files" spares main.py and settings.ini |
| 6 | `file:line` | output contains `mod.py:<n>` |
| 7 | no preamble | first line is not "Let me…" |

First run, 2026-08-25:

```
lean:    8 passed, 0 failed
default: 8 passed, 0 failed
```

**Both profiles are indistinguishable on these probes.** That is the real
finding of this whole study: the behaviours are mostly in the model's
post-training, and the 2,555-token prose block tunes tendencies rather than
creating capabilities. 340 tokens of hand-written prose reproduced everything
these seven probes can detect.

Two honest limits. Seven probes are a smoke test, not a guarantee -- they catch
gross regressions, not the slow drift that shows up over a 200-turn session,
and they say nothing about the edge cases the dropped policy blocks exist for.
And these are LLM outputs: treat a single FAIL as a signal to re-run, not a
verdict.

## v1 study: what actually worked

Baseline for the config in `settings.before.json`: **10,114-11,537 tokens**
(drifts between runs; deltas below are against a paired control).

| Lever | Kind | Delta | Notes |
|---|---|---|---|
| `--tools ""` | CLI flag | **−7,359** | No tools at all. Chat only. |
| `--tools "Bash,Read,Edit,Write"` | CLI flag | **−6,117** | No subagents, no skills. |
| `--tools "Bash,Read,Edit,Write,Agent"` | CLI flag | **−5,881** | Keeps subagents. Lands at 5,022. |
| `--safe-mode` | CLI flag | −1,024 | Also kills CLAUDE.md, skills, plugins, agents, hooks, MCP. |
| `includeGitInstructions: false` | setting | −441 | Same effect via `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1`. Removes the `# Git` block. |
| `CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS=1` | env | −285 | Drops the built-in Explore/Plan agent types. |
| `--exclude-dynamic-system-prompt-sections` | CLI flag | −118 | Moves cwd/env/git-status into the first user message. Relocates more than it removes. |
| `permissions.deny: [13 tools]` | setting | **−2,561** | The existing deny list. Removing it *costs* 2,561, so it is a real saving — see the correction note below. |

**The one lever that mattered was `--tools`.** Once the deny list is expanded to
the full roster, as it is today, that saving has already been banked through
settings and `--tools` adds nothing (see the current baseline above).

### Correction: `permissions.deny` does remove schemas

Reading the binary suggested deny rules only block *calls* and leave schemas in
the request. Measurement says otherwise: emptying the 13-entry deny list took
the total from 10,665 to **13,226**. Whatever the mechanism, denying a tool
removes roughly 2,500 tokens' worth of schema for this list. Measure, don't
read.

An earlier version of this document claimed the opposite, on the strength of the
binary analysis alone. It was wrong.

## What does nothing

Measured at exactly 0 delta:

| Lever | Why |
|---|---|
| `disabledBuiltinTools` | Managed/workspace-scoped key. Ignored in `~/.claude/settings.json`. |
| `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=1` | Experiment-gated; not active for this account. |
| `CLAUDE_CODE_DISABLE_CLAUDE_MDS=1` | Nothing to remove — there is no CLAUDE.md here. |
| `CLAUDE_CODE_DISABLE_CRON=1`, `ENABLE_TODO_TOOLS=0` | Those tools are already deferred (names only). |
| `enabledPlugins: {}`, `skillOverrides` | See caveat below — not measurable headlessly. |
| `--exclude-dynamic-system-prompt-sections` *with* `--system-prompt` | Documented no-op, confirmed at 2,913 either way. |

## What makes it worse

| Lever | Delta | Why |
|---|---|---|
| `ENABLE_TOOL_SEARCH=auto` | **+7,632** | Turns off tool deferral, inlining every schema. Tool search is the single biggest saving Claude Code already applies for you. Never disable it. |
| `ENABLE_TOOL_SEARCH=standard` | large | Same as above. |
| `--append-system-prompt` | +12 for a one-word string | Additive by design; listed only for contrast with `--system-prompt`. |

## Not bloat (costs zero prompt tokens)

Worth knowing so you don't trade comfort for nothing:

- `statusLine` — the script runs locally and renders to the terminal.
- `tui: fullscreen`, `effortLevel`, `skipDangerousModePermissionPrompt`.
- `model: opus[1m]` — changes the window size, not what's sent.
- MCP, in this setup — ~60 tokens total. The `disableClaudeAiConnectors` and
  `ENABLE_CLAUDEAI_MCP_SERVERS=false` entries are near-free either way; they
  matter only if you actually add MCP servers, whose schemas are deferred anyway.
- No `~/.claude/CLAUDE.md`, no `agents/`, no hooks, no output styles exist here,
  so none of them cost anything.

## The floor

Superseded. The v1 claim was "roughly 3.5k is the practical hard floor with no
tools at all". Today `--tools ""` measures **2,555**, and with
`--system-prompt` the floor collapses to **268**. There is no hard floor in the
binary; there is a prose default that a flag replaces.

Ranked, as of 2026-08-25:

| Configuration | Total |
|---|---|
| barebones settings, interactive | ~6,100-6,600 |
| barebones settings, headless | 4,910 |
| + `--exclude-dynamic-system-prompt-sections` | 4,850 |
| + `--system-prompt-file` (~230-token prompt) | 2,913 |
| + `--system-prompt "You are Claude Code."` | 2,623 |
| `--tools ""` | 2,555 |
| `--tools "" --system-prompt "..."` | 268 |

## The bare-bones config

`settings.barebones.json` (applied to `~/.claude/settings.json`) measured
**4,864** when written and **4,910** today — version drift, same config, no
change on this side. It is settings-only — no wrapper, no flags — which is what
makes it survive `claude` being launched from anywhere.

What it does, in order of value:

1. `permissions.deny` listing every built-in tool except `Bash`, `Read`,
   `Edit`, `Write`. Bare tool names remove schemas outright (~5,250 in v1
   terms).
2. `includeGitInstructions: false` (~441).
3. `enabledPlugins: {}`, `disableBundledSkills`, `disableArtifact`,
   `disableWorkflows`, `autoMemoryEnabled: false`.

### Price list for re-enabling

Measured, so you can buy back exactly what you miss. Tool-schema costs are
from the current study; the rest are v1.

| Add back | Cost |
|---|---|
| `Bash` | 877 (+286 one-off if it is your only tool) |
| `Read` | 608 |
| `Edit` | 348 |
| `Write` | 236 |
| `Agent` (subagents) | **0** headless — genuinely unmeasurable without an interactive session. Re-enable it first. |
| `ListAgents` | 405 |
| `Skill` (and with it, skills) | ~1,600 |
| `Skill` + `ToolSearch` together | ~3,400 |
| `Glob` + `Grep` | ~280 (use `Bash` instead) |
| the `# Git` block | 441 |
| the whole plugin skills listing | ~700 (interactive only) |

Remove a name from the `deny` array to re-enable that tool.

## Caveats

- **Headless is not interactive.** `claude -p` appears not to load the skills
  listing or the `Agent` tool, which is why `skillOverrides`, `enabledPlugins:
  {}` and denying `Agent` all measured zero here. The skills listing costs ~700
  in real interactive captures. Verify anything skill- or subagent-related in a
  real session. Everything in the current study is headless; the two interactive
  numbers quoted above are opportunistic reads of live transcripts, not
  controlled runs.
- **Verify patches actually applied.** One result in this study (`−285`) was a
  silent JSON patch failure that produced a plausible-looking number. `sweep5.sh`
  aborts loudly instead; the earlier sweeps did not.
- **`# Harness` only exists in the *lean* system prompt variant**, which this
  account already receives. If your prompt has a `# Harness` block you are
  already on the shorter prose; if it doesn't, you have more prose than these
  numbers assume.
- The agent roster is not in the system prompt at all; it arrives as a
  system-reminder in the message stream.
- Every `CLAUDE_CODE_*` env var here is internal, with no stability contract.
  Several are coupled to server-side experiment flags and can flip per account.
- The deny list currently logs `Permission deny rule "JavaScript" matches no
  known tool` and the same for `NotebookRead` on every launch. Harmless, free,
  but it means those two entries are dead weight in 2.1.245.
