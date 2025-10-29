#!/bin/bash
# Generate self-signed TLS certificates for Wazuh Indexer

set -e

CERTS_DIR="/home/xbyooki/projects/hma-infra/docker/wazuh-certs"
cd "$CERTS_DIR"

echo "Generating Wazuh Indexer certificates..."

# Generate CA private key
openssl genrsa -out ca-key.pem 2048

# Generate CA certificate
openssl req -new -x509 -sha256 -key ca-key.pem -out ca.pem -days 3650 \
    -subj "/C=US/ST=State/L=City/O=HuntMasterAcademy/OU=Compliance/CN=Wazuh CA"

# Generate Indexer private key
openssl genrsa -out indexer-key.pem 2048

# Generate Indexer certificate signing request
openssl req -new -key indexer-key.pem -out indexer.csr \
    -subj "/C=US/ST=State/L=City/O=HuntMasterAcademy/OU=Compliance/CN=hma-wazuh-indexer"

# Generate Indexer certificate
openssl x509 -req -in indexer.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial \
    -out indexer.pem -days 3650 -sha256 \
    -extfile <(printf "subjectAltName=DNS:hma-wazuh-indexer,DNS:localhost,IP:127.0.0.1")

# Generate Admin private key
openssl genrsa -out admin-key.pem 2048

# Generate Admin certificate signing request
openssl req -new -key admin-key.pem -out admin.csr \
    -subj "/C=US/ST=State/L=City/O=HuntMasterAcademy/OU=Compliance/CN=admin"

# Generate Admin certificate
openssl x509 -req -in admin.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial \
    -out admin.pem -days 3650 -sha256

# Set permissions
chmod 644 *.pem
chmod 600 *-key.pem

echo "Certificates generated successfully in $CERTS_DIR"
ls -lh "$CERTS_DIR"
