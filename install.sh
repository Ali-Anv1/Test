#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Arista Panel Installer (Fixed Module Error) ===${NC}"

# 1. نصب پیش‌نیازها
echo -e "${YELLOW}[*] Checking prerequisites...${NC}"
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    pkg install nodejs -y
fi

if ! command -v wrangler &> /dev/null; then
    echo -e "${YELLOW}[*] Installing Cloudflare Wrangler...${NC}"
    npm install -g wrangler
fi

# 2. دانلود فایل ورکر (با پسوند mjs برای حل ارور)
echo -e "${YELLOW}[*] Downloading worker code...${NC}"
GITHUB_URL="https://raw.githubusercontent.com/Ali-Anv1/Test/main/worker.js"

# نکته مهم: فایل را با پسوند mjs ذخیره می‌کنیم تا ارور export رفع شود
curl -sSL $GITHUB_URL -o worker.mjs

if [ ! -f "worker.mjs" ]; then
    echo -e "${RED}[!] Failed to download worker code.${NC}"
    exit 1
fi

# 3. لاگین
echo -e "${YELLOW}----------------------------------------${NC}"
echo -e "${GREEN}1. A link will appear below.${NC}"
echo -e "${GREEN}2. COPY the link and OPEN it in Chrome.${NC}"
echo -e "${GREEN}3. Click 'Allow' and come back here.${NC}"
echo -e "${YELLOW}----------------------------------------${NC}"
echo -e "Press Enter to start login..."
read -p ""

npx wrangler login

# 4. اکانت
echo -e "${YELLOW}[*] Fetching Account Info...${NC}"
ACCOUNT_ID=$(npx wrangler whoami | grep "Account ID" | awk '{print $3}')

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}[!] Login failed.${NC}"
    exit 1
fi
echo -e "${GREEN}[+] Logged in! Account ID: $ACCOUNT_ID${NC}"

# 5. نام‌گذاری
echo -e "${YELLOW}----------------------------------------${NC}"
read -p "Do you want custom names? (y/n): " OPT
if [[ "$OPT" == "y" || "$OPT" == "Y" ]]; then
    read -p "Enter Project Name: " WORKER_NAME
    read -p "Enter KV Name: " KV_TITLE
else
    RAND=$(tr -dc a-z0-9 </dev/urandom | head -c 5)
    WORKER_NAME="bp-panel-$RAND"
    KV_TITLE="bp_kv_$RAND"
    echo -e "Random Name: $WORKER_NAME"
fi

# 6. ساخت KV
echo -e "${YELLOW}[*] Creating KV Namespace...${NC}"
KV_ID_OUTPUT=$(npx wrangler kv:namespace create "$KV_TITLE" 2>&1)
KV_ID=$(echo "$KV_ID_OUTPUT" | grep -oE 'id = "[^"]+"' | cut -d'"' -f2)

if [ -z "$KV_ID" ]; then
    KV_ID=$(npx wrangler kv:namespace list | grep -B 1 "$KV_TITLE" | grep "id" | cut -d'"' -f4)
fi
echo -e "${GREEN}[+] KV ID: $KV_ID${NC}"

# 7. ساخت کانفیگ (تنظیم main روی mjs)
echo -e "${YELLOW}[*] Generating Config...${NC}"
cat << EOF > wrangler.toml
name = "$WORKER_NAME"
main = "worker.mjs"
compatibility_date = "2023-10-30"

[[kv_namespaces]]
binding = "KV"
id = "$KV_ID"
EOF

# 8. دیپلوی
echo -e "${BLUE}[*] Deploying to Cloudflare...${NC}"
npx wrangler deploy

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}✅ Installation Completed!${NC}"
echo -e "🔗 Your Panel URL is shown above 👆"
echo -e "${BLUE}=========================================${NC}"

rm worker.mjs wrangler.toml
