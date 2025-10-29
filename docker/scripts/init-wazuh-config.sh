#!/bin/bash
# Initialize Wazuh Manager configuration
# Creates default ossec.conf from Wazuh image if not present

set -e

echo "🔧 Initializing Wazuh Manager configuration..."

# Create config directory if it doesn't exist
mkdir -p ./wazuh-config/manager

# If ossec.conf doesn't exist, extract from image
if [ ! -f ./wazuh-config/manager/ossec.conf ]; then
  echo "📋 Extracting default ossec.conf from Wazuh Manager image..."
  
  # Start temporary container to extract config
  docker run --rm -v $(pwd)/wazuh-config/manager:/tmp/manager wazuh/wazuh-manager:4.9.1 sh -c "cp /var/ossec/etc/ossec.conf /tmp/manager/ossec.conf"
  
  echo "✅ Default ossec.conf extracted successfully"
else
  echo "✅ ossec.conf already exists, skipping extraction"
fi

# Ensure custom rules directory exists
mkdir -p ./wazuh-config/rules

# Create default custom rules file if it doesn't exist
if [ ! -f ./wazuh-config/rules/hma_custom_rules.xml ]; then
  cat > ./wazuh-config/rules/hma_custom_rules.xml <<'EOF'
<!-- HMA Custom Security Rules -->
<group name="hma,">
  <!-- Admin Portal Access Monitoring -->
  <rule id="100001" level="3">
    <if_sid>1002</if_sid>
    <match>admin-portal</match>
    <description>Admin portal access detected</description>
    <group>authentication_success,pci_dss_10.2.5,</group>
  </rule>

  <!-- Database Backup Monitoring -->
  <rule id="100002" level="5">
    <if_sid>1002</if_sid>
    <match>backup_failed</match>
    <description>Database backup failed</description>
    <group>service_availability,</group>
  </rule>

  <!-- Credit Adjustment Monitoring -->
  <rule id="100003" level="5">
    <if_sid>1002</if_sid>
    <match>credit_adjustment</match>
    <description>User credit balance adjusted</description>
    <group>gdpr_IV_30.1.g,pci_dss_10.2.5,</group>
  </rule>

  <!-- Payment Processing Monitoring -->
  <rule id="100004" level="7">
    <if_sid>1002</if_sid>
    <match>payment_failed</match>
    <description>Payment processing failure detected</description>
    <group>pci_dss_10.2.6,</group>
  </rule>

  <!-- User Data Access Monitoring (GDPR) -->
  <rule id="100005" level="5">
    <if_sid>1002</if_sid>
    <match>user_data_access</match>
    <description>User personal data accessed</description>
    <group>gdpr_IV_30.1.g,</group>
  </rule>

  <!-- Suspicious Activity Detection -->
  <rule id="100006" level="10">
    <if_sid>1002</if_sid>
    <match>suspicious_activity</match>
    <description>Suspicious user activity detected</description>
    <group>authentication_failures,pci_dss_11.4,</group>
  </rule>
</group>
EOF
  echo "✅ Created default HMA custom rules"
fi

# Ensure decoders directory exists
mkdir -p ./wazuh-config/decoders

# Create default custom decoders file if it doesn't exist
if [ ! -f ./wazuh-config/decoders/hma_decoders.xml ]; then
  cat > ./wazuh-config/decoders/hma_decoders.xml <<'EOF'
<!-- HMA Custom Log Decoders -->
<decoder name="hma-json">
  <program_name>hma-academy</program_name>
  <plugin_decoder>JSON_Decoder</plugin_decoder>
</decoder>

<decoder name="hma-brain-service">
  <parent>hma-json</parent>
  <prematch>\"service\":\"hma-academy-brain\"</prematch>
</decoder>

<decoder name="hma-api-gateway">
  <parent>hma-json</parent>
  <prematch>\"service\":\"hma-academy-api\"</prematch>
</decoder>
EOF
  echo "✅ Created default HMA custom decoders"
fi

echo ""
echo "✅ Wazuh configuration initialization complete!"
echo ""
echo "Configuration files created:"
echo "  - ./wazuh-config/manager/ossec.conf (extracted from image)"
echo "  - ./wazuh-config/rules/hma_custom_rules.xml"
echo "  - ./wazuh-config/decoders/hma_decoders.xml"
echo ""
