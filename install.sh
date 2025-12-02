#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Arista Panel (Browser Login Mode) ===${NC}"

# 1. نصب Node.js و Wrangler (پیش‌نیازهای لاگین مرورگر)
echo -e "${YELLOW}[*] Checking prerequisites...${NC}"

if ! command -v node &> /dev/null; then
    echo "Installing Node.js (Required for browser login)..."
    pkg install nodejs -y
fi

if ! command -v wrangler &> /dev/null; then
    echo -e "${YELLOW}[*] Installing Cloudflare Wrangler (This may take a minute)...${NC}"
    npm install -g wrangler
fi

# 2. دانلود فایل ورکر از گیتهاب
echo -e "${YELLOW}[*] Downloading worker code...${NC}"
GITHUB_URL="https://raw.githubusercontent.com/Ali-Anv1/Test/main/worker.js"
curl -sSL $GITHUB_URL -o worker.js

if [ ! -f "worker.js" ]; then
    echo -e "${RED}[!] Failed to download worker.js${NC}"
    exit 1
fi

# 3. لاگین با مرورگر
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${GREEN}[!] Press Enter to open Cloudflare Login page in your browser...${NC}"
read -p ""
# دستور لاگین که مرورگر رو باز میکنه
npx wrangler login

# 4. دریافت اطلاعات اکانت
echo -e "${YELLOW}[*] Fetching Account Info...${NC}"
ACCOUNT_ID=$(npx wrangler whoami | grep "Account ID" | awk '{print $3}')

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}[!] Login failed or Account ID not found.${NC}"
    exit 1
fi
echo -e "${GREEN}[+] Logged in! Account ID: $ACCOUNT_ID${NC}"

# 5. تنظیمات نام
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

# 6. ساخت KV Namespace با Wrangler
echo -e "${YELLOW}[*] Creating KV Namespace...${NC}"
KV_ID_OUTPUT=$(npx wrangler kv:namespace create "$KV_TITLE" 2>&1)
# استخراج ID از خروجی
KV_ID=$(echo "$KV_ID_OUTPUT" | grep -oE 'id = "[^"]+"' | cut -d'"' -f2)

if [ -z "$KV_ID" ]; then
    # اگر قبلا وجود داشته باشه، سعی میکنیم پیداش کنیم (ساده‌سازی شده)
    echo -e "${YELLOW}[!] KV might already exist, trying to list...${NC}"
    KV_ID=$(npx wrangler kv:namespace list | grep -B 1 "$KV_TITLE" | grep "id" | cut -d'"' -f4)
fi

echo -e "${GREEN}[+] KV ID: $KV_ID${NC}"

# 7. ساخت فایل کانفیگ wrangler.toml
echo -e "${YELLOW}[*] Generating Config...${NC}"
cat << EOF > wrangler.toml
name = "$WORKER_NAME"
main = "worker.js"
compatibility_date = "2023-10-30"

[[kv_namespaces]]
binding = "KV"
id = "$KV_ID"
EOF

# 8. دیپلوی نهایی
echo -e "${BLUE}[*] Deploying to Cloudflare...${NC}"
npx wrangler deploy

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}✅ Installation Completed!${NC}"
echo -e "Your Panel is running on the URL shown above 👆"
echo -e "${BLUE}=========================================${NC}"

# پاکسازی
rm worker.js wrangler.toml
