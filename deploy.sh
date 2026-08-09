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
command -v rsync >/dev/null || { echo "rsync required"; exit 1; }
[ -d "$SRC" ] || { echo "source not found: $SRC"; exit 1; }
mkdir -p "$DST"

if [ "$MODE" = "--exfat" ]; then
  nsym=$(find "$SRC" -type l 2>/dev/null | wc -l | tr -d ' ')
  echo "==> exFAT deploy: dereferencing symlinks ($nsym) + materializing hardlinks as real files."
  echo "    (git/node duplicate their bundled binaries here — expect the payload to grow.)"
  # -L: copy the referent of each symlink (no symlinks land on the target).
  # rsync copies hardlinked files as independent files unless -H is given (we omit it on purpose).
  # --no-perms/owner/group: exFAT has no unix metadata. exit 23 = some (broken) symlinks skipped -> OK.
  rsync -rL --no-perms --no-owner --no-group --info=progress2 "$SRC"/ "$DST"/
  rc=$?; [ $rc -eq 0 ] || [ $rc -eq 23 ] || { echo "rsync failed ($rc)"; exit $rc; }
else
  echo "==> deploy (preserving symlinks — target must support them: APFS/ext4/NTFS)."
  rsync -a --info=progress2 "$SRC"/ "$DST"/
fi

echo "==> done. target size: $(du -sh "$DST" 2>/dev/null | cut -f1)"
echo "    run:  bash \"$DST/start.sh\"   |   web: bash \"$DST/start_web.sh\""
