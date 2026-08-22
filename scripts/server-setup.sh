#!/usr/bin/env bash
# =============================================================================
# Flicko — Initial Server Hardening Script (Ubuntu 22.04 LTS)
# =============================================================================
#
# This script hardens a fresh Ubuntu 22.04 VPS for running Flicko in
# production behind Cloudflare. It must be run as root on first boot.
#
# What it does (in order):
#   1. System update & upgrade
#   2. Create non-root deploy user with sudo
#   3. SSH hardening: key-only auth, custom port, no root login
#   4. UFW firewall: default deny, allow SSH/HTTP/HTTPS from trusted IPs
#   5. fail2ban: SSH, NGINX rate-limit, and custom flicko-auth jails
#   6. Automatic security updates via unattended-upgrades
#   7. Kernel sysctl tuning for high-concurrency network workloads
#   8. File descriptor ulimits for 65k concurrent connections
#   9. Docker CE + Docker Compose v2 installation
#  10. Deploy user added to docker group
#
# Usage:
#   sudo bash scripts/server-setup.sh
#
# Prerequisites:
#   - Fresh Ubuntu 22.04 LTS server
#   - Root or sudo access
#   - Internet connectivity
#   - Your SSH public key ready to paste (or set DEPLOY_SSH_KEY env var)
#
# Security philosophy:
#   - Principle of least privilege (no root SSH, deploy user needs sudo)
#   - Defense in depth (UFW + fail2ban + Cloudflare + SSH hardening)
#   - Fail closed (default deny all inbound traffic)
#   - Automated patching (unattended-upgrades for security fixes)
#
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration — edit these before running
# ─────────────────────────────────────────────────────────────────────────────

# Deploy user name. This is the only user that will have SSH access.
DEPLOY_USER="${DEPLOY_USER:-deploy}"

# SSH port — moved from default 22 to reduce automated scanning noise.
# Port 2222 is well-known enough that tools won't choke, but obscure
# enough to drop 99% of automated SSH brute-force attempts.
SSH_PORT="${SSH_PORT:-2222}"

# IP address allowed to SSH in. Set to your static IP or bastion host.
# Use "any" to allow SSH from all IPs (not recommended for production).
ALLOWED_SSH_IP="${ALLOWED_SSH_IP:-any}"

# SSH public key for the deploy user. If not set, the script will prompt.
DEPLOY_SSH_KEY="${DEPLOY_SSH_KEY:-}"

# Timezone for the server.
TIMEZONE="${TIMEZONE:-UTC}"

# ─────────────────────────────────────────────────────────────────────────────
# Preflight checks
# ─────────────────────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (or with sudo)."
    exit 1
fi

if ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
    echo "WARNING: This script is designed for Ubuntu 22.04 LTS."
    echo "         Detected: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | head -1)"
    read -rp "Continue anyway? [y/N] " yn
    [[ "$yn" == [yY] ]] || exit 1
fi

echo "============================================================"
echo " Flicko Server Hardening — $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================================"
echo ""
echo " Deploy user:    ${DEPLOY_USER}"
echo " SSH port:       ${SSH_PORT}"
echo " Allowed SSH IP: ${ALLOWED_SSH_IP}"
echo " Timezone:       ${TIMEZONE}"
echo ""
read -rp "Proceed with these settings? [y/N] " confirm
[[ "$confirm" == [yY] ]] || exit 0

# ─────────────────────────────────────────────────────────────────────────────
# 1. System update & upgrade
# ─────────────────────────────────────────────────────────────────────────────
# Rationale: Ensure all packages have the latest security patches before
# we start configuring services. DEBIAN_FRONTEND=noninteractive prevents
# interactive prompts from blocking automation.

echo ""
echo ">>> [1/10] Updating system packages..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get dist-upgrade -y -qq
apt-get autoremove -y -qq
apt-get autoclean -qq

