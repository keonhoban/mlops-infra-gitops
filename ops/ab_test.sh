#!/bin/bash
# ab_test.sh — A/B/Canary/Blue-Green 분포 검증
# 사용: ./ab_test.sh [N]  (기본 N=200)
set -euo pipefail

N=${1:-200}
URL=${FASTAPI_URL:-"https://fastapi.local"}
PAYLOAD='{"data": [[5.1, 3.5, 1.4, 0.2]]}'

echo "🔍 A/B·Canary·Blue-Green 분포 확인 (${N}건)"
: > ab_test_result.log
for i in $(seq 1 $N); do
  id="client_$i"
  variant=$(curl -sk "${URL}/predict" \
    -H "Content-Type: application/json" \
    -H "x-client-id: ${id}" \
    -d "${PAYLOAD}" | jq -r '.variant')
  echo "$id → $variant" | tee -a ab_test_result.log >/dev/null
done

count_B=$(grep -c "→ B" ab_test_result.log || true)
count_A=$((N - count_B))
ratio=$((count_B * 100 / N))
echo "📊 결과: A=${count_A}, B=${count_B} (B=${ratio}%)"
