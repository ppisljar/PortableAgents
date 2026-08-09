#!/usr/bin/env bash
# Deploy a built payload (from build.sh) onto a drive.
#
# exFAT/FAT — the cross-platform default for USB sticks — supports NEITHER symlinks NOR hardlinks,
# but Node and git ship plenty of both. So build to a normal filesystem first (APFS/ext4), then:
#   bash deploy.sh ./dist /Volumes/USB --exfat     # flatten links -> real files (portable, larger)
#   bash deploy.sh ./dist /mnt/ntfs                # keep links (APFS/ext4/NTFS) -> compact
set -uo pipefail
SRC="${1:?Usage: bash deploy.sh <dist-dir> <target-dir> [--exfat]}"
DST="${2:?Usage: bash deploy.sh <dist-dir> <target-dir> [--exfat]}"
MODE="${3:-}"
[ -d "$SRC" ] || { echo "source not found: $SRC"; exit 1; }
mkdir -p "$DST"

if [ "$MODE" = "--exfat" ]; then
  nsym=$(find "$SRC" -type l 2>/dev/null | wc -l | tr -d ' ')
  echo "==> exFAT deploy: dereferencing symlinks ($nsym) + materializing hardlinks as real files."
  echo "    (git/node duplicate their bundled binaries here — expect the payload to grow.)"
  # cp -RL: follow symlinks (copy their targets); hardlinked files become independent copies.
  # exFAT carries no unix perms — cp may warn but still copies the data. Portable (macOS + Linux cp).
  cp -RL "$SRC"/. "$DST"/ || echo "  (perm warnings are expected on exFAT — data still copied)"
else
  echo "==> deploy (preserving symlinks — target must support them: APFS/ext4/NTFS)."
  cp -R "$SRC"/. "$DST"/
fi

echo "==> done. target size: $(du -sh "$DST" 2>/dev/null | cut -f1)"
echo "    run:  bash \"$DST/start.sh\"   |   web: bash \"$DST/start_web.sh\""