# Set timezone.
timedatectl set-timezone "${TIMEZONE}"

echo "    ✓ System updated and timezone set to ${TIMEZONE}"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Create non-root deploy user
# ─────────────────────────────────────────────────────────────────────────────
# Rationale: Running services as root is dangerous — any exploit gives
# full system access. A dedicated deploy user with sudo only when needed
# limits the blast radius of a compromise.

echo ""
echo ">>> [2/10] Creating deploy user '${DEPLOY_USER}'..."

if id "${DEPLOY_USER}" &>/dev/null; then
    echo "    User '${DEPLOY_USER}' already exists, skipping creation."
else
    # --disabled-password: no password login (SSH key only)
    # --gecos "": skip interactive full name prompt
    adduser --disabled-password --gecos "" "${DEPLOY_USER}"
    usermod -aG sudo "${DEPLOY_USER}"
    echo "    ✓ User '${DEPLOY_USER}' created and added to sudo group."
fi

# Set up SSH authorized keys for the deploy user.
DEPLOY_HOME="/home/${DEPLOY_USER}"
SSH_DIR="${DEPLOY_HOME}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

if [[ -n "${DEPLOY_SSH_KEY}" ]]; then
    echo "${DEPLOY_SSH_KEY}" > "${AUTH_KEYS}"
elif [[ -f /root/.ssh/authorized_keys ]]; then
    # Copy root's authorized keys as a sensible default.
    cp /root/.ssh/authorized_keys "${AUTH_KEYS}"
    echo "    Copied root SSH keys to ${DEPLOY_USER}."
else
    echo "    No SSH key provided. Paste your public key now (or Ctrl+C to abort):"
    read -r key
    echo "${key}" > "${AUTH_KEYS}"
fi

chmod 600 "${AUTH_KEYS}"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${SSH_DIR}"
echo "    ✓ SSH key configured for '${DEPLOY_USER}'."

# Allow deploy user to run sudo without password for deployments.
# Rationale: Automated deploy scripts need non-interactive sudo.
# This is acceptable because SSH key auth is the access gate.
echo "${DEPLOY_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${DEPLOY_USER}"
chmod 440 "/etc/sudoers.d/${DEPLOY_USER}"

echo "    ✓ Passwordless sudo configured."

# ─────────────────────────────────────────────────────────────────────────────
# 3. SSH hardening
# ─────────────────────────────────────────────────────────────────────────────
# Rationale:
#   - Key-only auth:     Eliminates password brute-force attacks entirely.
#   - Disable root login: Forces use of the deploy user (audit trail).
#   - Custom port:       Drops 99% of automated scanning bots.
#   - MaxAuthTries 3:    Limits brute-force window per connection.
#   - LoginGraceTime 30: Closes hanging connections quickly.
#   - ClientAliveInterval/CountMax: Detects dead connections.
#   - AllowUsers:        Whitelist — only the deploy user can SSH in.

echo ""
echo ">>> [3/10] Hardening SSH..."

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.bak.$(date +%s)"

# Back up original config.
cp "${SSHD_CONFIG}" "${SSHD_BACKUP}"
echo "    Backed up sshd_config to ${SSHD_BACKUP}"

cat > "${SSHD_CONFIG}" << SSHEOF
# =============================================================================
# Flicko — Hardened SSH Configuration
# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
# =============================================================================

# ── Connection ───────────────────────────────────────────────
Port ${SSH_PORT}
AddressFamily inet
ListenAddress 0.0.0.0

# ── Authentication ───────────────────────────────────────────
# Key-only: passwords and keyboard-interactive disabled.
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes

# Only allow the deploy user to log in.
AllowUsers ${DEPLOY_USER}

# Limit brute-force window: 3 attempts, 30s grace period.
MaxAuthTries 3
LoginGraceTime 30
MaxSessions 5

# ── Forwarding ───────────────────────────────────────────────
# Disable all forwarding unless explicitly needed.
AllowTcpForwarding no
AllowAgentForwarding no
X11Forwarding no
PermitTunnel no

