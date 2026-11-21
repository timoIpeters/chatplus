# Chat Plus

An HLX mod that improves the Farever chat: timestamps, history kept across character switches, chat commands with an address book of seen players, a resizable chat, settings in Better Mod Settings, English and German texts. Workspace layout, shared rules and tools: `../workbench/WORKSPACE.md`. How the game's chat works: `../workbench/research/chat.md`. `AUDITLOG.md` records decisions (D), findings (F), risks (R) and next steps (A).

- Build: `haxe compile.hxml` → `build/chat-plus/chat-plus.hl`. Test: `haxe test.hxml`. Once per clone: `git clone --depth 1 https://github.com/hlx-framework/hlx-core.git vendor/hlx-core`.
- `README.md` is the player-facing description (also used on Nexus Mods); build details stay here.
- Logic that doesn't touch the game (time formatting, settings, texts, command parsing, player lookup, chat size) lives in its own classes and is tested in `tests/`.
- Features that can only be checked in the game get a section in `TESTABLE.md`. The user tests them on the PC.
