# 🐮 Scrap Mechanic AI Assistant (MooMoo)

An in-game AI companion for **Scrap Mechanic**, powered by LLMs (OpenRouter) and integrated directly into the gameplay. 

In this custom game mod, the beloved **Baby Woc** named **MooMoo** acts as your personal AI assistant. Players communicate via chat commands (`/aiask <prompt>`), while the AI receives **live in-game context** (world time, active quests, player coordinates, companion status) and can safely execute supported actions in the game world.

---

## 🌟 Key Features

* **In-Character Persona:** MooMoo speaks in natural Russian (or English) as a friendly, slightly scrappy Baby Woc companion.
* **Live Game Context:** The AI is grounded in real session data rather than static guesses:
  * Current day number and exact time of day.
  * Active and completed quest states from `QuestManager`.
  * Player position and movement status.
  * Baby Woc companion state (distance, following/dismissed).
* **Safe Action Allowlist:** The server validates and executes safe in-game actions:
  * Summoning or dismissing the Baby Woc companion (`call_companion`, `dismiss_companion`).
  * Setting time of day presets (`set_time_of_day`) with day count preservation.
  * Activating, tracking, and completing quests (`activate_quest`, `complete_quest`).
* **Game Knowledge Base (RAG):** Built-in index of game mechanics, items, and crafting recipes from Scrap Mechanic files.
* **Security by Design:** No arbitrary Lua execution. Strict argument validation. Zero hardcoded API keys.

---

## 📁 Repository Structure

```
├── mod/
│   └── AI Assistant/             # Scrap Mechanic Custom Game mod
│       ├── description.json      # Mod descriptor
│       ├── config.json           # Entry scripts mapping
│       ├── Scripts/
│       │   ├── Game.lua          # Main game script & chat commands
│       │   ├── Player.lua        # Player lifecycle
│       │   ├── characters/       # Companion character logic
│       │   └── worlds/           # World management
│       ├── Gui/                  # Custom GUI definitions
│       └── Characters/           # Character configurations
├── bridge/
│   ├── openrouter_bridge.js      # Node.js bridge connecting game to OpenRouter
│   ├── package.json              # Bridge metadata & scripts
│   ├── openrouter_key.txt.example # API key template
│   ├── scrap_knowledge_index.json# Indexed game files knowledge base
│   └── tools/
│       └── build_scrap_knowledge.js # Tool to re-index game files
├── docs/
│   └── ROADMAP_AND_ARCHITECTURE_RU.md # Russian architecture & roadmap
├── .gitignore                    # Ignores API keys, logs, and game caches
└── README.md
```

---

## 🚀 Quick Start Guide

### 1. Requirements

* **Scrap Mechanic** (Steam version)
* **Node.js** (v18.0.0 or higher)
* An **OpenRouter API Key** (from [openrouter.ai](https://openrouter.ai))

### 2. Mod Installation

Copy the `mod/AI Assistant` folder into your Scrap Mechanic User Mods directory:

```
%APPDATA%\Axolot Games\Scrap Mechanic\User\User_<YourSteamID>\Mods\AI Assistant
```

### 3. Bridge Configuration

Navigate to the `bridge/` directory:

```powershell
cd bridge
```

Provide your OpenRouter API key using either of these two methods:

* **Option A (Environment Variable, Recommended):**
  ```powershell
  $env:OPENROUTER_API_KEY = "sk-or-v1-your-key-here"
  ```
* **Option B (Key File):**
  Create a file named `openrouter_key.txt` inside `bridge/` and paste your key into it:
  ```powershell
  Copy-Item openrouter_key.txt.example openrouter_key.txt
  # Then paste your API key into openrouter_key.txt
  ```

> ⚠️ `openrouter_key.txt` is included in `.gitignore` and will never be tracked by git.

### 4. Running the Bridge

Start the bridge process:

```powershell
npm start
# or: node openrouter_bridge.js
```

The bridge will automatically detect your Scrap Mechanic user mod cache directory and begin listening for requests.

### 5. In-Game Usage

1. Launch Scrap Mechanic and start/join a world running the **AI Assistant** custom game.
2. Open chat (`Enter`) and talk to MooMoo:
   ```text
   /aiask привет! чем ты можешь мне помочь?
   /aiask какой сейчас игровой день и время?
   /aiask сделай ночь
   /aiask позови коровку
   /aiask какие квесты у меня активны?
   ```

---

## 🛡️ Security & Privacy

* **Zero Secrets in Repository:** API keys, local logs, and cache files are strictly excluded via `.gitignore`.
* **Zero Hardcoded Paths:** The bridge dynamically discovers the player's Steam mod cache folder on any machine.
* **Server-Side Action Validation:** LLM requests are parsed into structured action objects and verified by server Lua before running.

---

## 📜 License

MIT License. Feel free to modify and expand!
