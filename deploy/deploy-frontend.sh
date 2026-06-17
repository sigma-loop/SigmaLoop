#!/usr/bin/env bash
# Manual frontend deploy (the GitHub Action does this automatically on push to
# main — use this for a one-off deploy from your laptop). Needs the AWS CLI
# configured with access to the bucket + distribution.
#
#   BUCKET=sigmaloop-frontend DISTRIBUTION_ID=E123… ./deploy-frontend.sh
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-https://api.sigmaloop.dpdns.org/api/v1}"
BUCKET="${BUCKET:?set BUCKET=your-s3-bucket-name}"
DISTRIBUTION_ID="${DISTRIBUTION_ID:?set DISTRIBUTION_ID=your-cloudfront-id}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/Frontend"

echo "==> Building with VITE_API_BASE_URL=$API_BASE_URL"
npm ci
VITE_API_BASE_URL="$API_BASE_URL" npm run build

echo "==> Syncing dist/ → s3://$BUCKET"
aws s3 sync dist/ "s3://$BUCKET" --delete \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude index.html
aws s3 cp dist/index.html "s3://$BUCKET/index.html" \
  --cache-control "no-cache"

echo "==> Invalidating CloudFront"
aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*"
echo "Done."
