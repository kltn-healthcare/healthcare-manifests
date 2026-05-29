#!/bin/bash

echo "Paste the entire credentials block from AWS Academy."
echo "After pasting, press Enter, then press Ctrl+D."

RAW_INPUT=$(cat)

# Stitch wrapped lines together: if a line lacks '=', append it to the previous line.
CLEANED_CREDS=""
while IFS= read -r line; do
    line=$(echo "$line" | tr -d '\r' | xargs)
    if [[ "$line" == *=* ]]; then
        CLEANED_CREDS="$CLEANED_CREDS"$'\n'"$line"
    else
        CLEANED_CREDS="$CLEANED_CREDS""$line"
    fi
done <<< "$RAW_INPUT"

ACCESS_KEY_ID=$(echo "$CLEANED_CREDS" | grep aws_access_key_id | cut -d'=' -f2 | tr -d ' ')
SECRET_ACCESS_KEY=$(echo "$CLEANED_CREDS" | grep aws_secret_access_key | cut -d'=' -f2 | tr -d ' ')
SESSION_TOKEN=$(echo "$CLEANED_CREDS" | grep aws_session_token | cut -d'=' -f2 | tr -d ' ')

if [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ] || [ -z "$SESSION_TOKEN" ]; then
    echo "ERROR: Failed to parse credentials. Ensure you copied the entire block."
    exit 1
fi

echo ""
echo "Parsed credentials:"
echo "AWS_ACCESS_KEY_ID: $ACCESS_KEY_ID (Length: ${#ACCESS_KEY_ID} chars)"
echo "AWS_SECRET_ACCESS_KEY: $SECRET_ACCESS_KEY (Length: ${#SECRET_ACCESS_KEY} chars)"
echo "AWS_SESSION_TOKEN: ${SESSION_TOKEN:0:50}...[TRUNCATED]...${SESSION_TOKEN: -50}"
echo "Total session token length: ${#SESSION_TOKEN} bytes"
echo ""

echo "Applying secret to the 'external-secrets' namespace..."
kubectl create secret generic aws-academy-creds \
  -n external-secrets \
  --from-literal=access-key-id="$ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$SECRET_ACCESS_KEY" \
  --from-literal=session-token="$SESSION_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Restarting External Secrets Operator to pick up new credentials..."
kubectl rollout restart deployment external-secrets-operator -n external-secrets

echo "Waiting 15 seconds for the operator to restart and sync with AWS..."
sleep 15

echo ""
echo "Status checks:"
echo "1. Checking K8s secret size:"
kubectl describe secret aws-academy-creds -n external-secrets | grep -E "access-key-id|secret-access-key|session-token"

echo ""
echo "2. Checking ClusterSecretStore status:"
kubectl get clustersecretstore

echo ""
echo "3. Checking ExternalSecrets sync status across all namespaces:"
kubectl get externalsecrets -A