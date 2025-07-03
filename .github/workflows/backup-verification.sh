# File: .github/workflows/backup-verification.yml
# Automated backup verification
name: Backup Verification

on:
  schedule:
    - cron: '0 6 * * 1'  # Weekly on Monday
  workflow_dispatch:

jobs:
  verify-backups:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Test backup restoration
      run: |
        docker-compose -f docker-compose.test.yml up -d
        ./scripts/backup/test-restore.sh
        
    - name: Verify backup integrity
      run: |
        ./scripts/backup/verify-checksums.sh
        
    - name: Report results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: backup-verification-report
        path: reports/backup-verification-*.html