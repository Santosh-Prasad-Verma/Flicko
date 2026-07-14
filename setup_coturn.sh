#!/bin/bash
# ==============================================================================
# Automated Coturn (STUN/TURN) Server Installation & Configuration Script
# Target: Ubuntu 24.04 (Azure VPS)
# ==============================================================================

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root (use sudo)"
  exit 1
fi

echo "🔄 Updating package lists..."
apt-get update -y

echo "📦 Installing Coturn server..."
apt-get install coturn -y

echo "⚙️ Configuring TURN Server (/etc/turnserver.conf)..."
# Backup the default configuration
mv /etc/turnserver.conf /etc/turnserver.conf.backup

# Generate the new secure configuration
cat <<EOF > /etc/turnserver.conf
# Listening port for STUN/TURN (default is 3478)
listening-port=3478

# Use TLS (optional, but 3478 standard is non-TLS)
# tls-listening-port=5349

# External Public IP of your Azure VPS
external-ip=104.43.114.32

# Local IP to bind to (allows listening on all interfaces)
listening-ip=0.0.0.0

# Server Realm
realm=flicko.southeastasia.cloudapp.azure.com

# Enable long-term credential mechanism
lt-cred-mech

# Fingerprint option
fingerprint

# Add the static user credentials for Flicko calls
user=flicko:flickoSecretSecurePassword2026!

# Log file configuration
log-file=/var/log/turnserver.log
simple-log

# Dynamic port range for relaying media (open these in Azure NSG)
min-port=49152
max-port=65535

# Do not allow loopback addresses for security
no-loopback-peers
no-multicast-peers
EOF

echo "🚀 Enabling turnserver daemon..."
# Configure coturn daemon to start on boot
sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/g' /etc/default/coturn || true
if ! grep -q "TURNSERVER_ENABLED=1" /etc/default/coturn; then
  echo "TURNSERVER_ENABLED=1" >> /etc/default/coturn
fi

echo "🛡️ Configuring local UFW firewall (if active)..."
if which ufw > /dev/null; then
  # Allow STUN/TURN traffic
  ufw allow 3478/tcp
  ufw allow 3478/udp
  # Allow dynamic WebRTC media range
  ufw allow 49152:65535/udp
  echo "✅ Local firewall rules added."
else
  echo "⚠️ UFW firewall not installed. Skipping local firewall rules."
fi

echo "🔄 Starting and enabling turnserver service..."
systemctl daemon-reload
systemctl enable coturn
systemctl restart coturn

echo "=============================================================================="
echo "🎉 Coturn Installation & Configuration Complete!"
echo "=============================================================================="
echo "⚠️  IMPORTANT: You must open the following Inbound Port Rules in your"
echo "   Azure Network Security Group (NSG) web panel for 'Flicko-Server':"
echo "   1. Port 3478 -> TCP and UDP (For STUN/TURN Signaling)"
echo "   2. Ports 49152-65535 -> UDP (For WebRTC Media Relay)"
echo "=============================================================================="
echo "STUN/TURN Server is active at: turn:104.43.114.32:3478"
echo "User: flicko"
echo "=============================================================================="
