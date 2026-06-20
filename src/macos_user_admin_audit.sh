#!/bin/bash
set -u

OUTPUT_DIR=""
usage() { echo "Usage: macos_user_admin_audit.sh [--output DIR]"; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done
[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./macos-user-audit-$STAMP}"
mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/user-audit.txt"
CSV="$OUTPUT_DIR/users.csv"
JSON="$OUTPUT_DIR/summary.json"
ERRORS="$OUTPUT_DIR/command-errors.log"
: > "$REPORT"; : > "$ERRORS"
echo 'username,uid,admin,secure_token,filevault_enabled,home_exists,shell' > "$CSV"

section() { title="$1"; shift; { printf '\n===== %s =====\n' "$title"; "$@"; } >> "$REPORT" 2>> "$ERRORS" || true; }
section "Collection metadata" /bin/bash -c 'date -u +%Y-%m-%dT%H:%M:%SZ; hostname; sw_vers; id'
section "Local users" /usr/bin/dscl . -list /Users UniqueID
section "Admin group" /usr/bin/dscl . -read /Groups/admin GroupMembership
section "FileVault users" /usr/bin/fdesetup list
section "Recent logins" /usr/bin/last -20
section "Failed login records" /bin/bash -c 'log show --last 24h --style compact --predicate "eventMessage CONTAINS[c] \"authentication failed\" OR eventMessage CONTAINS[c] \"login failed\"" 2>/dev/null | tail -n 1000'

ADMIN_USERS="$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | cut -d: -f2-)"
FV_FILE="$OUTPUT_DIR/filevault-users.tmp"
fdesetup list 2>/dev/null | awk -F, '{print $1}' | sort -u > "$FV_FILE"
TOTAL=0
ADMINS=0
TOKEN_USERS=0
MISSING_HOMES=0

while read -r username uid; do
  case "$uid" in ''|*[!0-9]*) continue ;; esac
  [ "$uid" -lt 500 ] && continue
  case "$username" in _*|daemon|nobody|root) continue ;; esac
  TOTAL=$((TOTAL + 1))
  home=$(dscl . -read "/Users/$username" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
  shell=$(dscl . -read "/Users/$username" UserShell 2>/dev/null | awk '{print $2}')
  admin=false
  echo " $ADMIN_USERS " | grep -q " $username " && { admin=true; ADMINS=$((ADMINS + 1)); }
  token="Unknown"
  token_output=$(sysadminctl -secureTokenStatus "$username" 2>&1 || true)
  echo "$token_output" | grep -qi ENABLED && { token="Enabled"; TOKEN_USERS=$((TOKEN_USERS + 1)); }
  echo "$token_output" | grep -qi DISABLED && token="Disabled"
  fv=false
  grep -Fxq "$username" "$FV_FILE" && fv=true
  home_exists=false
  [ -d "$home" ] && home_exists=true || MISSING_HOMES=$((MISSING_HOMES + 1))
  printf '"%s",%s,"%s","%s","%s","%s","%s"\n' "$username" "$uid" "$admin" "$token" "$fv" "$home_exists" "$shell" >> "$CSV"
done <<EOF
$(dscl . -list /Users UniqueID 2>>"$ERRORS")
EOF

OVERALL="Healthy"
[ "$MISSING_HOMES" -gt 0 ] && OVERALL="Attention required"
cat > "$JSON" <<EOF
{
  "collected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "interactive_users": $TOTAL,
  "administrator_users": $ADMINS,
  "users_with_secure_token": $TOKEN_USERS,
  "users_with_missing_home_folder": $MISSING_HOMES,
  "overall_status": "$OVERALL"
}
EOF
rm -f "$FV_FILE"
printf '\nUser and admin audit completed: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
