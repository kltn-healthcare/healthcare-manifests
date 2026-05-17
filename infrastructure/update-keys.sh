#!/bin/bash

echo "====================================================================="
echo "PLEASE PASTE THE ENTIRE CREDENTIALS BLOCK FROM AWS ACADEMY HERE:"
echo "(After pasting, press ENTER to go to a new line, then press CTRL + D)"
echo "====================================================================="

# Read the raw multiline input from clipboard/terminal
RAW_INPUT=$(cat)

# Algorithm to stitch wrapped lines together (If a line doesn't contain '=', append to previous line)
CLEANED_CREDS=""
while IFS= read -r line; do
    # Strip carriage returns and leading/trailing whitespaces
    line=$(echo "$line" | tr -d '\r' | xargs)
    if [[ "$line" == *=* ]]; then
        CLEANED_CREDS="$CLEANED_CREDS"$'\n'"$line"
    else
        CLEANED_CREDS="$CLEANED_CREDS""$line"
    fi
done <<< "$RAW_INPUT"

# Extract exact values from the reconstructed text block
ACCESS_KEY_ID=$(echo "$CLEANED_CREDS" | grep aws_access_key_id | cut -d'=' -f2 | tr -d ' ')
SECRET_ACCESS_KEY=$(echo "$CLEANED_CREDS" | grep aws_secret_access_key | cut -d'=' -f2 | tr -d ' ')
SESSION_TOKEN=$(echo "$CLEANED_CREDS" | grep aws_session_token | cut -d'=' -f2 | tr -d ' ')

# Validate if any token component is missing
if [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ] || [ -z "$SESSION_TOKEN" ]; then
    echo "❌ ERROR: Failed to parse credentials. Please ensure you copied the entire block."
    exit 1
fi

# Print parsed configuration details for Admin verification
echo ""
echo "====================================================================="
echo "                  PARSED CREDENTIALS VERIFICATION                    "
echo "====================================================================="
echo "▶ AWS_ACCESS_KEY_ID     : $ACCESS_KEY_ID (Length: ${#ACCESS_KEY_ID} chars)"
echo "▶ AWS_SECRET_ACCESS_KEY : $SECRET_ACCESS_KEY (Length: ${#SECRET_ACCESS_KEY} chars)"
echo "▶ AWS_SESSION_TOKEN     : ${SESSION_TOKEN:0:50}...[TRUNCATED OUTPUT FOR CLEAN VIEW]...${SESSION_TOKEN: -50}"
echo "  [Total Session Token Length: ${#SESSION_TOKEN} bytes]"
echo "====================================================================="
echo ""

echo "=> Applying Secret directly into 'external-secrets' namespace..."
# Update Kubernetes Secret directly
kubectl create secret generic aws-academy-creds \
  -n external-secrets \
  --from-literal=access-key-id="$ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$SECRET_ACCESS_KEY" \
  --from-literal=session-token="$SESSION_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=> Restarting External Secrets Operator to catch new credentials..."
kubectl rollout restart deployment external-secrets-operator -n external-secrets

echo "=> Waiting 15 seconds for the operator to restart and sync with AWS..."
sleep 15

echo ""
echo "====================================================================="
echo "                     AUTOMATED STATUS CHECK                          "
echo "====================================================================="
echo "1. Checking K8s Secret Size:"
kubectl describe secret aws-academy-creds -n external-secrets | grep -E "access-key-id|secret-access-key|session-token"

echo ""
echo "2. Checking ClusterSecretStore Infrastructure Status:"
kubectl get clustersecretstore

echo ""
echo "3. Checking ExternalSecrets Sync Status Across All Namespaces:"
kubectl get externalsecrets -A
echo "====================================================================="