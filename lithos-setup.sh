export LITHOS_REPO="$HOME/src/lithos"
export RALPH_DEV_ROOT="$(pwd)"
export RPP_DIR="$RALPH_DEV_ROOT/ralph-plus-plus"
export RS_DIR="$RALPH_DEV_ROOT/ralph-sandbox"

export LOGS_DIR="$RALPH_DEV_ROOT/logs"
mkdir -p "$LOGS_DIR"

run_case() {
  local case_name="$1"; shift
  local raw="$LOGS_DIR/${case_name}-raw.log"
  local clean="$LOGS_DIR/${case_name}-clean.log"
  echo "▶ $case_name → $raw"
  local cmd
  cmd="$(printf '%q ' "$@")"
  echo "$ $cmd" > "$raw"
  script -q -a -c "$cmd" "$raw"
  local rc=$?
  ansifilter -o "$clean" "$raw"
  echo "  exit=$rc  clean log: $clean"
  return $rc
}
