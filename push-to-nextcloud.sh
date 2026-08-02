#!/usr/bin/env bash
# Push the VHS business docs to Nextcloud over WebDAV.
#
# Credentials are read from ~/.vhs-nextcloud-creds, which must contain:
#   NC_USER=yourusername
#   NC_PASS=your-nextcloud-app-password
#
# Generate the app password at Settings > Personal > Security, never use the
# real account password here. The creds file should be mode 600.
#
# Usage: bash ~/vhs-site/push-to-nextcloud.sh

set -euo pipefail

CREDS="$HOME/.vhs-nextcloud-creds"
SRC="$HOME/vhs-site"
REMOTE_DIR="VHS-Business"

# LAN address is used rather than cloud.173842069.xyz so the upload does not
# make a round trip out through the Cloudflare tunnel and back.
BASE="http://192.168.4.125:30027"

if [[ ! -f "$CREDS" ]]; then
  echo "Missing $CREDS" >&2
  echo "Create it with:" >&2
  echo "  umask 077 && printf 'NC_USER=%s\\nNC_PASS=%s\\n' 'user' 'apppass' > $CREDS" >&2
  exit 1
fi

# Refuse to run if the creds file is group/world readable.
perms=$(stat -c '%a' "$CREDS")
if [[ "$perms" != "600" && "$perms" != "400" ]]; then
  echo "Refusing to run: $CREDS is mode $perms, should be 600." >&2
  echo "Fix with: chmod 600 $CREDS" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CREDS"
: "${NC_USER:?NC_USER not set in $CREDS}"
: "${NC_PASS:?NC_PASS not set in $CREDS}"

DAV="$BASE/remote.php/dav/files/$NC_USER"

# -f makes curl exit nonzero on HTTP errors so set -e actually catches them.
# Credentials go via --user on stdin-free args; they are never echoed.
say() { printf '  %-26s %s\n' "$1" "$2"; }

echo "Uploading to $BASE  ->  /$REMOTE_DIR"

# MKCOL is idempotent in practice: 201 created, 405 already exists. Both fine.
code=$(curl -s -o /dev/null -w '%{http_code}' -X MKCOL \
  --user "$NC_USER:$NC_PASS" "$DAV/$REMOTE_DIR" || true)
case "$code" in
  201) say "$REMOTE_DIR/" "created" ;;
  405) say "$REMOTE_DIR/" "already exists" ;;
  401) echo "Auth failed (401). Check NC_USER and the app password." >&2; exit 1 ;;
  *)   echo "Unexpected $code creating $REMOTE_DIR" >&2; exit 1 ;;
esac

failed=0
for f in PROJECT-PRIMER.md README.md index.html intake-form.html; do
  if [[ ! -f "$SRC/$f" ]]; then
    say "$f" "SKIPPED, not found"; failed=1; continue
  fi
  code=$(curl -s -o /dev/null -w '%{http_code}' -T "$SRC/$f" \
    --user "$NC_USER:$NC_PASS" "$DAV/$REMOTE_DIR/$f" || true)
  case "$code" in
    201) say "$f" "uploaded" ;;
    204) say "$f" "updated" ;;
    *)   say "$f" "FAILED ($code)"; failed=1 ;;
  esac
done

if [[ $failed -eq 0 ]]; then
  echo
  echo "Done. Open https://cloud.173842069.xyz/apps/files/?dir=/$REMOTE_DIR"
else
  echo
  echo "Finished with errors, see above." >&2
  exit 1
fi
