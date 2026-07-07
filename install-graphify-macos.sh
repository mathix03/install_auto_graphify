#!/usr/bin/env bash
#
# install-graphify-macos.sh — version macOS
# Installe graphify (CLI + skill Claude Code) automatiquement.
#   - Demande les droits administrateur (sudo) une seule fois, au début
#   - Installe Homebrew puis Python 3 si absents
#   - Installe le package pip "graphifyy" (le vrai nom du package graphify sur PyPI)
#   - Copie le skill dans ~/.claude/skills/graphify via "graphify install --platform claude"
#   - Trouve Claude (app /Applications/Claude.app et/ou CLI) - et installe
#     Claude Code automatiquement s'il est absent (installeur officiel, repli npm)
#   - Lie graphify au projet (CLAUDE.md + hook)
#   - Construit la carte du graphe (sans LLM) et l'ouvre dans le navigateur
#   - Génère et ouvre un guide d'utilisation complet (graphify-out/guide-graphify.html)
#   - Lance l'app Claude (ou le CLI dans un nouveau Terminal)
#
# Tout est automatique : aucune question posée (sauf le mot de passe sudo).
# Le projet cartographié est le dossier où se trouve le script, sauf si un
# chemin est donné en argument :
#     ./install-graphify-macos.sh [/chemin/vers/projet]
#
set -uo pipefail

# ============================================================================
# 0. Couleurs et helpers
# ============================================================================
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
step() { echo -e "\n${CYAN}==> $*${NC}"; }
ok()   { echo -e "    ${GREEN}[OK]${NC} $*"; }
warn() { echo -e "    ${YELLOW}[!]${NC} $*"; }
fail() { echo -e "\n${RED}[ERREUR]${NC} $*"; exit 1; }

# ============================================================================
# 1. Si lancé avec "sudo ./install-graphify-macos.sh", on redescend vers
#    l'utilisateur réel : Homebrew, pip, le skill et le navigateur doivent
#    s'installer dans SON profil, pas dans celui de root.
# ============================================================================
if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    echo "Relance en tant que $SUDO_USER..."
    exec sudo -u "$SUDO_USER" -H bash "$0" "$@"
fi

# ============================================================================
# 2. Dossier projet résolu automatiquement (aucune question posée)
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="${1:-$SCRIPT_DIR}"
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || fail "Dossier projet introuvable : ${1:-$SCRIPT_DIR}"

echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}     Installation automatique de graphify${NC}"
echo -e "${CYAN}=============================================${NC}"
echo "Utilisateur : $USER"
echo "Projet      : $PROJECT_PATH"

# ============================================================================
# 3. Droits administrateur : un seul mot de passe, mis en cache pour la suite
#    (utilisé par l'installeur Homebrew si besoin ; refus non bloquant)
# ============================================================================
if [[ $EUID -ne 0 ]]; then
    step "Droits administrateur (sudo)"
    if sudo -v; then
        ok "Droits administrateur obtenus"
    else
        warn "sudo refusé - l'installation de Homebrew pourrait échouer, le reste fonctionnera."
    fi
fi

# Homebrew (Apple Silicon : /opt/homebrew, Intel : /usr/local) + pip user bin
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

# ============================================================================
# 4. Homebrew (installé seulement si nécessaire pour Python)
# ============================================================================
ensure_brew() {
    command -v brew >/dev/null 2>&1 && return 0
    warn "Homebrew introuvable - installation en cours..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
    command -v brew >/dev/null 2>&1
}

# ============================================================================
# 5. Python 3.9+
# ============================================================================
step "Vérification de Python 3.9+"
have_python() {
    command -v python3 >/dev/null 2>&1 && \
    python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,9) else 1)' 2>/dev/null
}
if ! have_python; then
    warn "Python 3.9+ introuvable - installation via Homebrew..."
    ensure_brew || fail "Homebrew indisponible. Installez Python 3.9+ manuellement (https://www.python.org)."
    brew install python || fail "brew install python a échoué."
    have_python || fail "Python installé mais toujours introuvable. Rouvrez un terminal puis relancez."
fi
ok "Python : $(command -v python3) ($(python3 --version 2>&1))"

# pip présent ?
python3 -m pip --version >/dev/null 2>&1 || python3 -m ensurepip --user >/dev/null 2>&1 || true
python3 -m pip --version >/dev/null 2>&1 || fail "pip indisponible pour ce Python."

# ============================================================================
# 6. Package pip "graphifyy" (nom officiel du package graphify sur PyPI)
#    Échelle de replis :
#      1. pipx s'il est présent
#      2. pip --user avec le python3 courant (erreurs affichées)
#      3. repli PEP 668 (--break-system-packages) si ce pip connaît l'option
#      4. dernier recours : Python récent via Homebrew + venv dédié
#         (~/.graphify/venv) + binaire lié dans ~/.local/bin
#    Le vieux Python 3.9 d'Apple (pip 21) échoue souvent aux étapes 2-3 :
#    l'étape 4 le contourne systématiquement.
# ============================================================================
step "Installation du package pip 'graphifyy'"
INSTALLED=""

