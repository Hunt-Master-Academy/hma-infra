#!/bin/bash
# Generate self-signed certificates for Wazuh stack (local development)

# Root CA
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout root-ca-key.pem -out root-ca.pem \
  -subj "/C=US/ST=Dev/L=Local/O=HMA/OU=Compliance/CN=Wazuh Root CA"

# Dashboard certificate
openssl req -nodes -newkey rsa:2048 \
  -keyout dashboard-key.pem -out dashboard.csr \
  -subj "/C=US/ST=Dev/L=Local/O=HMA/OU=Compliance/CN=hma-wazuh-dashboard"

openssl x509 -req -days 365 -in dashboard.csr \
  -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial \
  -out dashboard-cert.pem

# Indexer certificate
openssl req -nodes -newkey rsa:2048 \
  -keyout indexer-key.pem -out indexer.csr \
  -subj "/C=US/ST=Dev/L=Local/O=HMA/OU=Compliance/CN=hma-wazuh-indexer"

openssl x509 -req -days 365 -in indexer.csr \
  -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial \
  -out indexer-cert.pem

# Admin certificate for OpenSearch
openssl req -nodes -newkey rsa:2048 \
  -keyout admin-key.pem -out admin.csr \
  -subj "/C=US/ST=Dev/L=Local/O=HMA/OU=Compliance/CN=admin"

openssl x509 -req -days 365 -in admin.csr \
  -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial \
  -out admin-cert.pem

# Cleanup CSR files
rm -f *.csr *.srl

echo "✅ Certificates generated successfully!"
ls -lh
