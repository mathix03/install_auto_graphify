# graphify Auto-Installer

One-click PowerShell installer that turns any codebase into an interactive knowledge graph and wires it straight into Claude Code — zero manual steps, zero questions asked.

<img width="3412" height="1916" alt="Capture d'écran 2026-07-06 200744" src="https://github.com/user-attachments/assets/121f2ac6-76fd-4396-a060-339fc08eec53" />

## What it does

Run the script once and it automatically:

1. **Elevates itself to administrator** (single UAC click — the only interaction needed)
2. **Installs Python 3.11** if missing (via winget, with a python.org fallback)
3. **Installs the graphify engine** (`graphifyy` pip package) and its Claude Code skill
4. **Finds Claude on your PC** (desktop app and/or CLI) and **links graphify to your project** — a `CLAUDE.md` section plus a hook make the knowledge graph *always-on*: Claude consults it before answering any codebase question
5. **Builds the interactive map** of your code — nodes are functions, classes and concepts; colors are auto-detected communities; the biggest nodes are the central "god nodes"
6. **Opens two pages in your browser**: the graph map (`graph.html`) and a complete user guide (`guide-graphify.html`)
7. **Launches the Claude app**

## Quick start

**Method 1: The One-Liner (Recommended)**
Open PowerShell as administrator and run this single command to download and execute the installer:

```powershell
irm [https://raw.githubusercontent.com/mathix03/install_auto_graphify/main/install-graphify.ps1](https://raw.githubusercontent.com/mathix03/install_auto_graphify/main/install-graphify.ps1) -OutFile install-graphify.ps1; powershell -ExecutionPolicy Bypass -File .\install-graphify.ps1
```
**Method 2: Manual Download

Drop `install-graphify.ps1` into your project folder, then:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-graphify.ps1
```

<img width="2943" height="1946" alt="Capture d&#39;écran 2026-07-06 200628" src="https://github.com/user-attachments/assets/33cbd178-2bec-4d24-978f-66ef3d833c81" />

Or right-click the script → **Run with PowerShell**. To target another folder without moving the script:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-graphify.ps1 -ProjectPath "C:\path\to\project"
```

## What you get

```
your-project/
├── CLAUDE.md                      # graphify section → Claude uses the graph automatically
├── .claude/settings.json          # hooks keeping the graph in the loop
└── graphify-out/
    ├── graph.html                 # interactive map (search, zoom, community filters)
    ├── guide-graphify.html        # full usage guide (opened alongside the map)
    ├── graph.json                 # raw graph data, GraphRAG-ready
    └── GRAPH_REPORT.md            # plain-language report with an honest audit trail
```

The initial map covers your **code** (AST extraction, no LLM, no API cost). Type `/graphify` inside Claude to enrich it with docs, PDFs, images, videos and semantic links.

### The Included Guide
The installer also generates a comprehensive local guide to help you master Graphify:

<img width="1307" height="1482" alt="Capture d&#39;écran 2026-07-06 200848" src="https://github.com/user-attachments/assets/04a88729-44b6-4417-a045-c436799fd698" />
<img width="1165" height="1424" alt="Capture d&#39;écran 2026-07-06 200910" src="https://github.com/user-attachments/assets/71ab8560-25e7-4800-b561-33d03e723189" />
<img width="1202" height="1050" alt="Capture d&#39;écran 2026-07-06 200926" src="https://github.com/user-attachments/assets/3cc102be-1094-4ab0-ae7f-db6289421963" />

## Credits
This project is an automated installer for the excellent **graphify** engine developed by [safishamsi](https://github.com/safishamsi/graphify). Make sure to check out the original repository to support their work!

## 🔒 Security & Transparency

Since this script requests **Administrator privileges (UAC elevation)** to configure the environment, here is a transparent list of exactly what it accesses and modifies on your machine:

* **System & Python:** Checks if Python 3.11+ is installed. If missing, it invokes Windows `winget` (or the official python.org installer) to deploy it.
* **Python Packages:** Installs the official `graphifyy` engine globally or locally via `pip install`.
* **Claude Code Integration:** Creates and registers the custom graphify skill inside your global user profile folder (`~\.claude\skills\`).
* **Project Directory:** Modifies *only* the specific project folder where it is executed by appending automated context instructions to `CLAUDE.md` and registering git/tool hooks inside `.claude/settings.json`.

> **Note:** The script explicitly drops administrator rights before launching your default web browser and the Claude app to maintain system safety.

## Requirements

- Windows 10/11 with PowerShell 5.1+
- Administrator rights (the script requests them itself)
- Internet connection (pip / winget downloads)

## Notes

- The pip package is **`graphifyy`** (double *y*) — that is the official PyPI name of graphify. Do not install `graphify` (single *y*), it is a different package.
- The browser and Claude are deliberately launched **without** admin rights; only the installation itself is elevated.
- The graph is persistent across sessions: build once, query forever. Keep it fresh with `graphify update .` (instant, no LLM) or `graphify hook install` (auto-rebuild on every git commit).