pip_knows_bsp() {
    python3 -m pip install --help 2>/dev/null | grep -q -- --break-system-packages
}

if command -v pipx >/dev/null 2>&1; then
    if pipx install graphifyy >/dev/null 2>&1 || pipx upgrade graphifyy >/dev/null 2>&1; then
        INSTALLED=1
        ok "Installé via pipx"
    else
        warn "pipx a échoué - tentative via pip..."
    fi
fi

if [[ -z "$INSTALLED" ]]; then
    # pip à jour = plus de chances de trouver des wheels précompilées
    python3 -m pip install --user --upgrade pip >/dev/null 2>&1 || true
    if PIP_OUT="$(python3 -m pip install --user --upgrade graphifyy 2>&1)"; then
        INSTALLED=1
        ok "Installé via pip --user"
    else
        echo "$PIP_OUT" | tail -n 15
        if echo "$PIP_OUT" | grep -qi 'externally.managed' && pip_knows_bsp; then
            warn "Environnement Python 'externally managed' - repli avec --break-system-packages"
            if python3 -m pip install --user --upgrade --break-system-packages graphifyy; then
                INSTALLED=1
                ok "Installé via pip --user (--break-system-packages)"
            fi
        fi
    fi
fi

if [[ -z "$INSTALLED" ]]; then
    warn "pip a échoué avec le Python du système (cause fréquente : Python Apple 3.9 trop ancien)."
    warn "Dernier recours : Python récent via Homebrew + environnement virtuel dédié..."
    ensure_brew || fail "Homebrew indisponible - impossible d'installer un Python récent. Envoyez le message d'erreur pip ci-dessus."
    brew install python || true
    BREW_PY="$(brew --prefix 2>/dev/null)/bin/python3"
    [[ -x "$BREW_PY" ]] || BREW_PY="$(command -v python3)"
    VENV="$HOME/.graphify/venv"
    "$BREW_PY" -m venv "$VENV" || fail "Création de l'environnement virtuel impossible."
    "$VENV/bin/pip" install --upgrade pip graphifyy \
        || fail "pip install graphifyy a échoué même dans un venv - envoyez le message d'erreur ci-dessus."
    mkdir -p "$HOME/.local/bin"
    ln -sf "$VENV/bin/graphify" "$HOME/.local/bin/graphify"
    INSTALLED=1
    ok "Installé dans $VENV (binaire lié dans ~/.local/bin)"
fi

# Sur macOS, pip --user installe les binaires dans ~/Library/Python/3.x/bin
USER_BIN="$(python3 -m site --user-base 2>/dev/null)/bin"
[[ -d "$USER_BIN" ]] && export PATH="$USER_BIN:$PATH"

GRAPHIFY="$(command -v graphify || true)"
[[ -n "$GRAPHIFY" ]] || fail "graphify introuvable dans le PATH après installation (vérifiez $USER_BIN)."
VERSION="$(python3 -c 'import importlib.metadata as m; print(m.version("graphifyy"))' 2>/dev/null \
        || "$HOME/.graphify/venv/bin/python" -c 'import importlib.metadata as m; print(m.version("graphifyy"))' 2>/dev/null \
        || echo '?')"
ok "graphify $VERSION : $GRAPHIFY"

# ============================================================================
# 7. Installation du skill dans ~/.claude/skills/graphify
# ============================================================================
step "Installation du skill Claude Code"
"$GRAPHIFY" install --platform claude || fail "graphify install a échoué."
if [[ -f "$HOME/.claude/skills/graphify/SKILL.md" ]]; then
    ok "Skill installé : $HOME/.claude/skills/graphify"
else
    warn "SKILL.md non trouvé - vérifiez la sortie de 'graphify install' ci-dessus."
fi

# ============================================================================
# 8. Détection de Claude (app de bureau et CLI)
#    - installation automatique de Claude Code s'il est absent
# ============================================================================
step "Recherche de Claude sur le Mac"
CLAUDE_APP=""
for candidate in "/Applications/Claude.app" "$HOME/Applications/Claude.app"; do
    [[ -d "$candidate" ]] && { CLAUDE_APP="$candidate"; break; }
done
CLAUDE_CLI="$(command -v claude || true)"

[[ -n "$CLAUDE_APP" ]] && ok "App de bureau Claude : $CLAUDE_APP"
[[ -n "$CLAUDE_CLI" ]] && ok "CLI Claude Code : $CLAUDE_CLI"

