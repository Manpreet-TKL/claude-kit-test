# memory/

Claude Code's auto-memory, adopted into the kit so it's git-tracked — every
commit is a versioned backup of the memories Claude has saved across
conversations.

One subfolder per project slug (the directory names Claude Code uses under
`~/.claude/projects/`, e.g. `-home-toukan`). `install.sh` (`syncMemory`) moves
any real `~/.claude/projects/<slug>/memory/` dir in here on first run and
symlinks it back, so Claude reads and writes memories through the link — edits
land here live, nothing to re-install.

Inside each folder: `MEMORY.md` is the index Claude loads every session; each
other `*.md` file is one memory. Edit or delete them freely — prune memories
that have gone stale, commit the ones worth keeping.
