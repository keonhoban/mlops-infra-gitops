for mode in ab_test canary blue_green; do
  yq e ".env.ALIAS_SELECTION_MODE=\"$mode\"" -i charts/fastapi/values/dev.yaml
  grep -A 10 '^env:' charts/fastapi/values/dev.yaml
  git commit -am "test: $mode routing" && git push
  sleep 120  # ArgoCD 동기화 대기
  ./ops/ab_test.sh 500
done
