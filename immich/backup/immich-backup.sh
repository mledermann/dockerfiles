#!/usr/bin/env bash
#
# Immich backup -> /mnt/backups/highway/immich  (CIFS share on NAS 192.168.0.206)
#
# The two halves of an Immich backup need different handling:
#
#   1. Postgres  -> logical pg_dump. The raw data directory under
#                   /media/photos/data must NEVER be file-copied while the
#                   server is running; the result is silently inconsistent.
#   2. Library   -> rsync mirror, plus a dated history of anything that was
#                   changed or deleted, so a bad edit or accidental delete
#                   doesn't propagate to the only copy you have.
#
# CIFS cannot store POSIX ownership. Everything lands on the NAS as
# root:root 0755 regardless of what it looked like here. After restoring:
#
#     chown -R immich:immich /media/photos/library
#     chown -R 999:999       /media/photos/data && chmod 0700 /media/photos/data
#
set -euo pipefail

SRC_LIBRARY=/media/photos/library
MOUNT=/mnt/backups
DEST="$MOUNT/highway/immich"
STAGE=/var/backups/immich
PG_CONTAINER=immich_postgres
DB_NAME=immich
DB_USER=postgres
KEEP_DUMP_DAYS=7
KEEP_DUMP_MIN=3
KEEP_HISTORY_DAYS=30

STAMP="$(date +%Y%m%dT%H%M%S)"
log() { printf '%s  %s\n' "$(date '+%F %T')" "$*"; }
die() { printf '%s  ERROR: %s\n' "$(date '+%F %T')" "$*" >&2; exit 1; }

# --- preflight -------------------------------------------------------------
# The CIFS entry is 'nofail,soft', so an unreachable NAS means an empty
# directory rather than an error. Backing up into it would look like success.
mountpoint -q "$MOUNT" || die "$MOUNT not mounted (NAS unreachable?)"
[ -d "$SRC_LIBRARY" ] || die "$SRC_LIBRARY missing"
docker inspect -f '{{.State.Running}}' "$PG_CONTAINER" 2>/dev/null | grep -q true \
    || die "$PG_CONTAINER is not running"

install -d -m 0700 "$STAGE"
install -d "$DEST" "$DEST/db" "$DEST/library" "$DEST/history"

probe="$DEST/.write-probe-$$"
: > "$probe" 2>/dev/null || die "$DEST not writable"
rm -f "$probe"

# --- 1. database -----------------------------------------------------------
dump="$STAGE/immich-db-$STAMP.sql.gz"
log "dumping database -> $dump"

# No -t on docker exec. The Immich docs show it, but allocating a TTY
# translates LF -> CRLF and silently corrupts the gzip stream when piped.
docker exec "$PG_CONTAINER" \
    pg_dump --clean --if-exists --dbname="$DB_NAME" --username="$DB_USER" \
    | gzip > "$dump"

gzip -t "$dump" || die "dump failed integrity check: $dump"
size=$(stat -c%s "$dump")
[ "$size" -gt 1000000 ] || die "dump suspiciously small (${size}B) - aborting"
log "dump ok ($(numfmt --to=iec "$size"))"

# Keep a short local history so a corrupt NAS copy isn't the only fallback.
ls -1t "$STAGE"/immich-db-*.sql.gz 2>/dev/null \
    | tail -n +$((KEEP_LOCAL_DUMPS + 1)) | xargs -r rm -f

# --- 2. rsync --------------------------------------------------------------
# -rlt rather than -a: CIFS cannot accept perms/owner/group, and asking for
# them makes rsync fail noisily on every single file. --modify-window absorbs
# the coarser timestamp granularity on the share.
RSYNC_OPTS=(
    -rlt --partial --human-readable
    --modify-window=1
    --no-perms --no-owner --no-group
)

log "syncing database dumps"
rsync "${RSYNC_OPTS[@]}" --delete "$STAGE/" "$DEST/db/"

log "syncing library"
# 'backups/' is Immich's own nightly dump directory - redundant here, since
# this script takes its own verified dump into db/.
# thumbs/ and encoded-video/ are regenerable; uncomment to trade restore time
# for backup size once the library outgrows the share.
rsync "${RSYNC_OPTS[@]}" \
    --delete \
    --backup --backup-dir="$DEST/history/$STAMP" \
    --exclude='backups/' \
    --exclude='*.tmp' \
    "$SRC_LIBRARY/" "$DEST/library/"
#   --exclude='thumbs/' \
#   --exclude='encoded-video/' \

# rsync creates the backup-dir even on a no-change run; drop it if empty.
rmdir "$DEST/history/$STAMP" 2>/dev/null || true

log "pruning history older than ${KEEP_HISTORY_DAYS}d"
find "$DEST/history" -mindepth 1 -maxdepth 1 -type d \
    -mtime +"$KEEP_HISTORY_DAYS" -exec rm -rf {} + 2>/dev/null || true

# --- manifest --------------------------------------------------------------
{
    echo "last_success   $(date '+%F %T %Z')"
    echo "host           $(hostname)"
    echo "immich_version $(grep -oP '(?<=^IMMICH_VERSION=).*' /home/mark/projects/dockerfiles/immich/.env 2>/dev/null || echo unknown)"
    echo "library_bytes  $(du -sb "$SRC_LIBRARY" | cut -f1)"
    echo "latest_dump    $(basename "$dump")"
    echo
    echo "restore: gunzip -c db/<dump> | docker exec -i immich_postgres psql -U postgres -d immich"
    echo "then:    chown -R immich:immich /media/photos/library"
} > "$DEST/MANIFEST.txt"

log "backup complete"
