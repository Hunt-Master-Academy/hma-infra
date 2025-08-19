#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
COMPOSE="docker compose -f $ROOT_DIR/docker/docker-compose.yml"

cmd=${1:-apply}

psql_exec() {
  # -X: do not read startup files, -q: quiet, -v ON_ERROR_STOP=1: stop on error
  $COMPOSE exec -T postgres psql -U "${POSTGRES_USER:-hma_admin}" -d "${POSTGRES_DB:-huntmaster}" -X -q -v ON_ERROR_STOP=1 "$@"
}

list_migrations() {
  ls -1 "$ROOT_DIR"/database/migrations/V*.sql 2>/dev/null | sort || true
}

applied_versions() {
  psql_exec -Atqc "SELECT version FROM infra.schema_migrations ORDER BY applied_at;" 2>/dev/null || true
}

apply_migration() {
  local file="$1"
  echo "[migrate] applying $(basename "$file")"
  cat "$file" | psql_exec
}

case "$cmd" in
  apply)
    # Always attempt to apply V0001 first (idempotent)
    if [[ -f "$ROOT_DIR/database/migrations/V0001__create_schema_migrations.sql" ]]; then
      apply_migration "$ROOT_DIR/database/migrations/V0001__create_schema_migrations.sql" || true
    fi
    mapfile -t files < <(list_migrations)
    if [[ ${#files[@]} -eq 0 ]]; then
      echo "[migrate] no migration files found"
      exit 0
    fi
  mapfile -t applied < <(applied_versions)
    for f in "${files[@]}"; do
      v=$(basename "$f")
      if printf '%s
' "${applied[@]}" | grep -qx "$v"; then
        echo "[migrate] skipping already applied $v"
        continue
      fi
      apply_migration "$f"
    done
    ;;
  status)
    echo "[migrate] Status (DB vs files)"
    mapfile -t files < <(list_migrations)
  mapfile -t applied < <(applied_versions)
    for f in "${files[@]}"; do
      v=$(basename "$f")
      if printf '%s
' "${applied[@]}" | grep -qx "$v"; then
        echo "  [x] $v"
      else
        echo "  [ ] $v"
      fi
    done
    ;;
  rollback)
    echo "[migrate] rollback not implemented for raw SQL. Consider adding down scripts or adopting Flyway/Liquibase."
    exit 1
    ;;
  *)
    echo "Usage: $0 [apply|status|rollback]" >&2
    exit 2
    ;;
esac
