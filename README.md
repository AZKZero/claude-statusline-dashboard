# My Claude Code dashboard, in one line

![Claude Code statusline: Opus 5.5, OtherProj/abdullah-z-site, master branch, 6% context, 64.5K tokens, $0.54, 43% of 5-hour quota resetting in 2h27m, 37% of weekly quota resetting in 4 days](statusline.jpeg)

*Model · directory · branch · context & cost · account quota, in one line.*

Once an agent is doing most of the typing, the things I glance at change. I stopped caring about the cursor and started caring about **how full the context is, what the session has cost, and how much quota is left**. Claude Code lets you replace its status line with any shell command, so I wrote one that looks like the Powerlevel10k prompt I already use in zsh.

## How it hooks in

In `~/.claude/settings.json`, point `statusLine` at a script. Claude Code pipes a JSON blob describing the session to its stdin and renders whatever it prints.

## The segments

- **Model**: `.model.display_name`, in magenta.
- **Directory**: the last two path components of `.workspace.current_dir`. Enough to tell worktrees apart without eating the line.
- **Git**: the current branch, truncated to 30 characters. Green when the tree is clean, yellow when `git status --porcelain` has output. Hidden outside a repo.
- **Context & cost**: a 10-block bar of `.context_window.used_percentage`, total tokens, and `.cost.total_cost_usd`. The segment goes green → yellow at 50% → red past 80%, which is my cue to compact or start fresh.
- **Quota**: the 5-hour and 7-day `.rate_limits` windows with time until reset (`↻2h:27m`, `↻4d`). Coloured by whichever window is fuller.

## Matching the terminal prompt

The look comes from two small helpers. `seg` prints a padded block with 256-colour background and foreground. `arrow` prints the rounded Nerd Font separator (`U+E0B4`) using the previous segment's colour as foreground and the next one's as background, so the blocks flow into each other. A leading `U+E0B6` cap rounds off the start. Those are the same glyphs set in my `~/.p10k.zsh`, so the statusline and the shell prompt read as one system.

Optional segments (git, quota) are simply skipped, and the script tracks the last background colour so the end cap always matches whatever came before it.

## Small details that mattered

- Everything is read with `jq` using `// default` fallbacks, so a missing field never breaks the line.
- Token counts are humanised with `awk` (`64.5 K`, `1.2 M`).
- White text on the red state; black text reads badly there.
- Reset times collapse to the coarsest useful unit: days, then `h:m`, then minutes.

## Get it

The whole thing is about 170 lines of bash with no dependencies beyond jq, git and a Nerd Font. Grab [statusline.sh](statusline.sh), save it as ~/.claude/statusline.sh, make it executable, and point your settings at it.

> If you're going to watch an agent work all day, make the number that matters the one you can't miss.
