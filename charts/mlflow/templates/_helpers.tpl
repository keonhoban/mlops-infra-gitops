{{/*
Common labels helpers (mlflow)
*/}}

{{- define "mlflow.name" -}}
mlflow
{{- end -}}

{{- define "mlflow.component" -}}
tracking
{{- end -}}

{{- define "mlflow.labels" -}}
app.kubernetes.io/name: {{ include "mlflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ include "mlflow.component" . }}
app.kubernetes.io/part-of: mlops
{{- end -}}

{{- define "mlflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mlflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ include "mlflow.component" . }}
{{- end -}}

