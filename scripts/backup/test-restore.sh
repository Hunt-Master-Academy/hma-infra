#!/usr/bin/env bats
#
# BATS (Bash Automated Testing System) test for restore-full.sh
#

# Path to the script being tested
SCRIPT_UNDER_TEST="$(dirname "$BATS_TEST_FILENAME")/restore-full.sh"

# setup() is run before each test
setup() {
    # Create a temporary directory for mock backups, restores, and command logs
    BATS_TMPDIR="$(mktemp -d -t restore_test_XXXXXX)"
    export BATS_TMPDIR

    # Create a directory for our mock commands
    mkdir -p "$BATS_TMPDIR/bin"

    # Create mock commands that log their calls and arguments
    cat > "$BATS_TMPDIR/bin/find" <<'EOF'
#!/bin/bash
# Mock find: returns pre-defined paths based on the backup date pattern
BACKUP_DATE_PATTERN=$(echo "$@" | grep -o '[0-9]\{8\}')
if [[ -z "$BACKUP_DATE_PATTERN" ]]; then exit 0; fi

if [[ "$@" == *"/backups/postgres"* ]]; then
    if [ -f "$BATS_TMPDIR/backups/postgres/huntmaster_postgres_${BACKUP_DATE_PATTERN}_120000.sql.gz" ]; then
        echo "$BATS_TMPDIR/backups/postgres/huntmaster_postgres_${BACKUP_DATE_PATTERN}_120000.sql.gz"
    fi
elif [[ "$@" == *"/backups/redis"* ]]; then
    if [ -f "$BATS_TMPDIR/backups/redis/huntmaster_redis_${BACKUP_DATE_PATTERN}_120000.rdb" ]; then
        echo "$BATS_TMPDIR/backups/redis/huntmaster_redis_${BACKUP_DATE_PATTERN}_120000.rdb"
    fi
elif [[ "$@" == *"/backups -name app_data"* ]]; then
    if [ -f "$BATS_TMPDIR/backups/app_data_${BACKUP_DATE_PATTERN}_120000.tar.gz" ]; then
        echo "$BATS_TMPDIR/backups/app_data_${BACKUP_DATE_PATTERN}_120000.tar.gz"
    fi
fi
EOF

    # Mock psql to log the call and capture stdin
    cat > "$BATS_TMPDIR/bin/psql" <<'EOF'
#!/bin/bash
echo "psql called with: $@" >> "$BATS_TMPDIR/command.log"
cat > "$BATS_TMPDIR/psql.stdin.log"
EOF

    # Mock other commands to simply log their execution
    for cmd in redis-cli docker gunzip; do
        echo -e "#!/bin/bash\necho \"$cmd called with: \$@\" >> \"$BATS_TMPDIR/command.log\"" > "$BATS_TMPDIR/bin/$cmd"
        # The gunzip mock needs to output something for the pipe to work
        if [[ "$cmd" == "gunzip" ]]; then
            echo "cat \"\$2\"" >> "$BATS_TMPDIR/bin/$cmd"
        fi
    done

    chmod +x "$BATS_TMPDIR/bin"/*
    export PATH="$BATS_TMPDIR/bin:$PATH"

    # Create fake backup files for a known date
    mkdir -p "$BATS_TMPDIR/backups/postgres"
    mkdir -p "$BATS_TMPDIR/backups/redis"
    echo "fake pg dump content" > "$BATS_TMPDIR/backups/postgres/huntmaster_postgres_20240115_120000.sql.gz"
    echo "fake rdb content" > "$BATS_TMPDIR/backups/redis/huntmaster_redis_20240115_120000.rdb"
    tar -czf "$BATS_TMPDIR/backups/app_data_20240115_120000.tar.gz" --files-from /dev/null
}

# teardown() is run after each test
teardown() {
    rm -rf "$BATS_TMPDIR"
}

@test "restore-full: should fail and show usage if no date is provided" {
    run bash "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "restore-full: should restore all components on the happy path" {
    # Run the script with a valid date and a target directory inside our temp space
    run bash "$SCRIPT_UNDER_TEST" 20240115 "$BATS_TMPDIR/restore"

    [ "$status" -eq 0 ]

    # Verify mocks were called correctly
    grep -q "gunzip called with: -c" "$BATS_TMPDIR/command.log"
    grep -q "psql called with: -h postgres -U huntmaster -d huntmaster" "$BATS_TMPDIR/command.log"
    grep -q "redis-cli called with: -h redis FLUSHALL" "$BATS_TMPDIR/command.log"
    grep -q "docker called with: cp $BATS_TMPDIR/backups/redis/huntmaster_redis_20240115_120000.rdb huntmaster-redis:/data/dump.rdb" "$BATS_TMPDIR/command.log"
    grep -q "docker called with: restart huntmaster-redis" "$BATS_TMPDIR/command.log"

    # Verify psql received the correct data from gunzip
    [ -f "$BATS_TMPDIR/psql.stdin.log" ]
    grep -q "fake pg dump content" "$BATS_TMPDIR/psql.stdin.log"

    # Verify app data was restored to the specified directory
    [ -d "$BATS_TMPDIR/restore" ]
    [[ "$output" == *"Application data restored to $BATS_TMPDIR/restore"* ]]
}

@test "restore-full: should show warning if postgres backup is not found" {
    # Run with a date for which no backup exists
    run bash "$SCRIPT_UNDER_TEST" 20240116

    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING: PostgreSQL backup not found"* ]]

    # Verify psql was NOT called
    ! grep -q "psql called" "$BATS_TMPDIR/command.log" 2>/dev/null
}

@test "restore-full: should show warning if redis backup is not found" {
    run bash "$SCRIPT_UNDER_TEST" 20240116

    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING: Redis backup not found"* ]]

    # Verify redis-cli and docker were NOT called for restore
    ! grep -q "redis-cli called" "$BATS_TMPDIR/command.log" 2>/dev/null
    ! grep -q "docker called with: cp" "$BATS_TMPDIR/command.log" 2>/dev/null
}

@test "restore-full: should use default restore target if not provided" {
    run bash "$SCRIPT_UNDER_TEST" 20240115

    [ "$status" -eq 0 ]
    [[ "$output" == *"Application data restored to /workspace/restore"* ]]
}

