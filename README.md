# HoneyLua

**HoneyLua** is a **Roblox script hub** designed to be executed through a Roblox executor.

- **Executor-first** - built around `loadstring`, `game:HttpGet`, and executor globals
- **Premium feel** - polished organization, consistent style, and practical utilities
- **Obfuscated-ready** - production usage may rely on obfuscated builds

---

## What you get

- A script hub workflow intended for Roblox executors
- A large MM2-focused core with HoneyLua UI integration
- Supporting files for UI, game-specific loading, and internal tooling

> This repository is not positioned as an open-source learning codebase. Some runtime builds may be obfuscated and the project is maintained primarily as a usable script hub.

---

## Usage

HoneyLua is intended to be loaded and executed in a compatible Roblox executor environment.

Current code context:
- The core script uses executor globals such as `getgenv()`
- Remote assets are fetched with `loadstring(game:HttpGet(...))`
- The current main core is MM2-oriented

Documentation and loader examples can be expanded as the hub evolves.

---

## Contribution Policy

HoneyLua is publicly visible, but development direction stays curated. Contributions may be reviewed selectively depending on scope, maintenance cost, and project fit.

---

## Licensing

HoneyLua is publicly available, but no open-source license is granted unless explicitly provided in writing by the owner.

---

## Disclaimer

HoneyLua is provided for educational and development purposes. You are responsible for how you use it.
