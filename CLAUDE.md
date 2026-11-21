# Chat Plus

An HLX mod that improves the Farever chat: timestamps, history kept across character switches, more commands, channel buttons and a settings panel. Workspace layout, shared rules and tools: `../workbench/WORKSPACE.md`. How the game's chat works: `../workbench/research/chat.md`. `AUDITLOG.md` records decisions (D), findings (F), risks (R) and next steps (A).

- Build: `haxe compile.hxml` → `build/chat-plus/chat-plus.hl`. Test: `haxe test.hxml`.
- Logic that doesn't touch the game (time formatting, separators, settings) lives in its own classes and is tested in `tests/`.
- Features that can only be checked in the game get a section in `TESTABLE.md`. The user tests them on the PC.
