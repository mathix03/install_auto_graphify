# graphify Auto-Installer

![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-apt%20·%20dnf%20·%20pacman%20·%20zypper%20·%20apk-FCC624?logo=linux&logoColor=black)
![macOS](https://img.shields.io/badge/macOS-Intel%20%26%20Apple%20Silicon-000000?logo=apple&logoColor=white)
![AI assistants](https://img.shields.io/badge/links-Claude%20Code%20·%20Gemini%20CLI%20·%20Antigravity-8A2BE2)

One-click installer that turns any codebase into an **interactive knowledge graph** and wires it straight into **Claude Code, Gemini CLI and Google Antigravity** — zero manual steps, zero questions asked.

Drop the script into a project folder, run it, and seconds later you have: a queryable graph of your code open in your browser, a full user guide next to it, and your AI assistants permanently linked to the graph.

<img width="3412" height="1916" alt="Interactive knowledge graph map" src="https://github.com/user-attachments/assets/38c03f0b-4973-4864-82d6-0b778a6273f7" />

<details>
<summary><strong>More screenshots</strong> (report, guide, outputs)</summary>

<img width="1307" height="1482" alt="Graph report" src="https://github.com/user-attachments/assets/cb4c9c65-4be7-4a67-afdf-e016c1501d7c" />
<img width="1165" height="1424" alt="Usage guide" src="https://github.com/user-attachments/assets/2b123aea-bb3c-4284-a546-b047086a4ae9" />
<img width="1202" height="1050" alt="Graph details" src="https://github.com/user-attachments/assets/3e2c12ba-16e1-4b66-970c-d11b3c249375" />

</details>

---

## What it does

Every version runs the same fully automatic pipeline:

1. **Elevates privileges** — UAC prompt on Windows, single `sudo` password on Linux/macOS (used only for system packages; everything else installs in your user profile)
2. **Installs Python 3** if missing — winget/python.org (Windows), native package manager (Linux), Homebrew (macOS)
3. **Installs the graphify engine** — the [`graphifyy`](https://pypi.org/project/graphifyy/) pip package — and its Claude Code skill (`~/.claude/skills/graphify`)
4. **Finds Claude** (desktop app and/or CLI) — and **installs Claude Code automatically if missing** (official installer, npm fallback). Also detects Gemini CLI and Google Antigravity if present.
5. **Links graphify to your project for three AI assistants**:
   - **Claude Code** — `CLAUDE.md` section + PreToolUse hook
   - **Gemini CLI** — `GEMINI.md` section + BeforeTool hook
   - **Google Antigravity** — `.agents/` rules + workflows + skill

   Each assistant consults the knowledge graph before answering any codebase question, in every future session. The links are inert files: even if Gemini or Antigravity isn't installed yet, everything is ready the day you install them.
6. **Builds the interactive map** — AST extraction, no LLM, no API cost — and opens it in your browser **together with a complete usage guide** (`guide-graphify.html`)
7. **Launches Claude** — the desktop app, or the CLI in a new terminal opened in your project

---

## Quick start

### Windows (10/11)

Download [`install-graphify.ps1`](install-graphify.ps1) into your project folder, then right-click → **Run with PowerShell**, or:

```powershell
irm https://raw.githubusercontent.com/mathix03/install_auto_graphify/main/install-graphify.ps1 -OutFile install-graphify.ps1
powershell -ExecutionPolicy Bypass -File .\install-graphify.ps1
```

Target another folder without moving the script:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-graphify.ps1 -ProjectPath "C:\path\to\project"
```

### GNU/Linux

```bash
curl -fsSLO https://raw.githubusercontent.com/mathix03/install_auto_graphify/main/install-graphify.sh
chmod +x install-graphify.sh
./install-graphify.sh                # project = the script's folder
./install-graphify.sh ~/my/project   # or an explicit path
```

Works on Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE and Alpine (apt, dnf/yum, pacman, zypper, apk).

### macOS (Intel & Apple Silicon)

```bash
curl -fsSLO https://raw.githubusercontent.com/mathix03/install_auto_graphify/main/install-graphify-macos.sh
chmod +x install-graphify-macos.sh
./install-graphify-macos.sh                # project = the script's folder
./install-graphify-macos.sh ~/my/project   # or an explicit path
```

Installs Homebrew automatically if it is needed and missing. Compatible with the stock bash 3.2 shipped with macOS.

---

## Example run

What a successful installation looks like on each platform (click to expand):

<details>
<summary><strong>Windows</strong></summary>

<img width="2943" height="1946" alt="Windows install run" src="https://github.com/user-attachments/assets/8fb0f9b5-98f1-4cb1-bda7-bb3e99c991d1" />

</details>

<details>
<summary><strong>GNU/Linux</strong></summary>

<img width="1832" height="1200" alt="Linux install run 1" src="https://github.com/user-attachments/assets/74091f3f-83a9-4c3f-b7d5-ef7cbd30d735" />
<img width="2471" height="1760" alt="Linux install run 2" src="https://github.com/user-attachments/assets/90b0bedc-d045-4228-9734-263b943b0e21" />

</details>

<details>
<summary><strong>macOS</strong></summary>

<img width="1680" height="900" alt="macOS install run 1" src="https://github.com/user-attachments/assets/a5f64911-fc6a-4a3e-9c04-eab90a017db1" />
<img width="1680" height="879" alt="macOS install run 2" src="https://github.com/user-attachments/assets/f7dbcdf2-d7aa-49ce-9db8-ccead1bf389d" />
<img width="1680" height="1050" alt="macOS install run 3" src="https://github.com/user-attachments/assets/850b30c2-426b-400e-b139-82a948595dba" />
<img width="1680" height="614" alt="macOS install run 4" src="https://github.com/user-attachments/assets/14da7ef7-6730-4a8a-a0f2-7d5143da0f87" />

</details>

---

## What you get

```
your-project/
├── CLAUDE.md                      # Claude Code → uses the graph automatically
├── GEMINI.md                      # Gemini CLI → uses the graph automatically
├── .claude/settings.json          # Claude PreToolUse hook
├── .gemini/settings.json          # Gemini BeforeTool hook
├── .agents/                       # Antigravity rules + workflows + skill
└── graphify-out/
    ├── graph.html                 # interactive map (search, zoom, community filters)
    ├── guide-graphify.html        # full usage guide (opened alongside the map)
    ├── graph.json                 # raw graph data, GraphRAG-ready
    └── GRAPH_REPORT.md            # plain-language report with an honest audit trail
```

On the map: **colors** are auto-detected communities (click the legend to filter), the **biggest nodes** are the central "god nodes", and the search bar finds any node instantly.

The initial map covers your **code** (AST extraction — instant and free). Type `/graphify` inside Claude to enrich it with docs, PDFs, images, videos and semantic links.

---

## Platform differences

| | Windows | GNU/Linux | macOS |
|---|---|---|---|
| Privilege model | UAC self-elevation | one `sudo` prompt (system packages only) | one `sudo` prompt (Homebrew only) |
| Python source | winget / python.org | apt · dnf · pacman · zypper · apk | Homebrew |
| Claude detected | desktop app + CLI | CLI | desktop app (`/Applications/Claude.app`) + CLI |
| Claude auto-install | `claude.ai/install.ps1`, npm fallback | `claude.ai/install.sh`, npm fallback | `claude.ai/install.sh`, npm fallback |
| AI assistants linked | Claude Code · Gemini CLI · Antigravity | Claude Code · Gemini CLI · Antigravity | Claude Code · Gemini CLI · Antigravity |
| Opens map & guide | default browser (unelevated) | `xdg-open` | `open` |
| Launches Claude | app, or CLI in PowerShell window | CLI in gnome-terminal/konsole/kitty/… | app, or CLI in Terminal.app |

All three scripts are re-runnable: running them again simply updates everything.

### Robust pip install (Linux & macOS)

The `graphifyy` package is installed through a fallback ladder that survives old system Pythons and PEP 668 "externally managed" environments:

1. `pipx` if present
2. `pip install --user` (errors shown, pip upgraded first)
3. `--break-system-packages` retry — only when the error is PEP 668 *and* pip supports the flag
4. Last resort: a recent Python (Homebrew on macOS) + a dedicated virtualenv at `~/.graphify/venv`, with the `graphify` binary linked into `~/.local/bin`

---

## Security & transparency

This installer asks for admin rights, so here is exactly what it touches:

- **With elevation**: system package installs only (Python, and on Windows the optional winget install). The browser and Claude are deliberately launched **without** admin rights.
- **In your user profile**: the `graphifyy` pip package and the skill folder `~/.claude/skills/graphify`.
- **In the target project only**: `CLAUDE.md`, `GEMINI.md`, `.claude/settings.json`, `.gemini/settings.json` and `.agents/` — the assistant links described above.
- **Downloads**: python.org (Windows fallback), the official Claude Code installer (`claude.ai/install.ps1` / `install.sh`), Homebrew's official installer (macOS, only if needed), and PyPI.
- Nothing is sent anywhere; the initial graph build is pure local AST extraction (no LLM, no API key).

> **Note the package name**: the official PyPI name of graphify is **`graphifyy`** (double *y*). Do not install `graphify` (single *y*) — that is a different, unrelated package.

## Uninstall

```bash
graphify uninstall              # removes graphify from all detected platforms
graphify uninstall --purge     # also deletes graphify-out/
graphify claude uninstall      # per-project: removes the CLAUDE.md section + hook
graphify gemini uninstall      # per-project: removes the GEMINI.md section + hook
graphify antigravity uninstall # per-project: removes .agents/ rules + workflows + skill
pip uninstall graphifyy        # (or: pipx uninstall graphifyy)
```

## Requirements

- **Windows**: Windows 10/11, PowerShell 5.1+, admin rights, internet
- **Linux**: any distro with apt/dnf/yum/pacman/zypper/apk, bash, sudo, internet
- **macOS**: macOS 12+, internet (Homebrew is installed automatically if needed)

## Credits

This project is an installer for [**graphify**](https://github.com/safishamsi/graphify) by Safi Shamsi (MIT License) — all the knowledge-graph magic is his work. This repo just makes getting it running with Claude Code, Gemini CLI and Google Antigravity a one-click affair.

## License

MIT
