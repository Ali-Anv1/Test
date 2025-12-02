#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Cloudflare Panel Installer (GitHub)   ${NC}"
echo -e "${BLUE}=========================================${NC}"

# 1. نصب پیش‌نیازها
echo -e "${YELLOW}[*] Checking dependencies...${NC}"
pkg install jq curl -y > /dev/null 2>&1

# 2. دانلود فایل ورکر از گیتهاب شما
echo -e "${YELLOW}[*] Downloading worker.js from GitHub...${NC}"
# لینک فایل خام (Raw) از ریپازیتوری شما
GITHUB_URL="https://raw.githubusercontent.com/Ali-Anv1/Test/main/worker.mjs"

curl -sSL $GITHUB_URL -o worker.js

if [ ! -f "worker.js" ] || [ ! -s "worker.mjs" ]; then
    echo -e "${RED}[!] Error: Failed to download worker.js! Check your internet or GitHub URL.${NC}"
    exit 1
fi
echo -e "${GREEN}[+] Worker code downloaded successfully.${NC}"

# 3. دریافت توکن
echo -e "${YELLOW}----------------------------------------${NC}"
read -p "Enter Cloudflare API Token: " CF_TOKEN

echo -e "${YELLOW}[*] Verifying Token...${NC}"
VERIFY_RES=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json")

STATUS=$(echo $VERIFY_RES | jq -r '.success')

if [ "$STATUS" != "true" ]; then
    echo -e "${RED}[!] Invalid Token. Please check permissions (Workers:Edit, KV:Edit).${NC}"
    exit 1
fi

ACCOUNT_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

echo -e "${GREEN}[+] Token Verified. Account ID: $ACCOUNT_ID${NC}"

# 4. تنظیمات نام پروژه و KV (سوال از کاربر)
echo -e "${YELLOW}----------------------------------------${NC}"

# KV Name
read -p "Do you want a custom name for KV? (y/n): " KV_OPT
if [[ "$KV_OPT" == "y" || "$KV_OPT" == "Y" ]]; then
    read -p "Enter KV Name: " KV_TITLE
else
    RAND=$(tr -dc a-z0-9 </dev/urandom | head -c 5)
    KV_TITLE="bp_kv_$RAND"
    echo -e "Using Random KV Name: ${BLUE}$KV_TITLE${NC}"
fi

# Worker Name
read -p "Do you want a custom name for Project (Worker)? (y/n): " WORKER_OPT
if [[ "$WORKER_OPT" == "y" || "$WORKER_OPT" == "Y" ]]; then
    read -p "Enter Project Name: " WORKER_NAME
else
    RAND=$(tr -dc a-z0-9 </dev/urandom | head -c 5)
    WORKER_NAME="bp-panel-$RAND"
    echo -e "Using Random Worker Name: ${BLUE}$WORKER_NAME${NC}"
fi

# 5. ساخت KV
echo -e "${YELLOW}[*] Creating KV Namespace...${NC}"
KV_RES=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/storage/kv/namespaces" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" \
     --data "{\"title\": \"$KV_TITLE\"}")

KV_ID=$(echo $KV_RES | jq -r '.result.id')

if [ "$KV_ID" == "null" ] || [ -z "$KV_ID" ]; then
    echo -e "${RED}[!] Failed to create KV Namespace.${NC}"
    echo $KV_RES
    exit 1
fi
echo -e "${GREEN}[+] KV Created (ID: $KV_ID)${NC}"

# 6. ساخت فایل متادیتا (بایندینگ KV)
# نکته مهم: اینجا name رو دقیقاً KV گذاشتیم
echo "{\"body_part\":\"script\",\"bindings\":[{\"type\":\"kv_namespace\",\"name\":\"KV\",\"namespace_id\":\"$KV_ID\"}]}" > metadata.json

# 7. آپلود و دیپلوی ورکر
echo -e "${YELLOW}[*] Deploying Worker ($WORKER_NAME)...${NC}"

UPLOAD_RES=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -F "metadata=@metadata.json;type=application/json" \
     -F "script=@worker.js;type=application/javascript")

SUCCESS=$(echo $UPLOAD_RES | jq -r '.success')

if [ "$SUCCESS" != "true" ]; then
    echo -e "${RED}[!] Upload Failed!${NC}"
    echo $UPLOAD_RES
    exit 1
fi

# فعال کردن ساب‌دامین
curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME/subdomain" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{"enabled":true}' > /dev/null

# دریافت آدرس ساب‌دامین کاربر
SUBDOMAIN=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/subdomain" \
    -H "Authorization: Bearer $CF_TOKEN" | jq -r '.result.subdomain')

# 8. پایان
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}✅ Installation Completed Successfully!${NC}"
echo -e "🔗 Your Panel URL: ${YELLOW}https://$WORKER_NAME.$SUBDOMAIN.workers.dev${NC}"
echo -e "${BLUE}=========================================${NC}"

# پاک کردن فایل‌های موقت
rm worker.js metadata.json
