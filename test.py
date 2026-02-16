set -euo pipefail

for c in airflow mlflow triton fastapi; do
  echo "=============================="
  echo "[CHART] $c"
  echo "=============================="

  helm lint "charts/$c" --strict

  echo "--- template: dev ---"
  helm template "test-$c-dev" "charts/$c" -n "core-dev" \
    -f "charts/$c/values/base.yaml" \
    -f "envs/dev/$c/values.yaml" \
    --debug > "/tmp/$c-dev.yaml"

  echo "--- template: prod ---"
  helm template "test-$c-prod" "charts/$c" -n "core-prod" \
    -f "charts/$c/values/base.yaml" \
    -f "envs/prod/$c/values.yaml" \
    --debug > "/tmp/$c-prod.yaml"

  echo "OK: /tmp/$c-dev.yaml /tmp/$c-prod.yaml"
done