if [[ -z "$CLAUDE_APP" && -z "$CLAUDE_CLI" ]]; then
    warn "Claude introuvable - installation automatique de Claude Code..."
    # Installeur officiel Claude Code (installe dans ~/.local/bin)
    curl -fsSL https://claude.ai/install.sh | bash || true
    hash -r 2>/dev/null || true
    export PATH="$HOME/.local/bin:$PATH"
    CLAUDE_CLI="$(command -v claude || true)"
    [[ -z "$CLAUDE_CLI" && -x "$HOME/.local/bin/claude" ]] && CLAUDE_CLI="$HOME/.local/bin/claude"
    # Repli npm si l'installeur officiel a échoué
    if [[ -z "$CLAUDE_CLI" ]] && command -v npm >/dev/null 2>&1; then
        warn "Installeur officiel indisponible - tentative via npm..."
        npm install -g @anthropic-ai/claude-code 2>/dev/null || true
        hash -r 2>/dev/null || true
        CLAUDE_CLI="$(command -v claude || true)"
    fi
    if [[ -n "$CLAUDE_CLI" ]]; then
        ok "Claude Code installé : $CLAUDE_CLI"
    else
        warn "Installation de Claude échouée - installez-le manuellement :"
        warn "  curl -fsSL https://claude.ai/install.sh | bash"
        warn "  (ou l'app de bureau : brew install --cask claude)"
        warn "Le skill est prêt et sera détecté au premier lancement."
    fi
fi

# ============================================================================
# 9. Liaison automatique de graphify au projet
#    (section CLAUDE.md + hook PreToolUse : graphify devient always-on)
# ============================================================================
step "Liaison de graphify au projet ($PROJECT_PATH)"
( cd "$PROJECT_PATH" && "$GRAPHIFY" claude install ) \
    && ok "Projet lié : CLAUDE.md + hook installés (graphify always-on)" \
    || warn "Liaison échouée - relancez 'graphify claude install' dans le projet."

# ============================================================================
# 10. Construction de la carte du graphe (sans LLM) et ouverture
# ============================================================================
step "Construction de la carte du graphe"
"$GRAPHIFY" update "$PROJECT_PATH" || true
GRAPH_HTML="$PROJECT_PATH/graphify-out/graph.html"

if [[ -f "$GRAPH_HTML" ]]; then
    ok "Carte générée : $GRAPH_HTML"
    open "$GRAPH_HTML" && ok "Carte ouverte dans le navigateur"
else
    warn "Pas de carte générée (dossier sans fichiers de code ?). Lancez /graphify dans Claude pour une extraction complète (code + docs + images)."
fi

# ============================================================================
# 10b. Guide d'utilisation : seconde page ouverte à côté de la carte
# ============================================================================
step "Génération du guide d'utilisation graphify"
GUIDE_DIR="$PROJECT_PATH/graphify-out"
mkdir -p "$GUIDE_DIR"
GUIDE_PATH="$GUIDE_DIR/guide-graphify.html"
cat > "$GUIDE_PATH" <<'GUIDE_EOF'
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
  <h3>Les fichiers voisins dans graphify-out/</h3>
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
    <tr><td><code>/graphify ~/mon-projet</code></td><td>Pipeline complet sur un dossier pr&eacute;cis</td></tr>
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
    <tr><td><code>graphify watch ~/mon-projet</code></td><td>Surveille le dossier et reconstruit la carte en continu</td></tr>
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

<footer>graphify — g&eacute;n&eacute;r&eacute; automatiquement par install-graphify-macos.sh &middot; tapez <code>/graphify --help</code> dans Claude pour la liste compl&egrave;te</footer>
</div>
</body>
</html>
GUIDE_EOF
ok "Guide généré : $GUIDE_PATH"
open "$GUIDE_PATH" && ok "Guide ouvert dans le navigateur (seconde page, à côté de la carte)" \
    || warn "Ouvrez manuellement : $GUIDE_PATH"

# ============================================================================
# 11. Lancement de Claude
# ============================================================================
step "Lancement de Claude"
if [[ -n "$CLAUDE_APP" ]]; then
    open -a "$CLAUDE_APP" && ok "Application Claude lancée"
elif [[ -n "$CLAUDE_CLI" ]]; then
    # Ouvre un nouveau Terminal dans le projet et y lance le CLI (chemin absolu)
    osascript >/dev/null 2>&1 <<OSA
tell application "Terminal"
    do script "cd '$PROJECT_PATH' && '$CLAUDE_CLI'"
    activate
end tell
OSA
    if [[ $? -eq 0 ]]; then
        ok "Claude Code lancé dans un nouveau Terminal"
    else
        warn "Impossible d'ouvrir le Terminal - lancez simplement :  cd '$PROJECT_PATH' && claude"
    fi
else
    warn "Claude non installé - étape ignorée."
fi

echo ""
ok "Installation terminée. Dans Claude, tapez /graphify pour enrichir la carte (docs, images, LLM)."
