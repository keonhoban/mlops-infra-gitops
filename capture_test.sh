for mode in ab_test canary blue_green; do
  echo ""
  echo "=============================="
  echo "🧪 테스트 모드 시작: $mode"
  echo "=============================="
  echo ""

  grep -A 10 '^env:' charts/fastapi/values/dev.yaml
  yq e ".env.ALIAS_SELECTION_MODE=\"$mode\"" -i charts/fastapi/values/dev.yaml
  grep -A 10 '^env:' charts/fastapi/values/dev.yaml

  git add charts/fastapi/values/dev.yaml
  git commit -am "test: $mode routing" && git push

  echo "⏳ ArgoCD 동기화 대기 중..."
  sleep 120

  echo "🚀 테스트 실행 중 ($mode)"
  ./ops/ab_test.sh 500

  echo ""
  echo "✅ 테스트 모드 종료: $mode"
  echo "──────────────────────────────"
  echo ""
done
