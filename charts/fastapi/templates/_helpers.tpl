{{/*
FastAPI chart helpers
- commonLabels: 리소스 메타데이터 공통 라벨 (제출/운영용)
- selectorLabels: Deployment selector / Pod labels / Service selector / ServiceMonitor selector에 쓰는 "불변 세트"
*/}}

{{- define "fastapi.commonLabels" -}}
app.kubernetes.io/name: fastapi
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: api
app.kubernetes.io/part-of: mlops
{{- end -}}

{{- define "fastapi.selectorLabels" -}}
app.kubernetes.io/name: fastapi
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: api
{{- end -}}

