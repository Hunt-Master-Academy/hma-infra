# Docker Secrets Directory

This directory contains secret files for Docker Compose secrets management.

## Files (DO NOT COMMIT)

- `CISO_DJANGO_SECRET` - Django SECRET_KEY for CISO Assistant
- `CISO_DB_PASSWORD` - PostgreSQL password for ciso_admin user
- `MINIO_ACCESS_KEY` - MinIO S3 access key
- `MINIO_SECRET_KEY` - MinIO S3 secret key
- `SMTP_PASSWORD` - Email SMTP password

## Usage

Secrets are referenced in docker-compose.compliance.yml:

```yaml
secrets:
  ciso_django_secret:
    file: ./secrets/CISO_DJANGO_SECRET
```

And accessed in containers as files:

```yaml
environment:
  DJANGO_SECRET_KEY_FILE: /run/secrets/ciso_django_secret
```

## Security

- Add `secrets/` to `.gitignore`
- Set file permissions: `chmod 600 secrets/*`
- Rotate secrets regularly
- Use Docker secrets or external vaults in production
