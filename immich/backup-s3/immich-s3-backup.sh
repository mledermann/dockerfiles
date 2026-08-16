#!/usr/bin/env bash
#
# immich-s3-backup.sh — sync the Immich photo library to S3.
#
# Backs up originals and database dumps; skips thumbs/ and encoded-video/,
# which Immich regenerates from the originals.
#
# Usage:
#   immich-s3-backup.sh                 # sync to S3
#   immich-s3-backup.sh --dry-run       # show what would transfer, change nothing
#   immich-s3-backup.sh --prune         # also delete remote objects gone locally
#   immich-s3-backup.sh --restore DEST  # pull the backup back down into DEST
#
set -euo pipefail

# ---------------------------------------------------------------- configuration
SRC="${IMMICH_SRC:-/media/photos/library}"
BUCKET="${IMMICH_BUCKET:-photos-backup-816269513269-us-east-2-an}"
PREFIX="${IMMICH_PREFIX:-immich}"
PROFILE="${AWS_PROFILE:-photos-backup}"
REGION="${AWS_REGION:-us-east-2}"
STORAGE_CLASS="${IMMICH_STORAGE_CLASS:-STANDARD_IA}"

# Directories Immich can rebuild from the originals. Excluded to save storage,
# request charges, and roughly 7,700 objects of comparison work per run.
EXCLUDES=(thumbs encoded-video)

# Subdirectories that must exist and be non-empty for the source to be
# considered healthy. Guards against syncing an unmounted or half-mounted disk.
REQUIRED_DIRS=(library backups)
MIN_FILES="${IMMICH_MIN_FILES:-1000}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/immich-s3-backup"
LOG_FILE="$STATE_DIR/backup.log"
LOCK_FILE="$STATE_DIR/backup.lock"

# ---------------------------------------------------------------------- helpers
mkdir -p "$STATE_DIR"

log() { printf '%s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" | tee -a "$LOG_FILE" >&2; }
die() { log "ERROR: $*"; exit 1; }

DRY_RUN=0
PRUNE=0
RESTORE_DEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=1; shift ;;
    --prune)    PRUNE=1; shift ;;
    --restore)  RESTORE_DEST="${2:-}"; [[ -n "$RESTORE_DEST" ]] || die "--restore needs a destination directory"; shift 2 ;;
    -h|--help)  sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          die "unknown argument: $1" ;;
  esac
done

# --------------------------------------------------------------------- preflight
command -v aws >/dev/null 2>&1 || die "aws CLI not found on PATH — see setup notes"

export AWS_PROFILE="$PROFILE"
export AWS_REGION="$REGION"

# Resolve credentials early so an expired or misconfigured profile fails here,
# with a clear message, rather than partway through a 18G transfer.
if ! caller_arn="$(aws sts get-caller-identity --query Arn --output text 2>&1)"; then
  die "could not authenticate with profile '$PROFILE': $caller_arn"
fi
log "authenticated as $caller_arn"

case "$caller_arn" in
  *:assumed-role/s3-photos-bucket-readwrite/*) ;;
  *) log "WARNING: expected to be running as s3-photos-bucket-readwrite, got $caller_arn" ;;
esac

aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1 \
  || die "bucket $BUCKET is not reachable with these credentials"

# ------------------------------------------------------------------------ restore
if [[ -n "$RESTORE_DEST" ]]; then
  mkdir -p "$RESTORE_DEST"
  if [[ -n "$(ls -A "$RESTORE_DEST" 2>/dev/null)" ]]; then
    die "restore destination $RESTORE_DEST is not empty — refusing to overwrite"
  fi
  log "restoring s3://$BUCKET/$PREFIX/ -> $RESTORE_DEST"
  aws s3 sync "s3://$BUCKET/$PREFIX/" "$RESTORE_DEST/" --no-progress
  log "restore complete — stop Immich, replace the library, then restore the DB dump from backups/"
  exit 0
fi

# ------------------------------------------------------------- source validation
[[ -d "$SRC" ]] || die "source directory $SRC does not exist"

for d in "${REQUIRED_DIRS[@]}"; do
  [[ -d "$SRC/$d" ]] || die "expected subdirectory $SRC/$d is missing — is the disk mounted?"
done

# A mount that vanished shows up as a nearly empty tree. Bail out before a
# --prune run mistakes that for a legitimate mass deletion.
file_count="$(find "$SRC/library" -type f ! -name '.immich' 2>/dev/null | wc -l)"
if (( file_count < MIN_FILES )); then
  die "only $file_count files under $SRC/library (expected >= $MIN_FILES) — refusing to sync"
fi

if [[ ! -r "$SRC/library" ]]; then
  die "cannot read $SRC/library — is $(id -un) still in the immich group?"
fi

# ---------------------------------------------------------------------- the sync
sync_args=(
  "$SRC/" "s3://$BUCKET/$PREFIX/"
  --storage-class "$STORAGE_CLASS"
  --no-progress
)

for d in "${EXCLUDES[@]}"; do
  sync_args+=(--exclude "$d/*")
done

(( PRUNE ))   && sync_args+=(--delete)
(( DRY_RUN )) && sync_args+=(--dryrun)

# Single-instance guard: a nightly timer must not stack on a run that is still
# working through a large first upload.
exec 9>"$LOCK_FILE"
flock -n 9 || die "another backup is already running (lock: $LOCK_FILE)"

log "starting sync: $SRC -> s3://$BUCKET/$PREFIX/ (class=$STORAGE_CLASS, prune=$PRUNE, dry-run=$DRY_RUN)"
log "excluding: ${EXCLUDES[*]}"

started=$SECONDS
set +e
aws s3 sync "${sync_args[@]}" 2>&1 | tee -a "$LOG_FILE"
rc=${PIPESTATUS[0]}
set -e
elapsed=$(( SECONDS - started ))

if (( rc != 0 )); then
  die "sync failed with exit code $rc after ${elapsed}s"
fi

log "sync completed in ${elapsed}s"

if (( ! DRY_RUN )); then
  remote="$(aws s3 ls "s3://$BUCKET/$PREFIX/" --recursive --summarize 2>/dev/null | tail -2 | tr -s ' ')"
  log "remote state: $(echo "$remote" | tr '\n' ' ')"
fi
