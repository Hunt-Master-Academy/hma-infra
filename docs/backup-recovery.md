
# Backup & Recovery

## Overview
This document describes backup and disaster recovery procedures for the HMA infrastructure, including RPO/RTO targets and operational steps for both database and cache layers.

## Backup Procedures
- **PostgreSQL**: Nightly logical backups via `pg_dump` and weekly full volume snapshots. Automated via `scripts/backup-database.sh` and scheduled in CI/CD.
- **Redis**: Daily RDB snapshot and AOF persistence. Automated via `scripts/backup/backup-redis.sh`.
- **MinIO**: Daily bucket sync to offsite S3-compatible storage.

## Recovery Procedures
- **Restore DB**: Use `scripts/restore-database.sh` for full or point-in-time recovery. Validate with `test-restore.sh`.
- **Restore Redis**: Load latest RDB/AOF file into running container.
- **Restore MinIO**: Sync from backup bucket using MinIO client.

## RPO/RTO Targets

| Service      | RPO         | RTO         |
|--------------|-------------|-------------|
| PostgreSQL   | 24h (MVP)   | 2h          |
| Redis        | 24h         | 1h          |
| MinIO        | 24h         | 2h          |

## Verification
- Backups are tested weekly via `scripts/backup/test-restore.sh`.
- Backup logs are stored in `/logs/backup/` and monitored for failures.

## Future Improvements
- Add continuous backup for production DBs
- Offsite backup rotation and retention policy