# ── Keepalive ────────────────────────────────────────────────
# Drop dead connections after 3 × 60s = 180s of silence.
ClientAliveInterval 60
ClientAliveCountMax 3

# ── Logging ──────────────────────────────────────────────────
# VERBOSE gives us richer auth logs for fail2ban.
LogLevel VERBOSE
SyslogFacility AUTH

# ── Security ─────────────────────────────────────────────────
# Restrict host key algorithms to modern, strong ones.
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# ── Misc ─────────────────────────────────────────────────────
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# ── Banner ───────────────────────────────────────────────────
Banner /etc/ssh/banner
SSHEOF

# Create a login banner (legal notice / deterrent).
cat > /etc/ssh/banner << 'BANNEREOF'

  ╔═══════════════════════════════════════════════════════════╗
  ║  AUTHORIZED ACCESS ONLY                                  ║
  ║  All connections are monitored and logged.                ║
  ║  Unauthorized access will be prosecuted.                  ║
  ╚═══════════════════════════════════════════════════════════╝

BANNEREOF

# Validate config before restarting (avoids lockout on syntax error).
if sshd -t -f "${SSHD_CONFIG}"; then
    systemctl restart sshd
    echo "    ✓ SSH hardened: port ${SSH_PORT}, key-only, root disabled."
else
    echo "    ERROR: sshd_config validation failed. Restoring backup."
    cp "${SSHD_BACKUP}" "${SSHD_CONFIG}"
    systemctl restart sshd
    exit 1
fi

echo ""
echo "    ╔══════════════════════════════════════════════════════╗"
echo "    ║  WARNING: SSH is now on port ${SSH_PORT}.                  ║"
echo "    ║  Test connectivity in a NEW terminal before logging  ║"
echo "    ║  out of this session:                                ║"
echo "    ║                                                      ║"
echo "    ║    ssh -p ${SSH_PORT} ${DEPLOY_USER}@<server-ip>            ║"
echo "    ╚══════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 4. UFW firewall
# ─────────────────────────────────────────────────────────────────────────────
# Rationale:
#   - Default deny incoming: only explicitly allowed traffic gets in.
#   - SSH from specific IP: limits attack surface to your IP only.
#   - HTTP/HTTPS from Cloudflare only: server is invisible without CF.
#     Direct IP access is blocked, preventing IP-based DDoS bypass.
#   - Allow all outgoing: server needs to reach package repos, APIs, etc.

echo ">>> [4/10] Configuring UFW firewall..."

apt-get install -y -qq ufw

# Reset to clean state.
ufw --force reset

# Default policies: deny everything inbound, allow outbound.
ufw default deny incoming
ufw default allow outgoing

# Allow SSH from specific IP (or anywhere if ALLOWED_SSH_IP=any).
if [[ "${ALLOWED_SSH_IP}" == "any" ]]; then
    ufw allow "${SSH_PORT}/tcp" comment "SSH"
else
    ufw allow from "${ALLOWED_SSH_IP}" to any port "${SSH_PORT}" proto tcp comment "SSH from admin"
fi

# Allow HTTP/HTTPS from Cloudflare IP ranges only.
# This ensures the server is only reachable through Cloudflare's proxy,
# hiding the origin IP from attackers and leveraging CF's DDoS protection.
#
# Cloudflare IPv4 ranges (as of 2024 — updated weekly by cron script).
CLOUDFLARE_IPV4=(
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
)

# Cloudflare IPv6 ranges.
CLOUDFLARE_IPV6=(
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
)

for ip in "${CLOUDFLARE_IPV4[@]}"; do
    ufw allow from "${ip}" to any port 80 proto tcp comment "Cloudflare HTTP"
    ufw allow from "${ip}" to any port 443 proto tcp comment "Cloudflare HTTPS"
done

