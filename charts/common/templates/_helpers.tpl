{{/*
Common labels
*/}}
{{- define "openlake.labels" -}}
app.kubernetes.io/name: {{ include "openlake.hive.serviceName" . }}
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
Hive Metastore service name
*/}}
{{- define "openlake.hive.serviceName" -}}
{{- printf "%s-hive-metastore" (include "openlake.name" .) -}}
{{- end }}

{{/*
Hive Metastore config name
*/}}
{{- define "openlake.hive.configName" -}}
{{- printf "%s-hive-metastore-cfg" (include "openlake.name" .) -}}
{{- end }}
