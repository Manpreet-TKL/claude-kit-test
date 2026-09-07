---
name: a-pause
description: Pause, default 1 hour, then resume the unfinished task
disable-model-invocation: false
---

# Pause

When loaded as context with no task, reply only `Context loaded.`

Preserve the latest unfinished user target. Wait for the requested duration
(default `1 hour`) with the client's native one-shot sleep or scheduling tool.
Do not poll or emit interim text. When the wait ends, resume that target
immediately; if none exists, say the pause ended. If no such tool is available,
say so instead of simulating the pause with shell polling.
