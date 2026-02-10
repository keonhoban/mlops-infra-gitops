{{/*
Common labels helpers (triton)
*/}}

{{- define "triton.name" -}}
triton
{{- end -}}

{{- define "triton.component" -}}
inference
{{- end -}}

{{- define "triton.labels" -}}
app.kubernetes.io/name: {{ include "triton.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ include "triton.component" . }}
app.kubernetes.io/part-of: mlops
{{- end -}}

{{- define "triton.selectorLabels" -}}
app.kubernetes.io/name: {{ include "triton.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ include "triton.component" . }}
{{- end -}}