for ip in "${CLOUDFLARE_IPV6[@]}"; do
    ufw allow from "${ip}" to any port 80 proto tcp comment "Cloudflare HTTP v6"
    ufw allow from "${ip}" to any port 443 proto tcp comment "Cloudflare HTTPS v6"
done

# Enable UFW (--force skips the confirmation prompt).
ufw --force enable
ufw status verbose

echo "    ✓ UFW configured: SSH(${SSH_PORT}), HTTP/HTTPS from Cloudflare only."

# ─────────────────────────────────────────────────────────────────────────────
# 5. fail2ban
# ─────────────────────────────────────────────────────────────────────────────
# Rationale:
#   - SSH jail: bans IPs after 3 failed attempts for 1 hour. Even with
#     key-only auth, this catches bots scanning for password prompts.
#   - NGINX rate-limit jail: bans clients hitting 429 rate limits
#     repeatedly (10 hits = ban for 10min). Deters API abuse.
#   - flicko-auth jail: bans IPs generating excessive 401 responses
#     on auth endpoints (brute-force token/credential guessing).

echo ""
echo ">>> [5/10] Installing and configuring fail2ban..."

apt-get install -y -qq fail2ban

# Create the custom Flicko auth filter.
mkdir -p /etc/fail2ban/filter.d

cat > /etc/fail2ban/filter.d/flicko-auth.conf << 'F2BFILTER'
# =============================================================================
# Flicko — fail2ban filter for failed API authentication attempts
# =============================================================================
#
# Matches NGINX access log lines where:
#   - The request targets /api/auth/ endpoints
#   - The response status is 401 (Unauthorized)
#
# This catches brute-force login attempts, invalid JWT tokens, and
# credential stuffing attacks against the auth API.
#
# Log format expected (NGINX combined):
#   172.16.0.1 - - [28/Feb/2026:12:00:00 +0000] "POST /api/auth/login HTTP/1.1" 401 ...
#
[Definition]

# Match 401 responses to any /api/auth/ endpoint.
# The <HOST> placeholder is replaced by fail2ban with the client IP regex.
failregex = ^<HOST> .+ "(GET|POST|PUT|PATCH|DELETE) /api/auth/\S* HTTP/\S+" 401

# Ignore successful requests and health checks.
ignoreregex = ^<HOST> .+ "(GET|POST) /healthz
F2BFILTER

# Create the NGINX rate-limit filter (matches 429 responses).
cat > /etc/fail2ban/filter.d/nginx-limit-req.conf << 'NLRFILTER'
# =============================================================================
# NGINX rate-limit exceeded filter
# =============================================================================
#
# Matches NGINX error log entries for rate-limiting.
# When NGINX returns 429 Too Many Requests, it logs to the error log.
#
[Definition]

failregex = limiting requests, excess: .* by zone .*, client: <HOST>

ignoreregex =
NLRFILTER

# Main fail2ban jail configuration.
cat > /etc/fail2ban/jail.local << F2BJAIL
# =============================================================================
# Flicko — fail2ban jail configuration
# =============================================================================

[DEFAULT]
# Ban duration defaults. Individual jails override as needed.
bantime  = 3600
findtime = 600
maxretry = 5

# Use the UFW action so bans are applied as firewall rules.
# This is more reliable than iptables when UFW is managing the firewall.
banaction = ufw

# Ignore localhost and private Docker networks.
ignoreip = 127.0.0.1/8 ::1 172.16.0.0/12 10.0.0.0/8

# Send ban notifications to syslog.
action = %(action_)s

# ── SSH jail ─────────────────────────────────────────────────
[sshd]
enabled  = true
port     = ${SSH_PORT}
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 3600
findtime = 600

# Why 3 retries / 1h ban:
#   With key-only auth, any failed attempt is suspicious — either a bot
#   or someone with the wrong key. 3 tries in 10 minutes = 1 hour ban.

