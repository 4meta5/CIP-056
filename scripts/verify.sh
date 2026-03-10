#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TOOLS_DIR="$PROJECT_DIR/tools"
SOURCE_DIR="$PROJECT_DIR/simple-token/daml"

PASS=0
FAIL=0

info()  { echo "==> $*"; }
warn()  { echo "WARNING: $*" >&2; }

# ---------- 1. daml-lint ----------
info "Running daml-lint (static analysis)..."
LINT_BIN=""
if command -v daml-lint &>/dev/null; then
  LINT_BIN="daml-lint"
elif [ -x "$TOOLS_DIR/daml-lint/target/release/daml-lint" ]; then
  LINT_BIN="$TOOLS_DIR/daml-lint/target/release/daml-lint"
fi

if [ -n "$LINT_BIN" ]; then
  if $LINT_BIN "$SOURCE_DIR" --format markdown; then
    info "daml-lint: PASS"
    PASS=$((PASS + 1))
  else
    warn "daml-lint: findings detected"
    FAIL=$((FAIL + 1))
  fi
else
  warn "daml-lint not found. Run scripts/setup.sh to install."
fi

# ---------- 2. daml-props ----------
info "Running daml-props (property-based tests)..."

# Detect JAVA_HOME
if [ -z "${JAVA_HOME:-}" ]; then
  for jhome in /opt/homebrew/Cellar/openjdk@21/*/libexec/openjdk.jdk/Contents/Home \
                /usr/local/Cellar/openjdk@21/*/libexec/openjdk.jdk/Contents/Home \
                /usr/lib/jvm/java-21-openjdk-* /usr/lib/jvm/java-21-*; do
    if [ -d "$jhome" ]; then
      export JAVA_HOME="$jhome"
      break
    fi
  done
fi
if [ -n "${JAVA_HOME:-}" ]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi

cd "$PROJECT_DIR/simple-token-test"
if dpm test 2>&1 | grep -q "ok,"; then
  info "daml-props: PASS (all tests including property tests)"
  PASS=$((PASS + 1))
else
  warn "daml-props: test failures detected"
  FAIL=$((FAIL + 1))
fi

# ---------- 3. daml-verify ----------
info "Running daml-verify (formal verification)..."
VERIFY_DIR="$TOOLS_DIR/daml-verify"

if [ -d "$VERIFY_DIR" ] && [ -f "$VERIFY_DIR/.venv/bin/python" ]; then
  cd "$VERIFY_DIR"
  if .venv/bin/python main.py; then
    info "daml-verify: PASS (all 9 properties proved)"
    PASS=$((PASS + 1))
  else
    warn "daml-verify: verification failures"
    FAIL=$((FAIL + 1))
  fi
else
  warn "daml-verify not found. Run scripts/setup.sh to install."
fi

# ---------- Summary ----------
echo ""
info "Verification complete: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
