# Immich → S3 backup

Nightly sync of `/media/photos/library` to `s3://photos-backup-816269513269-us-east-2-an/immich/`,
running as `arn:aws:iam::816269513269:role/s3-photos-bucket-readwrite`.

## What gets backed up

| Path | Size | Files | Included | Why |
|---|---|---|---|---|
| `library/` | 18G | 4053 | yes | Original photos and videos — irreplaceable |
| `backups/` | 486M | 15 | yes | Immich Postgres dumps — albums, faces, metadata |
| `upload/` | 16M | 1 | yes | Staging area for in-flight uploads |
| `profile/` | 8K | 1 | yes | User avatars |
| `thumbs/` | 1.4G | 7684 | no | Immich regenerates from originals |
| `encoded-video/` | 1.6G | 53 | no | Immich re-transcodes from originals |

Excluding the derivatives drops ~3G and ~7,700 objects from every run.

A restore needs both halves: the files **and** a database dump from `backups/`.
The originals alone will import as an unsorted pile with no albums or faces.

## Setup

### 1. AWS CLI

Not currently installed. Run in your sudo window:

```bash
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
aws --version
```

### 2. IAM

Policies are in `iam/`. The trust policy names an IAM user `immich-backup` —
rename it there if you use a different one.

```bash
aws iam create-user --user-name immich-backup

aws iam put-user-policy --user-name immich-backup \
  --policy-name assume-photos-backup-role \
  --policy-document file://iam/user-policy.json

aws iam update-assume-role-policy \
  --role-name s3-photos-bucket-readwrite \
  --policy-document file://iam/role-trust.json

aws iam put-role-policy --role-name s3-photos-bucket-readwrite \
  --policy-name photos-bucket-readwrite \
  --policy-document file://iam/role-permissions.json

aws iam create-access-key --user-name immich-backup
```

The user gets `sts:AssumeRole` and nothing else, so the keys on this box are
worthless without the role, and revoking the role's policy cuts off access
without touching the machine.

### 3. Credentials

`~/.aws/config`:

```ini
[profile photos-backup]
role_arn       = arn:aws:iam::816269513269:role/s3-photos-bucket-readwrite
source_profile = photos-base
region         = us-east-2

[profile photos-base]
region = us-east-2
```

`~/.aws/credentials` — from step 2's `create-access-key`:

```ini
[photos-base]
aws_access_key_id     = AKIA...
aws_secret_access_key = ...
```

```bash
chmod 600 ~/.aws/credentials
aws sts get-caller-identity --profile photos-backup
```

That last command should print an ARN containing `assumed-role/s3-photos-bucket-readwrite`.

### 4. First run

```bash
./immich-s3-backup.sh --dry-run   # verify the file list
./immich-s3-backup.sh             # ~18.5G, expect a few hours on a home upstream
```

The first upload is the long one; subsequent runs only move new photos and the
nightly database dump.

### 5. Schedule it

This directory is the source of truth; systemd runs installed copies, matching
the sibling `backup/` setup. Re-run these after editing anything here.

```bash
sudo install -m 0755 immich-s3-backup.sh /usr/local/bin/immich-s3-backup.sh
sudo install -m 0644 immich-s3-backup.service /etc/systemd/system/
sudo install -m 0644 immich-s3-backup.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now immich-s3-backup.timer
```

Enable the timer only. The service carries `WantedBy=multi-user.target`, so
enabling it as well would fire a backup at every boot.

Runs at 03:30 local — Immich dumps at 21:00 and the NAS job takes 22:30, so this
goes last with five hours of slack.

Then do one run under systemd. Running the script as yourself does not exercise
the sandbox, and `ProtectHome` blocking the AWS credential cache is exactly the
kind of failure that only surfaces here:

```bash
sudo systemctl start immich-s3-backup.service
journalctl -u immich-s3-backup.service -n 30 --no-pager
systemctl list-timers immich-s3-backup.timer
```

## Usage

Once installed the script is on `PATH`:

```bash
immich-s3-backup.sh              # sync
immich-s3-backup.sh --dry-run    # preview, changes nothing
immich-s3-backup.sh --prune      # also delete remote objects gone locally
immich-s3-backup.sh --restore /media/photos/restored
```

Logs: `~/.local/state/immich-s3-backup/backup.log`, and `journalctl -u immich-s3-backup`.

### On `--prune`

Off by default, and deliberately so. Without it, a photo you delete locally —
accidentally, or via ransomware — stays in S3. That costs a little storage and
buys you a real recovery path. Only reach for `--prune` when you have genuinely
culled the library and want S3 to match.

The script refuses to run if `library/` holds fewer than 1000 files, which stops
an unmounted disk from looking like a mass deletion.

## Safety checks

The script fails closed rather than backing up garbage:

- credentials resolve before any transfer starts, so a bad profile fails in seconds rather than mid-upload
- warns if the resolved identity is not the expected role
- requires `library/` and `backups/` to exist — catches an unmounted disk
- requires ≥1000 files under `library/`
- `flock` prevents a nightly run from stacking on a slow one
- `--restore` refuses a non-empty destination

## Cost

At `STANDARD_IA`, 18.5G runs about **$0.23/month**. To cut it further, set a
lifecycle rule moving objects to `GLACIER_IR` after 90 days (~$0.07/month) —
better done as a bucket lifecycle policy than by changing `IMMICH_STORAGE_CLASS`,
so the tiering applies to what is already uploaded.

Both classes bill a 128KB minimum per object and have a minimum storage duration
(30 days for `STANDARD_IA`, 90 for `GLACIER_IR`). Fine for photos; it is the main
reason `thumbs/` is excluded, since thousands of small files pay that minimum badly.

## Configuration

Environment overrides, all optional:

| Variable | Default |
|---|---|
| `IMMICH_SRC` | `/media/photos/library` |
| `IMMICH_BUCKET` | `photos-backup-816269513269-us-east-2-an` |
| `IMMICH_PREFIX` | `immich` |
| `IMMICH_STORAGE_CLASS` | `STANDARD_IA` |
| `IMMICH_MIN_FILES` | `1000` |
| `AWS_PROFILE` | `photos-backup` |
| `AWS_REGION` | `us-east-2` |

## Verifying a restore

Worth doing once, now, rather than discovering a problem when you need it:

```bash
immich-s3-backup.sh --restore /tmp/restore-test
ls /tmp/restore-test/backups/          # a recent dump should be here
diff <(cd /media/photos/library/library && find . -type f | sort) \
     <(cd /tmp/restore-test/library    && find . -type f | sort)
```
