#Requires -Version 5.1
<#
    install-graphify.ps1
    Installe graphify (CLI + skill Claude Code) automatiquement sur le PC.
    - Se relance tout seul en administrateur (invite UAC)
    - Installe Python 3.11 si absent (winget, ou installeur python.org en secours)
    - Installe le package pip "graphifyy" (le vrai nom du package graphify sur PyPI)
    - Copie le skill dans ~\.claude\skills\graphify via "graphify install --platform claude"
    - Trouve Claude (app de bureau et/ou CLI) et lie graphify au projet
      (section CLAUDE.md + hook via "graphify claude install")
    - Construit la carte du graphe (graphify update, sans LLM) et l'ouvre dans le navigateur
    - Génère et ouvre un guide d'utilisation complet (graphify-out\guide-graphify.html)
    - Lance l'application Claude

    Tout est automatique : aucune question posée. Le projet cartographié est le
    dossier où se trouve le script (placez le script dans votre projet), sauf si
    un chemin est donné explicitement :
        powershell -ExecutionPolicy Bypass -File .\install-graphify.ps1 [-ProjectPath "C:\mon\projet"]
#>

param(
    # Profil de l'utilisateur d'origine, transmis lors de l'élévation UAC
    # (au cas où l'élévation se ferait avec un autre compte administrateur)
    [string]$TargetUserProfile = $env:USERPROFILE,

    # Dossier du projet à cartographier et à lier à Claude.
    # Si vide : dossier du script (ou dossier courant en dernier recours).
    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# 0. Dossier projet résolu automatiquement (aucune question posée)
# ============================================================================
if (-not $ProjectPath) {
    $ProjectPath = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
}
try { $ProjectPath = (Resolve-Path $ProjectPath -ErrorAction Stop).Path } catch {}

# ============================================================================
# 1. Élévation automatique en administrateur (UAC)
# ============================================================================
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Droits administrateur requis - ouverture de l'invite UAC..." -ForegroundColor Yellow
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " +
               "-TargetUserProfile `"$env:USERPROFILE`" -ProjectPath `"$ProjectPath`""
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Host "Élévation refusée. Relancez le script et acceptez l'invite UAC." -ForegroundColor Red
        Read-Host "Appuyez sur Entrée pour fermer"
        exit 1
    }
    exit 0
}

function Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok([string]$msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Warn([string]$msg) { Write-Host "    [!] $msg" -ForegroundColor Yellow }

# Recharge le PATH depuis le registre (utile juste après une installation)
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

# Trouve un python.exe utilisable (ignore le faux alias du Microsoft Store)
function Find-Python {
    foreach ($cmd in @('python', 'python3', 'py')) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($found -and $found.Source -notmatch 'WindowsApps') {
            try {
                $v = & $found.Source --version 2>&1
                if ($v -match 'Python 3\.(\d+)') {
                    if ([int]$Matches[1] -ge 9) { return $found.Source }
                }
            } catch {}
        }
    }
    return $null
}

