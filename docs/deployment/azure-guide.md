# Azure Hosting Strategy

> **Reading time:** ~5 minutes · **Audience:** DevOps · **Last Updated:** 2026-04-11

This guide outlines exactly how to host the Flicko backend architecture using Microsoft Azure, explicitly optimized to maximize the standard $100 free credit tier without incurring rapid billing.

---

## Optimal Azure Topology

Instead of using Azure App Service (which charges per microservice per hour), we will use an **Azure Virtual Machine (B-Series)** to manually orchestrate Docker Compose, identically to a DigitalOcean VPS.

Why a Virtual Machine?
- You pay for the underlying hardware once, regardless of how many Docker containers you cram onto it.
- B-Series instances burst CPU credits perfectly aligned with chat-app traffic patterns (high spikes, long lulls).

---

## 1. Creating the Virtual Machine

1. In the Azure Portal, go to **Virtual Machines** -> **Create**.
2. **Resource Group:** Create new (`flicko-rg`)
3. **VM Name:** `flicko-prod-01`
4. **Region:** Choose the region physically closest to your primary user base latency.
5. **Image:** Ubuntu Server 22.04 LTS (x64)
6. **Size:** `Standard_B2s` (2 vCPUs, 4 GiB memory). This costs ~$30/month, meaning your $100 credit will comfortably last over 3 full months of live production traffic.
7. **Authentication:** Select SSH Public Key. Generate a new key pair or paste your existing one.

---

## 2. Network Security Group (NSG) Rules

By default, Azure VMs block all incoming traffic except SSH. You must configure the Azure Firewall.

1. Navigate to your new VM -> **Networking**.
2. Add inbound port rule:
   - **Destination port ranges:** `80`
   - **Protocol:** `TCP`
   - **Name:** `Allow-HTTP`
3. Add inbound port rule:
   - **Destination port ranges:** `443`
   - **Protocol:** `TCP`
   - **Name:** `Allow-HTTPS`

*Do NOT expose ports 8080, 8081, or 8082. NGINX will securely proxy traffic from port 443 down to those Docker containers internally.*

---

## 3. Deployment

Once the VM is running and the Networking Rules are saved:

1. Obtain the **Public IP Address** from the Azure VM Overview page.
2. In your Cloudflare Dashboard, map your DNS `A` records (`api.flicko.app`) to this IP address.
3. SSH into the Azure VM utilizing the `.pem` key you downloaded during creation.
4. Execute the standard `docker-compose` installation and orchestrating outlined in the [Docker Compose Guide](docker-compose.md).

---

## Expanding later (Azure Kubernetes Service)

If your app eventually grows beyond millions of daily users, your $100 Azure Credit will be exhausted. 

At that point, rather than scaling vertically to a bigger VM, you can containerize the 3 Go binaries using `helm` charts and push them into an **Azure Kubernetes Service (AKS)** cluster, which Azure manages for high availability and infinite horizontal pod scaling.
