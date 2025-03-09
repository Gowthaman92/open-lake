{{/*
Common labels
*/}}
{{- define "openlake.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common name prefix
*/}}
{{- define "openlake.name" -}}
{{- .Values.nameOverride | default "openlake" -}}
{{- end }}

{{/*
Postgres cluster name
*/}}
{{- define "openlake.postgres.clusterName" -}}
{{- printf "%s-postgres-cluster" (include "openlake.name" .) -}}
{{- end }}

{{/*
Trino service name
*/}}
{{- define "openlake.trino.serviceName" -}}
{{- printf "%s-trino" (include "openlake.name" .) -}}
{{- end }}

{{/*
Generic service name helper
*/}}
{{- define "openlake.serviceName" -}}
{{- $name := include "openlake.name" . -}}
{{- if .serviceSuffix -}}
{{- printf "%s-%s" $name .serviceSuffix -}}
{{- else -}}
{{- $name -}}
{{- end -}}
{{- end }}
