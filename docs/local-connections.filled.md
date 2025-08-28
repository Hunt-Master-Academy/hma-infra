# Local Connections (Filled)

Generated: Sun Aug 24 15:40:50 EDT 2025

## PostgreSQL
- Host: localhost
- Port: 5432
- Database: 
- User: 
- Password: 
- From containers: host=postgres port=5432
- Gamecalls URL:
  postgresql://:@localhost:5432/?options=-c%20search_path=game_calls
- Hunt-Strategy URL:
  postgresql://:@localhost:5432/?options=-c%20search_path=hunt_strategy

## Redis
- Host: localhost
- Port: 6379
- URL: redis://localhost:6379
- Password: 35GXWbylcb1FOlHopmH5KOkKX4n1Aug7661bBbR6Axc=

## MinIO (S3)
- API: http://localhost:9000
- Console: http://localhost:9001
- Access Key: minioadmin
- Secret Key: yM7h1z4buD1BONLUSnjjCe2jw5O4NnMV2doKkKaWXj4=
- Suggested bucket: hma-content-alpha

## Content Bridge
- Health: http://localhost:8090/health
- Audio:  http://localhost:8090/api/audio
- Icons:  http://localhost:8090/api/icons
- Research: http://localhost:8090/api/research
- Manifest: http://localhost:8090/api/manifest
- Mode: local
- CDN_URL: http://localhost:8090
- Local content path (host): /home/xbyooki/projects/hma-content