# ── NGINX rate-limit jail ────────────────────────────────────
[nginx-limit-req]
enabled  = true
port     = http,https
filter   = nginx-limit-req
logpath  = /var/log/nginx/error.log
maxretry = 10
bantime  = 600
findtime = 120

# Why 10 retries / 10min ban:
#   Legitimate clients rarely hit rate limits. 10 hits in 2 minutes
#   indicates automated abuse (scraping, credential stuffing).

# ── Flicko auth failure jail ─────────────────────────────────
[flicko-auth]
enabled  = true
port     = http,https
filter   = flicko-auth
logpath  = /var/log/nginx/access.log
maxretry = 10
bantime  = 1800
findtime = 300

# Why 10 retries / 30min ban:
#   Failed auth attempts on /api/auth/* indicate brute-force login
#   or token guessing. 10 failures in 5 minutes = 30 minute ban.
#   This is aggressive but appropriate for auth endpoints.
F2BJAIL

systemctl enable fail2ban
systemctl restart fail2ban

echo "    ✓ fail2ban: sshd (3/1h), nginx-limit-req (10/10m), flicko-auth (10/30m)."

# ─────────────────────────────────────────────────────────────────────────────
# 6. Automatic security updates
# ─────────────────────────────────────────────────────────────────────────────
# Rationale:
#   - Security patches should be applied automatically. The delay between
#     CVE disclosure and exploitation is often < 24 hours.
#   - Only security updates are auto-installed (not feature updates).
#   - Automatic reboot at 4 AM if kernel updates require it.
#   - Email notifications for installed updates (if mail is configured).

echo ""
echo ">>> [6/10] Configuring automatic security updates..."

apt-get install -y -qq unattended-upgrades apt-listchanges

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UUEOF'
// =============================================================================
// Flicko — Unattended Upgrades Configuration
// =============================================================================

Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

// Remove unused kernel packages after upgrade.
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Remove unused auto-installed dependencies.
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically reboot if required (e.g. kernel updates).
// Schedule: 4 AM UTC to minimise user impact.
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";

// Log to syslog for monitoring.
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";

// Don't install updates that require config file changes.
// This prevents interactive prompts in unattended mode.
Dpkg::Options {
    "--force-confdef";
    "--force-confold";
};
UUEOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AUTOEOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
AUTOEOF

systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

echo "    ✓ Automatic security updates enabled (reboot at 04:00 UTC if needed)."

# ─────────────────────────────────────────────────────────────────────────────
# 7. Kernel sysctl tuning
# ─────────────────────────────────────────────────────────────────────────────
# Rationale:
#   These settings tune the kernel for high-concurrency network workloads
#   (thousands of WebSocket connections + REST API requests).
#
#   somaxconn:           Max pending connections in the listen queue.
#                        Default 4096 is too low for burst traffic.
#   tcp_max_syn_backlog: SYN flood protection — holds more half-open
#                        connections before dropping. Prevents legitimate
#                        clients from being rejected during traffic spikes.
#   netdev_max_backlog:  Max packets queued on the NIC before the kernel
#                        starts dropping. Critical for bursty traffic.
#   ip_local_port_range: Widens ephemeral port range for outbound connections.
#                        Default 32768-60999 limits to ~28k simultaneous
#                        outbound connections. 1024-65535 gives ~64k.
#   file-max:            System-wide file descriptor limit. Each WebSocket
#                        connection uses one fd. 2M supports massive scale.
#   tcp_tw_reuse:        Allows reuse of TIME_WAIT sockets for new outbound
#                        connections to the same destination. Prevents
#                        ephemeral port exhaustion under heavy load.
#   tcp_fin_timeout:     Reduces TIME_WAIT duration from 60s to 15s.
#                        Frees sockets faster after connection close.
#   tcp_keepalive_*:     Detects dead TCP connections faster (30s idle,
#                        probe every 10s, drop after 3 failures = 60s).

