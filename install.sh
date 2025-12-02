#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Cloudflare Panel Installer (Local File) ===${NC}"

# چک کردن اینکه آیا فایل ورکر کنار اسکریپت هست یا نه
if [ ! -f "worker.js" ]; then
    echo -e "${RED}[!] Error: File 'worker.js' not found!${NC}"
    echo "Please copy your worker code into a file named 'worker.js' in this folder."
    exit 1
fi

# 1. نصب پیش‌نیازها
pkg install jq curl -y > /dev/null 2>&1

# 2. دریافت اطلاعات
echo -e "${GREEN}[*] Setup Cloudflare Account${NC}"
read -p "Enter Cloudflare API Token: " CF_TOKEN

# تست توکن
USER_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result.id')

if [ "$USER_ID" == "null" ]; then
    echo -e "${RED}[!] Token is invalid.${NC}"
    exit 1
fi

ACCOUNT_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

# 3. دریافت نام پروژه و KV
read -p "Do you want custom names? (y/n): " CUSTOM_OPT
if [[ "$CUSTOM_OPT" == "y" ]]; then
    read -p "Enter KV Name: " KV_TITLE
    read -p "Enter Project Name: " WORKER_NAME
else
    RAND=$(tr -dc a-z0-9 </dev/urandom | head -c 4)
    KV_TITLE="bp_kv_$RAND"
    WORKER_NAME="bp-panel-$RAND"
    echo "KV Name: $KV_TITLE | Worker Name: $WORKER_NAME"
fi

# 4. ساخت KV
echo "Creating KV Namespace..."
KV_ID=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/storage/kv/namespaces" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" \
     --data "{\"title\": \"$KV_TITLE\"}" | jq -r '.result.id')

# 5. ساخت Metadata برای اتصال KV به ورکر
echo "{\"body_part\":\"script\",\"bindings\":[{\"type\":\"kv_namespace\",\"name\":\"KV\",\"namespace_id\":\"$KV_ID\"}]}" > metadata.json

# 6. آپلود ورکر (خواندن از فایل worker.js)
echo -e "${BLUE}[*] Uploading Worker...${NC}"

# اینجا نکته اصلیه: ما فایل worker.js رو که کنار اسکریپت هست میخونیم
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -F "metadata=@metadata.json;type=application/json" \
     -F "script=@worker.js;type=application/javascript"

# 7. فعال‌سازی ساب‌دامین
echo "Deploying to Subdomain..."
curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME/subdomain" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{"enabled":true}'

echo -e "${GREEN}Done! Your Panel URL: https://$WORKER_NAME.$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/subdomain" -H "Authorization: Bearer $CF_TOKEN" | jq -r '.result.subdomain').workers.dev${NC}"
