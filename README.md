# graphify Auto-Installer

One-click PowerShell installer that turns any codebase into an interactive knowledge graph and wires it straight into Claude Code — zero manual steps, zero questions asked.

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

Drop `install-graphify.ps1` into your project folder, then:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-graphify.ps1
```

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

## Requirements

- Windows 10/11 with PowerShell 5.1+
- Administrator rights (the script requests them itself)
- Internet connection (pip / winget downloads)

## Notes

- The pip package is **`graphifyy`** (double *y*) — that is the official PyPI name of graphify. Do not install `graphify` (single *y*), it is a different package.
- The browser and Claude are deliberately launched **without** admin rights; only the installation itself is elevated.
- The graph is persistent across sessions: build once, query forever. Keep it fresh with `graphify update .` (instant, no LLM) or `graphify hook install` (auto-rebuild on every git commit).
