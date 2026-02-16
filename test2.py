set -euo pipefail

echo "=============================="
echo "[CHART] feast (optional)"
echo "=============================="

helm lint optional/charts/feast --strict

echo "--- template: dev ---"
helm template test-feast-dev optional/charts/feast -n "feature-store-dev" \
  -f optional/charts/feast/values/base.yaml \
  -f optional/envs/dev/feast/values.yaml \
  --debug > /tmp/feast-dev.yaml

echo "--- template: prod ---"
helm template test-feast-prod optional/charts/feast -n "feature-store-prod" \
  -f optional/charts/feast/values/base.yaml \
  -f optional/envs/prod/feast/values.yaml \
  --debug > /tmp/feast-prod.yaml

echo "OK: /tmp/feast-dev.yaml /tmp/feast-prod.yaml"

