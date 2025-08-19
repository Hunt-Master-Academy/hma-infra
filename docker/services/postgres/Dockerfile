FROM postgres:16-alpine

# Install common tools
RUN apk add --no-cache bash curl ca-certificates

# Copy init scripts (schemas, tables, functions, seeds)
COPY init /docker-entrypoint-initdb.d

# Healthcheck is handled by compose