# Lance un fichier ou une app SANS droits admin (via explorer.exe),
# pour ne pas ouvrir le navigateur ou Claude en administrateur.
function Start-Unelevated([string]$target) {
    Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList "`"$target`""
}

$exitCode = 0
try {
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "     Installation automatique de graphify"      -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "Profil cible : $TargetUserProfile"
    Write-Host "Projet       : $ProjectPath"

    # ========================================================================
    # 2. Python
    # ========================================================================
    Step "Vérification de Python 3.9+"
    $python = Find-Python

    if (-not $python) {
        Warn "Python introuvable - installation en cours..."
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            & winget install --id Python.Python.3.11 -e --silent --scope machine --accept-package-agreements --accept-source-agreements
        } else {
            Warn "winget indisponible - téléchargement depuis python.org..."
            $installer = Join-Path $env:TEMP 'python-3.11.9-amd64.exe'
            Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' -OutFile $installer -UseBasicParsing
            Start-Process -FilePath $installer -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1' -Wait
            Remove-Item $installer -Force -Confirm:$false
        }
        Update-SessionPath
        $python = Find-Python
        if (-not $python) {
            throw "Python installé mais introuvable dans le PATH. Rouvrez une session puis relancez le script."
        }
    }
    Ok "Python : $python ($(& $python --version 2>&1))"

    # ========================================================================
    # 3. Package pip "graphifyy" (nom officiel du package graphify sur PyPI)
    # ========================================================================
    Step "Installation du package pip 'graphifyy'"
    & $python -m pip install --upgrade pip --quiet
    & $python -m pip install --upgrade graphifyy
    if ($LASTEXITCODE -ne 0) { throw "pip install graphifyy a échoué (code $LASTEXITCODE)." }

    $version = & $python -c "import importlib.metadata; print(importlib.metadata.version('graphifyy'))"
    Ok "graphifyy $version installé"

    # ========================================================================
    # 4. Installation du skill dans ~\.claude\skills\graphify
    # ========================================================================
    Step "Installation du skill Claude Code"
    $scriptsDir  = & $python -c "import sysconfig; print(sysconfig.get_path('scripts'))"
    $graphifyExe = Join-Path $scriptsDir 'graphify.exe'
    if (-not (Test-Path $graphifyExe)) {
        $fallback = Get-Command graphify -ErrorAction SilentlyContinue
        if ($fallback) { $graphifyExe = $fallback.Source }
        else { throw "graphify.exe introuvable dans $scriptsDir" }
    }

    & $graphifyExe install --platform claude
    if ($LASTEXITCODE -ne 0) { throw "graphify install a échoué (code $LASTEXITCODE)." }

    # Si l'élévation UAC a utilisé un autre compte administrateur, le skill a été
    # copié dans le profil de l'admin - on le recopie dans le profil d'origine.
    $skillSrc = Join-Path $env:USERPROFILE '.claude\skills\graphify'
    $skillDst = Join-Path $TargetUserProfile '.claude\skills\graphify'
    if (($skillSrc -ne $skillDst) -and (Test-Path $skillSrc)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $skillDst) | Out-Null
        Copy-Item -Path $skillSrc -Destination (Split-Path $skillDst) -Recurse -Force
        Ok "Skill recopié vers le profil d'origine : $skillDst"
    }

    if (Test-Path (Join-Path $skillDst 'SKILL.md')) {
        Ok "Skill installé : $skillDst"
    } else {
        Warn "SKILL.md non trouvé dans $skillDst - vérifiez la sortie de 'graphify install' ci-dessus."
    }

    # ========================================================================
    # 5. Détection de Claude (app de bureau et CLI)
    # ========================================================================
    Step "Recherche de Claude sur le PC"
    $claudeApp = $null
    foreach ($candidate in @(
        (Join-Path $TargetUserProfile 'AppData\Local\AnthropicClaude\claude.exe'),
        (Join-Path $env:LOCALAPPDATA  'AnthropicClaude\claude.exe')
    )) {
        if (Test-Path $candidate) { $claudeApp = $candidate; break }
    }
    $claudeCli = Get-Command claude -ErrorAction SilentlyContinue

    if ($claudeApp) { Ok "App de bureau Claude : $claudeApp" }
    if ($claudeCli) { Ok "CLI Claude Code : $($claudeCli.Source)" }
    if (-not $claudeApp -and -not $claudeCli) {
        Warn "Claude introuvable. Installez-le depuis https://claude.ai/download - le skill est prêt et sera détecté au premier lancement."
    }

    # ========================================================================
    # 6. Liaison automatique de graphify au projet
    #    (section CLAUDE.md + hook PreToolUse : graphify devient always-on)
    # ========================================================================
    $hasProject = $ProjectPath -and (Test-Path $ProjectPath -PathType Container)
    if ($hasProject) {
        Step "Liaison de graphify au projet ($ProjectPath)"
        Push-Location $ProjectPath
        try {
            & $graphifyExe claude install
            if ($LASTEXITCODE -eq 0) { Ok "Projet lié : CLAUDE.md + hook installés (graphify always-on)" }
            else { Warn "graphify claude install a renvoyé le code $LASTEXITCODE - liaison à refaire avec 'graphify claude install' dans le projet." }
        } finally {
            Pop-Location
        }

        # ====================================================================
        # 7. Construction de la carte du graphe (sans LLM) et ouverture
        # ====================================================================
        Step "Construction de la carte du graphe"
        & $graphifyExe update $ProjectPath
        $graphHtml = Join-Path $ProjectPath 'graphify-out\graph.html'
        if (Test-Path $graphHtml) {
            Ok "Carte générée : $graphHtml"
            Start-Unelevated $graphHtml
            Ok "Carte ouverte dans le navigateur"
        } else {
            Warn "Pas de carte générée (dossier sans fichiers de code ?). Lancez /graphify dans Claude pour une extraction complète (code + docs + images)."
        }

        # ====================================================================
        # 7b. Guide d'utilisation : seconde page ouverte à côté de la carte
        # ====================================================================
        Step "Génération du guide d'utilisation graphify"
        $guideDir = Join-Path $ProjectPath 'graphify-out'
        New-Item -ItemType Directory -Force -Path $guideDir | Out-Null
        $guidePath = Join-Path $guideDir 'guide-graphify.html'
        $guideHtml = @'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Guide graphify — tirer le maximum de votre graphe</title>
<style>
  :root {
    --bg: #0f1115; --card: #171a21; --border: #2a2f3a;
    --text: #d7dce4; --muted: #8b93a1; --accent: #4fc3f7; --accent2: #b388ff;
    --ok: #66bb6a; --warn: #ffb74d; --code-bg: #10131a;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--text);
         font: 16px/1.65 "Segoe UI", system-ui, sans-serif; }
  .wrap { max-width: 980px; margin: 0 auto; padding: 32px 24px 80px; }
  header { text-align: center; padding: 24px 0 8px; }
  header h1 { font-size: 2rem; margin: 0 0 8px;
              background: linear-gradient(90deg, var(--accent), var(--accent2));
              -webkit-background-clip: text; background-clip: text; color: transparent; }
  header p { color: var(--muted); margin: 0 auto 12px; max-width: 640px; }
  nav { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; margin: 20px 0 8px; }
  nav a { color: var(--accent); text-decoration: none; font-size: .85rem;
          border: 1px solid var(--border); border-radius: 20px; padding: 5px 14px;
          background: var(--card); }
  nav a:hover { border-color: var(--accent); }
  section { background: var(--card); border: 1px solid var(--border);
            border-radius: 12px; padding: 22px 26px; margin-top: 22px; }
  h2 { font-size: 1.3rem; margin: 0 0 12px; color: var(--accent); }
  h3 { font-size: 1.02rem; margin: 18px 0 6px; color: var(--accent2); }
  p, li { color: var(--text); }
  ul { margin: 8px 0; padding-left: 22px; }
  code { background: var(--code-bg); border: 1px solid var(--border); border-radius: 5px;
         padding: 1px 7px; font: .86em Consolas, "Cascadia Code", monospace; color: #9ecbff; }
  pre { background: var(--code-bg); border: 1px solid var(--border); border-radius: 8px;
        padding: 14px 16px; overflow-x: auto; }
  pre code { background: none; border: none; padding: 0; }
  table { width: 100%; border-collapse: collapse; margin: 10px 0; font-size: .93rem; }
  th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid var(--border); vertical-align: top; }
  th { color: var(--muted); font-weight: 600; }
  td code { white-space: nowrap; }
  .tip { border-left: 3px solid var(--ok); background: rgba(102,187,106,.08);
         padding: 10px 14px; border-radius: 0 8px 8px 0; margin: 12px 0; }
  .warn { border-left: 3px solid var(--warn); background: rgba(255,183,77,.08);
          padding: 10px 14px; border-radius: 0 8px 8px 0; margin: 12px 0; }
  .muted { color: var(--muted); font-size: .9rem; }
  footer { text-align: center; color: var(--muted); font-size: .85rem; margin-top: 36px; }
</style>
</head>
<body>
<div class="wrap">

<header>
  <h1>&#129504; Guide graphify</h1>
  <p>Votre projet est maintenant un <strong>graphe de connaissances</strong> : chaque fonction, classe,
     document ou concept est un n&oelig;ud, chaque relation un lien. Voici comment en tirer le maximum.</p>
  <nav>
    <a href="#carte">La carte</a>
    <a href="#construire">Construire</a>
    <a href="#interroger">Interroger</a>
    <a href="#maj">Mise &agrave; jour</a>
    <a href="#ajouter">Ajouter du contenu</a>
    <a href="#exports">Exports</a>
    <a href="#astuces">Astuces pro</a>
  </nav>
</header>

<section id="carte">
  <h2>1. Lire la carte interactive (graph.html)</h2>
  <ul>
    <li><strong>Couleurs</strong> : chaque couleur est une <em>communaut&eacute;</em> — un groupe de concepts
        fortement li&eacute;s, d&eacute;tect&eacute; automatiquement. Cliquez sur la l&eacute;gende pour filtrer.</li>
    <li><strong>Gros n&oelig;uds</strong> : les <em>god nodes</em>, les concepts les plus centraux du projet.
        Commencez toujours par eux pour comprendre l'architecture.</li>
    <li><strong>Recherche</strong> : la barre de recherche localise n'importe quel n&oelig;ud instantan&eacute;ment.</li>
    <li><strong>Navigation</strong> : molette pour zoomer, glisser les n&oelig;uds pour r&eacute;organiser,
        survoler pour voir les d&eacute;tails d'un n&oelig;ud.</li>
  </ul>
  <h3>Les fichiers voisins dans graphify-out\</h3>
  <table>
    <tr><th>Fichier</th><th>Usage</th></tr>
    <tr><td><code>GRAPH_REPORT.md</code></td><td>Rapport en langage clair — <strong>lisez-le en premier</strong>. Chaque relation est marqu&eacute;e EXTRACTED (prouv&eacute;e), INFERRED (d&eacute;duite) ou AMBIGUOUS (incertaine) : un audit honn&ecirc;te.</td></tr>
    <tr><td><code>graph.json</code></td><td>Les donn&eacute;es brutes, pr&ecirc;tes pour GraphRAG et les outils externes.</td></tr>
    <tr><td><code>graph.html</code></td><td>La carte interactive (cette fen&ecirc;tre d'&agrave; c&ocirc;t&eacute;).</td></tr>
  </table>
</section>

<section id="construire">
  <h2>2. Construire et enrichir le graphe</h2>
  <div class="warn">La carte cr&eacute;&eacute;e par l'installeur couvre <strong>le code uniquement</strong> (extraction AST, sans IA).
  Pour la version compl&egrave;te — docs, PDF, images, vid&eacute;os, liens s&eacute;mantiques — tapez <code>/graphify</code> dans Claude.</div>
  <table>
    <tr><th>Commande (dans Claude)</th><th>Effet</th></tr>
    <tr><td><code>/graphify</code></td><td>Pipeline complet sur le dossier courant</td></tr>
    <tr><td><code>/graphify C:\mon\projet</code></td><td>Pipeline complet sur un dossier pr&eacute;cis</td></tr>
    <tr><td><code>/graphify https://github.com/owner/repo</code></td><td>Clone puis cartographie un repo GitHub</td></tr>
    <tr><td><code>/graphify &lt;url1&gt; &lt;url2&gt;</code></td><td>Plusieurs repos fusionn&eacute;s en un graphe crois&eacute;</td></tr>
    <tr><td><code>/graphify . --mode deep</code></td><td>Extraction approfondie, plus de liens d&eacute;duits</td></tr>
    <tr><td><code>/graphify . --update</code></td><td>Incr&eacute;mental : seulement les fichiers nouveaux/modifi&eacute;s</td></tr>
  </table>
</section>

<section id="interroger">
  <h2>3. Interroger le graphe — le c&oelig;ur de graphify</h2>
  <div class="tip">L'installeur a d&eacute;j&agrave; <strong>li&eacute; graphify &agrave; Claude</strong> (section CLAUDE.md + hook).
  Le plus simple : posez vos questions normalement dans Claude — &laquo; Comment fonctionne X&nbsp;? &raquo;,
  &laquo; Qu'est-ce qui appelle Y&nbsp;? &raquo; — il consultera le graphe automatiquement avant de r&eacute;pondre.</div>
  <h3>Les commandes directes (terminal ou via Claude)</h3>
  <table>
    <tr><th>Commande</th><th>Quand l'utiliser</th></tr>
    <tr><td><code>graphify query "ma question"</code></td><td>Contexte large (parcours BFS) : &laquo; &agrave; quoi X est-il connect&eacute;&nbsp;? &raquo;</td></tr>
    <tr><td><code>graphify query "..." --dfs</code></td><td>Tracer une cha&icirc;ne pr&eacute;cise (parcours DFS) : &laquo; comment X atteint Y&nbsp;? &raquo;</td></tr>
    <tr><td><code>graphify query "..." --budget 1500</code></td><td>Plafonner la r&eacute;ponse &agrave; N tokens</td></tr>
    <tr><td><code>graphify path "AuthModule" "Database"</code></td><td>Plus court chemin entre deux concepts</td></tr>
    <tr><td><code>graphify explain "NomDuConcept"</code></td><td>Explication simple d'un n&oelig;ud et de ses voisins</td></tr>
  </table>
  <div class="warn">Le moteur matche <strong>litt&eacute;ralement</strong> (pas de synonymes, pas de traduction) :
  utilisez le vocabulaire du projet — les noms que vous voyez sur la carte.</div>
</section>

<section id="maj">
  <h2>4. Garder le graphe &agrave; jour, automatiquement</h2>
  <table>
    <tr><th>Commande</th><th>Effet</th></tr>
    <tr><td><code>graphify update .</code></td><td>R&eacute;-extrait le code modifi&eacute; — sans IA, gratuit, instantan&eacute;. Le hook install&eacute; le fait d&eacute;j&agrave; apr&egrave;s chaque modification via Claude.</td></tr>
    <tr><td><code>graphify watch C:\mon\projet</code></td><td>Surveille le dossier et reconstruit la carte en continu</td></tr>
    <tr><td><code>graphify hook install</code></td><td>Hook git : reconstruction auto apr&egrave;s chaque commit</td></tr>
    <tr><td><code>/graphify . --update</code> (dans Claude)</td><td>Pour les docs / images / vid&eacute;os modifi&eacute;es</td></tr>
  </table>
</section>

<section id="ajouter">
  <h2>5. Ajouter du contenu externe</h2>
  <ul>
    <li><code>/graphify add https://exemple.com/article</code> — t&eacute;l&eacute;charge la page dans <code>./raw</code> et met le graphe &agrave; jour.</li>
    <li><code>--author "Nom"</code> / <code>--contributor "Nom"</code> — trace qui a &eacute;crit / ajout&eacute; le contenu.</li>
    <li>D&eacute;posez des <strong>PDF, images ou vid&eacute;os</strong> dans le dossier puis relancez <code>/graphify . --update</code> :
        les vid&eacute;os sont transcrites (Whisper — <code>--whisper-model medium</code> pour plus de pr&eacute;cision),
        les images analys&eacute;es et int&eacute;gr&eacute;es au graphe.</li>
  </ul>
</section>

<section id="exports">
  <h2>6. Exports &amp; int&eacute;grations</h2>
  <table>
    <tr><th>Option</th><th>Sortie</th></tr>
    <tr><td><code>/graphify . --svg</code></td><td>Image vectorielle — s'int&egrave;gre dans Notion, GitHub</td></tr>
    <tr><td><code>/graphify . --graphml</code></td><td>Fichier pour Gephi / yEd</td></tr>
    <tr><td><code>/graphify . --neo4j-push bolt://localhost:7687</code></td><td>Pousse le graphe dans Neo4j</td></tr>
    <tr><td><code>/graphify . --falkordb-push falkordb://localhost:6379</code></td><td>Pousse le graphe dans FalkorDB</td></tr>
    <tr><td><code>/graphify . --mcp</code></td><td>Serveur MCP : d'autres agents IA interrogent votre graphe</td></tr>
    <tr><td><code>/graphify . --wiki</code></td><td>Wiki navigable : index + un article par communaut&eacute;</td></tr>
    <tr><td><code>/graphify . --obsidian</code></td><td>Vault Obsidian (destination par d&eacute;faut du pipeline complet)</td></tr>
  </table>
</section>

<section id="astuces">
  <h2>7. Astuces pour en tirer le maximum</h2>
  <ul>
    <li><strong>Commencez par GRAPH_REPORT.md</strong>, puis explorez les god nodes sur la carte : c'est le chemin le plus court vers la compr&eacute;hension d'un projet inconnu.</li>
    <li><strong>Le graphe est persistant</strong> : construit une fois, interrog&eacute; dans toutes vos sessions Claude suivantes — z&eacute;ro reconstruction.</li>
    <li><code>graphify benchmark</code> — mesure combien de tokens le graphe &eacute;conomise par rapport &agrave; tout relire.</li>
    <li><code>graphify clone &lt;url-github&gt;</code> — clone un repo pr&ecirc;t &agrave; cartographier ; <code>graphify merge-graphs g1 g2</code> — fusionne plusieurs graphes en un graphe multi-repos.</li>
    <li><code>graphify export callflow-html</code> — diagramme d'architecture / flux d'appels en HTML (Mermaid).</li>
    <li>Mode <code>--mode deep</code> pour les papers scientifiques et les docs denses : plus de relations d&eacute;duites, mieux titr&eacute;es.</li>
    <li>Tr&egrave;s gros projets (&gt;5000 n&oelig;uds) : <code>--no-viz</code> pour sauter la carte, puis exports cibl&eacute;s.</li>
  </ul>
</section>

<footer>graphify — g&eacute;n&eacute;r&eacute; automatiquement par install-graphify.ps1 &middot; tapez <code>/graphify --help</code> dans Claude pour la liste compl&egrave;te</footer>
</div>
</body>
</html>
'@
        [IO.File]::WriteAllText($guidePath, $guideHtml, (New-Object System.Text.UTF8Encoding $true))
        Ok "Guide généré : $guidePath"
        Start-Unelevated $guidePath
        Ok "Guide ouvert dans le navigateur (seconde page, à côté de la carte)"
    } else {
        Warn "Dossier projet invalide ou absent - liaison et carte ignorées. Relancez avec -ProjectPath `"C:\mon\projet`"."
    }

    # ========================================================================
    # 8. Lancement de l'application Claude
    # ========================================================================
    Step "Lancement de Claude"
    if ($claudeApp) {
        Start-Unelevated $claudeApp
        Ok "Application Claude lancée"
    } elseif ($claudeCli) {
        $cliArgs = if ($hasProject) { "-NoExit -Command `"Set-Location '$ProjectPath'; claude`"" }
                   else             { "-NoExit -Command claude" }
        Start-Process -FilePath 'powershell.exe' -ArgumentList $cliArgs
        Ok "Claude Code (CLI) lancé dans un nouveau terminal"
    } else {
        Warn "Claude non installé - étape ignorée."
    }

    Write-Host ""
    Ok "Installation terminée. Dans Claude, tapez /graphify pour enrichir la carte (docs, images, LLM)."

} catch {
    Write-Host "`n[ERREUR] $($_.Exception.Message)" -ForegroundColor Red
    $exitCode = 1
}

Write-Host ""
Read-Host "Appuyez sur Entrée pour fermer"
exit $exitCode
