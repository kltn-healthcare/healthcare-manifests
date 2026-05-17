#!/bin/bash

echo "====================================================================="
echo "PLEASE PASTE THE ENTIRE CREDENTIALS BLOCK FROM AWS ACADEMY HERE:"
echo "(After pasting, press ENTER to go to a new line, then press CTRL + D)"
echo "====================================================================="

# Read the entire text block pasted by the user
RAW_CREDS=$(cat)

# Extract keys using grep and cut, removing spaces and Windows carriage returns (\r)
ACCESS_KEY_ID=$(echo "$RAW_CREDS" | grep aws_access_key_id | cut -d'=' -f2 | tr -d ' \r ')
SECRET_ACCESS_KEY=$(echo "$RAW_CREDS" | grep aws_secret_access_key | cut -d'=' -f2 | tr -d ' \r ')
SESSION_TOKEN=$(echo "$RAW_CREDS" | grep aws_session_token | cut -d'=' -f2 | tr -d ' \r ')

# Check if all 3 required keys were extracted successfully
if [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ] || [ -z "$SESSION_TOKEN" ]; then
    echo "❌ ERROR: Missing required credentials or incomplete input. Please try again!"
    exit 1
fi

echo "=> Creating and applying Secret directly into 'external-secrets' namespace..."

# Apply the secret directly to K8s cluster without generating static files
kubectl create secret generic aws-academy-creds \
  -n external-secrets \
  --from-literal=access-key-id="$ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$SECRET_ACCESS_KEY" \
  --from-literal=session-token="$SESSION_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=> Restarting External Secrets Operator deployment to apply new keys immediately..."
# FIXED: Changed deployment name from 'external-secrets' to 'external-secrets-operator'
kubectl rollout restart deployment external-secrets-operator -n external-secrets

echo "====================================================================="
echo " Update successful! System is syncing automatically."
echo "====================================================================="