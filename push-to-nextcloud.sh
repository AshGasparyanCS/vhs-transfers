#!/usr/bin/env bash
# Push the VHS business docs and scripts to Nextcloud so they can be read from
# any machine, not just the OptiPlex.
#
# Credentials come from ~/.vhs-nextcloud-creds:
#   NC_USER='Memory Archives'
#   NC_PASS='xxxxx-xxxxx-xxxxx-xxxxx-xxxxx'
#
# The quotes matter. The username contains a space, and without quotes `source`
# treats the second word as a command and silently leaves the old value set,
# which shows up later as a confusing 401.
#
# Usage: bash ~/vhs-site/push-to-nextcloud.sh

set -euo pipefail

CREDS="$HOME/.vhs-nextcloud-creds"
SRC="$HOME/vhs-site"
REMOTE_DIR="VHS-Business-Docs"

# LAN address, so the upload does not round trip through the Cloudflare tunnel.
BASE="http://192.168.4.125:30027"

FILES=(
  PROJECT-PRIMER.md
  README.md
  New-Delivery.ps1
  Verify-Drive.ps1
  index.html
  intake-form.html
  push-to-nextcloud.sh
)

say() { printf '  %-24s %s\n' "$1" "$2"; }
urlenc() { python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$1"; }

[[ -f "$CREDS" ]] || { echo "Missing $CREDS" >&2; exit 1; }

perms=$(stat -c '%a' "$CREDS")
[[ "$perms" == 600 || "$perms" == 400 ]] || {
  echo "Refusing to run: $CREDS is mode $perms, should be 600." >&2; exit 1; }

# shellcheck disable=SC1090
source "$CREDS"
: "${NC_USER:?NC_USER not set}"
: "${NC_PASS:?NC_PASS not set}"

USER_ENC=$(urlenc "$NC_USER")
DAV="$BASE/remote.php/dav/files/$USER_ENC"
DIR_ENC=$(urlenc "$REMOTE_DIR")

echo "Uploading to $BASE as '$NC_USER' -> /$REMOTE_DIR"

code=$(curl -s -o /dev/null -w '%{http_code}' -X MKCOL \
  --user "$NC_USER:$NC_PASS" "$DAV/$DIR_ENC" || true)
case "$code" in
  201) say "$REMOTE_DIR/" "created" ;;
  405) say "$REMOTE_DIR/" "already exists" ;;
  401) echo "Auth failed (401). Check the username spelling and app password." >&2; exit 1 ;;
  *)   echo "Unexpected $code creating $REMOTE_DIR" >&2; exit 1 ;;
esac

failed=0
for f in "${FILES[@]}"; do
  if [[ ! -f "$SRC/$f" ]]; then
    say "$f" "SKIPPED, not found"; failed=1; continue
  fi
  code=$(curl -s -o /dev/null -w '%{http_code}' -T "$SRC/$f" \
    --user "$NC_USER:$NC_PASS" "$DAV/$DIR_ENC/$(urlenc "$f")" || true)
  case "$code" in
    201) say "$f" "uploaded" ;;
    204) say "$f" "updated" ;;
    *)   say "$f" "FAILED ($code)"; failed=1 ;;
  esac
done

echo
if [[ $failed -eq 0 ]]; then
  echo "Done. Open it at:"
  echo "  https://cloud.173842069.xyz/apps/files/?dir=/$REMOTE_DIR"
else
  echo "Finished with errors, see above." >&2
  exit 1
fi