echo ""
echo ">>> [7/10] Tuning kernel sysctl parameters..."

cat > /etc/sysctl.d/99-flicko.conf << 'SYSCTLEOF'
# =============================================================================
# Flicko — Kernel Network Tuning
# =============================================================================

# ── Connection backlog ───────────────────────────────────────
# Max pending connections in the listen() backlog.
net.core.somaxconn = 65535

# Max SYN packets queued (SYN flood protection).
net.ipv4.tcp_max_syn_backlog = 65535

# Max packets queued at the NIC level before kernel processing.
net.core.netdev_max_backlog = 65535

# ── Port range ───────────────────────────────────────────────
# Widen ephemeral port range for outbound connections.
net.ipv4.ip_local_port_range = 1024 65535

# ── File descriptors ─────────────────────────────────────────
# System-wide fd limit: 2M to support massive concurrent connections.
fs.file-max = 2097152

# ── TCP optimisation ─────────────────────────────────────────
# Reuse TIME_WAIT sockets for new outbound connections.
net.ipv4.tcp_tw_reuse = 1

# Reduce TIME_WAIT duration from 60s to 15s.
net.ipv4.tcp_fin_timeout = 15

# Faster dead-connection detection (30s idle, 10s probe, 3 probes).
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3

# ── Memory buffers ───────────────────────────────────────────
# TCP read/write buffer sizes: min 4KB, default 128KB, max 16MB.
net.ipv4.tcp_rmem = 4096 131072 16777216
net.ipv4.tcp_wmem = 4096 131072 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# ── Security hardening ───────────────────────────────────────
# Ignore ICMP broadcast pings (Smurf attack prevention).
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Drop packets with invalid source addresses (spoofing prevention).
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable IP source routing (prevents routing manipulation attacks).
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Don't send ICMP redirects (not a router).
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Log suspicious packets (spoofed, source routed, redirects).
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Disable IPv6 if not needed (reduces attack surface).
# Uncomment if you don't use IPv6:
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
SYSCTLEOF

sysctl --system --quiet

echo "    ✓ Kernel tuned: somaxconn=65535, file-max=2097152, tcp_tw_reuse=1."

# ─────────────────────────────────────────────────────────────────────────────
# 8. File descriptor ulimits
# ─────────────────────────────────────────────────────────────────────────────
# Rationale:
#   Per-process file descriptor limits must match the system-wide fs.file-max.
#   Each TCP connection (WebSocket or REST) consumes one fd. With thousands
#   of concurrent users, the default 1024 limit causes "too many open files"
#   errors. 65536 supports 64k simultaneous connections per process.

echo ""
echo ">>> [8/10] Setting file descriptor ulimits..."

cat > /etc/security/limits.d/99-flicko.conf << 'LIMITSEOF'
# =============================================================================
# Flicko — File Descriptor Limits
# =============================================================================
# Each WebSocket connection and TCP socket uses one file descriptor.
# Default of 1024 is far too low for production.

# Deploy user — matches Docker container ulimits.
*               soft    nofile          65536
*               hard    nofile          65536

# Root — needs high limits for Docker daemon.
root            soft    nofile          65536
root            hard    nofile          65536
LIMITSEOF

# Also set for systemd services (Docker, etc.).
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/99-flicko-limits.conf << 'SDLIMITS'
[Manager]
DefaultLimitNOFILE=65536
SDLIMITS

# Ensure PAM enforces limits for SSH sessions.
if ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

echo "    ✓ ulimits: nofile=65536 (soft+hard) for all users."

# ─────────────────────────────────────────────────────────────────────────────
# 9. Docker CE installation
# ─────────────────────────────────────────────────────────────────────────────
# Rationale:
#   Install Docker from the official Docker repository (not Ubuntu's snap
#   or apt packages, which are often outdated). Docker CE provides the
#   latest security patches and features.

echo ""
echo ">>> [9/10] Installing Docker CE..."

