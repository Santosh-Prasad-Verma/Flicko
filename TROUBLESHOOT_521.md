# Troubleshooting Cloudflare 521 Error

## Quick Diagnosis Commands

Run these commands on your Azure VPS to diagnose the issue:

```bash
# 1. Check if Docker containers are running
docker ps

# 2. Check NGINX container specifically
docker ps | grep nginx

# 3. Check NGINX logs
docker logs flicko-nginx-1

# 4. Check if NGINX is listening on port 443
sudo netstat -tlnp | grep :443

# 5. Check firewall rules
sudo ufw status

# 6. Test NGINX locally
curl -k https://localhost

# 7. Check all container health
docker compose -f docker-compose.prod.yml ps
```

## Common Causes & Fixes

### 1. Docker Containers Not Running
**Check:**
```bash
docker compose -f docker-compose.prod.yml ps
```

**Fix:**
```bash
cd /home/tarun/Videos/Flicko
docker compose -f docker-compose.prod.yml up -d
```

### 2. NGINX Not Listening on Port 443
**Check:**
```bash
sudo netstat -tlnp | grep :443
# Should show: tcp 0.0.0.0:443 LISTEN <pid>/nginx
```

**Fix:**
```bash
# Restart NGINX container
docker compose -f docker-compose.prod.yml restart nginx

# Or rebuild if config changed
docker compose -f docker-compose.prod.yml up -d --force-recreate nginx
```

### 3. Firewall Blocking Port 443
**Check:**
```bash
sudo ufw status
# Should show: 443/tcp ALLOW Anywhere
```

**Fix:**
```bash
sudo ufw allow 443/tcp
sudo ufw reload
```

### 4. SSL Certificate Issues
**Check:**
```bash
# Verify certificates exist
ls -la /home/tarun/Videos/Flicko/secrets/origin*.pem

# Check certificate validity
openssl x509 -in secrets/origin.pem -text -noout | grep "Not After"
```

**Fix:**
```bash
# If certificates missing, download from Cloudflare:
# 1. Go to SSL/TLS > Origin Server in Cloudflare Dashboard
# 2. Create new certificate
# 3. Save as secrets/origin.pem and secrets/origin-key.pem
# 4. Restart NGINX
docker compose -f docker-compose.prod.yml restart nginx
```

### 5. Azure Network Security Group (NSG)
**Check in Azure Portal:**
- Navigate to your VM > Networking > Inbound port rules
- Verify port 443 is allowed from Cloudflare IPs

**Fix:**
Add inbound rule for port 443 from source "Internet" or Cloudflare IP ranges

### 6. NGINX Configuration Error
**Check:**
```bash
# Test NGINX config
docker exec flicko-nginx-1 nginx -t
```

**Fix:**
```bash
# View error logs
docker logs flicko-nginx-1 --tail 100

# If config error, fix and reload
docker compose -f docker-compose.prod.yml restart nginx
```

## Step-by-Step Diagnosis

Run these commands in order and share the output:

```bash
# Step 1: Container status
echo "=== Docker Containers ==="
docker ps -a

# Step 2: NGINX logs
echo "=== NGINX Logs (last 50 lines) ==="
docker logs flicko-nginx-1 --tail 50

# Step 3: Port listening
echo "=== Listening Ports ==="
sudo netstat -tlnp | grep -E ':(80|443)'

# Step 4: Firewall
echo "=== Firewall Status ==="
sudo ufw status numbered

# Step 5: Test local connection
echo "=== Local HTTPS Test ==="
curl -k -I https://localhost

# Step 6: Certificate check
echo "=== SSL Certificates ==="
ls -lh secrets/origin*.pem
```

## Quick Fix Script

```bash
#!/bin/bash
# Run this to attempt automatic fix

cd /home/tarun/Videos/Flicko

echo "Stopping containers..."
docker compose -f docker-compose.prod.yml down

echo "Checking firewall..."
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp

echo "Starting containers..."
docker compose -f docker-compose.prod.yml up -d

echo "Waiting 10 seconds..."
sleep 10

echo "Container status:"
docker ps

echo "NGINX logs:"
docker logs flicko-nginx-1 --tail 20

echo "Testing local connection:"
curl -k -I https://localhost
```

## Cloudflare Settings to Verify

1. **SSL/TLS Mode**: Should be "Full (strict)" or "Full"
   - Go to SSL/TLS > Overview
   - Set to "Full (strict)" if you have valid Origin Certificate

2. **Origin Server Certificate**: Must be installed on your server
   - Go to SSL/TLS > Origin Server
   - Verify certificate is valid and not expired

3. **DNS Settings**: Verify A record points to correct Azure IP
   - Go to DNS > Records
   - Check flicko.focko.tech A record points to your Azure VM public IP

4. **Cloudflare Proxy**: Orange cloud should be enabled
   - Go to DNS > Records
   - Ensure proxy status is "Proxied" (orange cloud)

## Expected Output (Healthy System)

```bash
# docker ps should show:
flicko-nginx-1           Up 2 hours (healthy)
flicko-ws-gateway-1      Up 2 hours (healthy)
flicko-msg-service-1     Up 2 hours (healthy)
flicko-backend-1         Up 2 hours (healthy)

# netstat should show:
tcp 0.0.0.0:443 LISTEN 12345/nginx
tcp 0.0.0.0:80  LISTEN 12345/nginx

# curl should return:
HTTP/2 200
server: nginx/1.25.3
```
