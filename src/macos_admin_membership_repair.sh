#!/bin/bash
set -u

ACTION=""
TARGET_USER=""
DRY_RUN=false
ASSUME_YES=false
OUTPUT_DIR=""
FAILURES=0
ACTIONS=0

usage() {
  cat <<'EOF'
Usage: macos_admin_membership_repair.sh [action] --user USER [options]

Actions:
  --add-admin       Add USER to the local admin group.
  --remove-admin    Remove USER from the local admin group.

Options:
  --dry-run         Show commands without changing the Mac.
  --yes             Skip confirmation prompts.
  --output DIR      Save logs and before/after state in DIR.
  -h, --help        Show help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --add-admin) ACTION="add"; shift ;;
    --remove-admin) ACTION="remove"; shift ;;
    --user) TARGET_USER="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 3; }
[ "$(id -u)" -eq 0 ] || { echo "Run this repair with sudo." >&2; exit 3; }
[ -n "$ACTION" ] || { echo "Choose --add-admin or --remove-admin." >&2; exit 2; }
[ -n "$TARGET_USER" ] || { echo "--user is required." >&2; exit 2; }
/usr/bin/id "$TARGET_USER" >/dev/null 2>&1 || { echo "Local user not found: $TARGET_USER" >&2; exit 2; }
USER_UID=$(id -u "$TARGET_USER")
[ "$USER_UID" -ge 500 ] || { echo "Refusing to modify a system account." >&2; exit 2; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./admin-membership-repair-$STAMP}"
mkdir -p "$OUTPUT_DIR"
LOG="$OUTPUT_DIR/repair.log"
BEFORE="$OUTPUT_DIR/before.txt"
AFTER="$OUTPUT_DIR/after.txt"
: > "$LOG"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
confirm() {
  $ASSUME_YES && return 0
  printf '%s [y/N]: ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
record_state() {
  destination="$1"
  {
    echo "User: $TARGET_USER"
    /usr/bin/id "$TARGET_USER" 2>&1 || true
    /usr/bin/dscl . -read /Groups/admin GroupMembership 2>&1 || true
  } > "$destination"
}
run_action() {
  description="$1"; shift
  ACTIONS=$((ACTIONS + 1)); log "$description"
  if $DRY_RUN; then
    printf 'DRY-RUN:' >> "$LOG"; for arg in "$@"; do printf ' %q' "$arg" >> "$LOG"; done; printf '\n' >> "$LOG"; return 0
  fi
  if "$@" >> "$LOG" 2>&1; then log "SUCCESS: $description"; return 0; fi
  FAILURES=$((FAILURES + 1)); log "WARNING: $description failed"; return 1
}

record_state "$BEFORE"
if ! confirm "Apply admin membership action '$ACTION' to $TARGET_USER?"; then log "Repair cancelled."; exit 10; fi

if [ "$ACTION" = "add" ]; then
  run_action "Adding $TARGET_USER to the admin group" /usr/sbin/dseditgroup -o edit -a "$TARGET_USER" -t user admin || true
else
  ADMIN_MEMBERS=$(/usr/bin/dscl . -read /Groups/admin GroupMembership 2>/dev/null | cut -d: -f2-)
  ADMIN_COUNT=$(printf '%s\n' "$ADMIN_MEMBERS" | awk '{print NF}')
  if [ "$ADMIN_COUNT" -le 1 ]; then log "Refusing to remove the last local administrator."; exit 20; fi
  run_action "Removing $TARGET_USER from the admin group" /usr/sbin/dseditgroup -o edit -d "$TARGET_USER" -t user admin || true
fi

record_state "$AFTER"
if [ "$FAILURES" -gt 0 ]; then log "Repair completed with $FAILURES warning(s)."; exit 20; fi
log "Repair completed successfully. Actions performed: $ACTIONS"
exit 0