if command -v docker &>/dev/null; then
    echo "    Docker already installed: $(docker --version)"
else
    # Install prerequisites.
    apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key.
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the Docker apt repository.
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io

    echo "    ✓ Docker CE installed: $(docker --version)"
fi

# Configure Docker daemon with production defaults.
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKEREOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    },
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 65536,
            "Soft": 65536
        }
    },
    "storage-driver": "overlay2",
    "live-restore": true,
    "userland-proxy": false,
    "iptables": true,
    "ip-forward": true
}
DOCKEREOF

# Rationale for daemon.json settings:
#   log-driver json-file: default, with size limits to prevent disk fill.
#   default-ulimits:      match system limits for all containers.
#   overlay2:             best performance storage driver for Ubuntu.
#   live-restore:         containers keep running during Docker daemon restarts.
#   userland-proxy false: use iptables for port forwarding (better performance).

systemctl enable docker
systemctl restart docker

echo "    ✓ Docker daemon configured with production defaults."

# ─────────────────────────────────────────────────────────────────────────────
# 10. Docker Compose v2 + deploy user setup
# ─────────────────────────────────────────────────────────────────────────────
# Rationale:
#   Docker Compose v2 is a Docker CLI plugin (not a standalone binary).
#   Adding the deploy user to the docker group allows running containers
#   without sudo (the docker socket is group-readable).
#
#   Security note: docker group membership is effectively root-equivalent.
#   This is acceptable because the deploy user already has NOPASSWD sudo,
#   and all access is gated by SSH key authentication.

echo ""
echo ">>> [10/10] Installing Docker Compose v2 and configuring deploy user..."

if docker compose version &>/dev/null; then
    echo "    Docker Compose already installed: $(docker compose version)"
else
    apt-get install -y -qq docker-compose-plugin
    echo "    ✓ Docker Compose v2 installed: $(docker compose version)"
fi

# Add deploy user to docker group.
usermod -aG docker "${DEPLOY_USER}"
echo "    ✓ '${DEPLOY_USER}' added to docker group."

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "============================================================"
echo " Server hardening complete!"
echo "============================================================"
echo ""
echo " Summary:"
echo "   • System updated, timezone ${TIMEZONE}"
echo "   • Deploy user: ${DEPLOY_USER} (sudo, docker)"
echo "   • SSH: port ${SSH_PORT}, key-only, root disabled"
echo "   • UFW: default deny, SSH/HTTP/HTTPS from trusted IPs"
echo "   • fail2ban: sshd, nginx-limit-req, flicko-auth"
echo "   • Auto security updates: enabled (reboot 04:00 UTC)"
echo "   • Sysctl: high-concurrency network tuning"
echo "   • ulimits: nofile=65536"
echo "   • Docker CE + Compose v2 installed"
echo ""
echo " Next steps:"
echo "   1. TEST SSH in a new terminal before disconnecting:"
echo "      ssh -p ${SSH_PORT} ${DEPLOY_USER}@<server-ip>"
echo ""
echo "   2. Install the update-cloudflare-ips.sh cron job:"
echo "      sudo cp scripts/update-cloudflare-ips.sh /usr/local/bin/"
echo "      sudo chmod +x /usr/local/bin/update-cloudflare-ips.sh"
echo "      echo '0 3 * * 0 root /usr/local/bin/update-cloudflare-ips.sh' | sudo tee /etc/cron.d/cloudflare-ips"
echo ""
echo "   3. Install logrotate config:"
echo "      sudo cp scripts/logrotate-flicko.conf /etc/logrotate.d/flicko"
echo ""
echo "   4. Deploy Flicko:"
echo "      cd /opt/flicko && scripts/deploy.sh"
echo ""
echo " Log: this script's output is not saved. Run with:"
echo "   sudo bash scripts/server-setup.sh 2>&1 | tee /var/log/server-setup.log"
echo ""
