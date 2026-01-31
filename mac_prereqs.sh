#!/usr/bin/env bash
set -euo pipefail

# mac_prereqs.sh
# - Fixes common Homebrew lock issues
# - Updates Homebrew
# - Ensures Xcode Command Line Tools are installed (can trigger install GUI)
# - Optional: reinstall CLT (destructive) with --reinstall-clt
# - Optional: remove broken cask "ollama-app" if present

REINSTALL_CLT=0
REMOVE_OLLAMA_APP=1

usage() {
  cat <<'EOF'
Usage:
  bash mac_prereqs.sh [--reinstall-clt] [--keep-ollama-app]

Options:
  --reinstall-clt     DANGEROUS: removes /Library/Developer/CommandLineTools then triggers reinstall.
  --keep-ollama-app   Do not attempt to uninstall the broken "ollama-app" cask.
EOF
}

# IMPORTANT: do NOT use "${@:-}" here; it creates a single empty argument when no args are passed.
for arg in "$@"; do
  # Defensive: ignore accidental empty args
  [[ -z "${arg:-}" ]] && continue

  case "$arg" in
    --reinstall-clt) REINSTALL_CLT=1 ;;
    --keep-ollama-app) REMOVE_OLLAMA_APP=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; usage; exit 1 ;;
  esac
done

log() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }

# 1) Ensure Homebrew exists
log "Checking Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install it first: https://brew.sh" >&2
  exit 1
fi

# 2) Fix stale Homebrew git lock (e.g. /opt/homebrew/.git/index.lock)
log "Fixing potential Homebrew lock"
HOMEBREW_GIT_LOCK="/opt/homebrew/.git/index.lock"
if [[ -f "$HOMEBREW_GIT_LOCK" ]]; then
  echo "Found lock: $HOMEBREW_GIT_LOCK"
  echo "Checking for running brew/git processes..."
  ps aux | egrep -i "brew|git" | egrep -v "egrep|mac_prereqs.sh" || true
  echo "Removing lock (requires sudo)..."
  sudo rm -f "$HOMEBREW_GIT_LOCK"
fi

# 3) Optional: remove invalid/broken cask that can break brew operations
if [[ "$REMOVE_OLLAMA_APP" == "1" ]]; then
  log "Checking for broken cask 'ollama-app' (optional cleanup)"
  if brew list --cask 2>/dev/null | grep -qi '^ollama-app$'; then
    echo "Uninstalling broken cask: ollama-app"
    brew uninstall --cask ollama-app || true
  else
    echo "ollama-app not installed (or not a cask). Skipping."
  fi
fi

# 4) Update Homebrew
log "brew update"
brew update

# 5) Xcode Command Line Tools
log "Checking Xcode Command Line Tools"
if [[ "$REINSTALL_CLT" == "1" ]]; then
  log "Reinstalling CLT (destructive)"
  echo "This removes /Library/Developer/CommandLineTools"
  sudo rm -rf /Library/Developer/CommandLineTools
fi

if xcode-select -p >/dev/null 2>&1; then
  echo "CLT present at: $(xcode-select -p)"
else
  echo "CLT not installed (or not detected)."
  echo "Triggering install (macOS GUI prompt will appear)..."
  xcode-select --install || true
  cat <<'EOF'

IMPORTANT:
- Complete the Command Line Tools installer popup.
- After installation finishes, re-run this script:
    bash mac_prereqs.sh

EOF
  exit 0
fi

# 6) Sanity checks
log "brew doctor (non-fatal)"
brew doctor || true

log "Done"
echo "Mac prerequisites look good."