#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TOOLS_DIR="$PROJECT_DIR/tools"

SKIP_VERIFY=false
CI_MODE=false

DAML_LINT_REPO_URL="https://github.com/OpenZeppelin/daml-lint"
DAML_VERIFY_REPO_URL="https://github.com/OpenZeppelin/daml-verify"

# ---------- Parse flags ----------
for arg in "$@"; do
  case "$arg" in
    --skip-verification) SKIP_VERIFY=true ;;
    --ci) CI_MODE=true ;;
    -h|--help)
      echo "Usage: scripts/setup.sh [--skip-verification] [--ci]"
      echo ""
      echo "  --skip-verification  Skip installing daml-lint and daml-verify"
      echo "  --ci                 Non-interactive mode for CI (no color, exit 1 on failure)"
      exit 0
      ;;
    *) echo "Unknown flag: $arg"; exit 2 ;;
  esac
done

# ---------- Helpers ----------
info()  { echo "==> $*"; }
warn()  { echo "WARNING: $*" >&2; }
fail()  { echo "ERROR: $*" >&2; exit 1; }

check_cmd() {
  command -v "$1" &>/dev/null
}

# ---------- OS detection ----------
OS="$(uname -s)"
ARCH="$(uname -m)"
info "Detected $OS ($ARCH)"

# ---------- 1. Java 21 ----------
info "Checking Java 21..."
if check_cmd java; then
  JAVA_VER=$(java -version 2>&1 | head -1 | sed 's/.*"\(.*\)".*/\1/' | cut -d. -f1)
  if [ "$JAVA_VER" -ge 21 ] 2>/dev/null; then
    info "Java $JAVA_VER found"
  else
    warn "Java $JAVA_VER found but Java 21+ required for tests"
  fi
else
  warn "Java not found. Install Java 21 to run tests:"
  case "$OS" in
    Darwin) echo "  brew install openjdk@21" ;;
    Linux)  echo "  sudo apt install openjdk-21-jdk  # or use sdkman" ;;
  esac
fi

# Detect JAVA_HOME
if [ -z "${JAVA_HOME:-}" ]; then
  case "$OS" in
    Darwin)
      # Try Homebrew location
      for jhome in /opt/homebrew/Cellar/openjdk@21/*/libexec/openjdk.jdk/Contents/Home \
                    /usr/local/Cellar/openjdk@21/*/libexec/openjdk.jdk/Contents/Home; do
        if [ -d "$jhome" ]; then
          export JAVA_HOME="$jhome"
          break
        fi
      done
      ;;
    Linux)
      for jhome in /usr/lib/jvm/java-21-openjdk-* /usr/lib/jvm/java-21-*; do
        if [ -d "$jhome" ]; then
          export JAVA_HOME="$jhome"
          break
        fi
      done
      ;;
  esac
fi

if [ -n "${JAVA_HOME:-}" ]; then
  export PATH="$JAVA_HOME/bin:$PATH"
  info "JAVA_HOME=$JAVA_HOME"
fi

# ---------- 2. dpm ----------
info "Checking dpm..."
if check_cmd dpm; then
  info "dpm found: $(which dpm)"
else
  warn "dpm not found. Install the Digital Asset Package Manager:"
  echo "  See https://docs.daml.com for installation instructions"
  echo "  Binary should be at ~/.dpm/bin/dpm"
  if [ "$CI_MODE" = true ]; then
    fail "dpm is required"
  fi
fi

# ---------- 3. Verify DARs ----------
info "Checking DARs..."
DAR_COUNT=$(ls "$PROJECT_DIR/dars/"*.dar 2>/dev/null | wc -l | tr -d ' ')
if [ "$DAR_COUNT" -ge 7 ]; then
  info "Found $DAR_COUNT DARs in dars/"
else
  fail "Expected 7 DARs in dars/, found $DAR_COUNT"
fi

# ---------- 4. Build ----------
info "Building simple-token..."
cd "$PROJECT_DIR/simple-token" && dpm build

info "Building simple-token-test..."
cd "$PROJECT_DIR/simple-token-test" && dpm build

# ---------- 5. Test ----------
info "Running tests..."
cd "$PROJECT_DIR/simple-token-test" && dpm test

# ---------- 6. Verification tools (optional) ----------
if [ "$SKIP_VERIFY" = true ]; then
  info "Skipping verification tools (--skip-verification)"
else
  mkdir -p "$TOOLS_DIR"

  # daml-lint (Rust)
  info "Setting up daml-lint..."
  if check_cmd daml-lint; then
    info "daml-lint already installed"
  elif check_cmd cargo; then
    if [ ! -d "$TOOLS_DIR/daml-lint" ]; then
      git clone "$DAML_LINT_REPO_URL" "$TOOLS_DIR/daml-lint"
    fi
    cd "$TOOLS_DIR/daml-lint" && cargo build --release
    info "daml-lint built at $TOOLS_DIR/daml-lint/target/release/daml-lint"
  else
    warn "Rust/Cargo not found. Install rustup to build daml-lint:"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  fi

  # daml-verify (Python + Z3)
  info "Setting up daml-verify..."
  if check_cmd python3; then
    if [ ! -d "$TOOLS_DIR/daml-verify" ]; then
      git clone "$DAML_VERIFY_REPO_URL" "$TOOLS_DIR/daml-verify"
    fi
    cd "$TOOLS_DIR/daml-verify"
    if [ ! -d .venv ]; then
      python3 -m venv .venv
    fi
    .venv/bin/pip install -q z3-solver
    info "daml-verify ready at $TOOLS_DIR/daml-verify"
  else
    warn "Python 3 not found. Install Python 3.10+ to use daml-verify"
  fi

  info "Verification tools installed in $TOOLS_DIR/"
fi

# ---------- Done ----------
echo ""
info "Setup complete!"
echo ""
echo "  Build:    cd simple-token && dpm build"
echo "  Test:     cd simple-token-test && dpm test"
if [ "$SKIP_VERIFY" = false ]; then
  echo "  Verify:   scripts/verify.sh"
fi
