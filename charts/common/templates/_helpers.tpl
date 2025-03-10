{{/*
Common labels
*/}}
{{- define "openlake.labels" -}}
{{- $releaseName := "" }}
{{- $releaseService := "" }}
{{- if .Release }}
  {{- $releaseName = .Release.Name }}
  {{- $releaseService = .Release.Service }}
{{- else if .context }}
  {{- if .context.Release }}
    {{- $releaseName = .context.Release.Name }}
    {{- $releaseService = .context.Release.Service }}
  {{- end }}
{{- end }}

{{- if .component }}
app.kubernetes.io/name: {{ include "openlake.serviceName" (dict "component" .component "context" .context) }}
{{- else }}
app.kubernetes.io/name: {{ include "openlake.name" . }}
{{- end }}
app.kubernetes.io/instance: {{ $releaseName }}
app.kubernetes.io/managed-by: {{ $releaseService }}
app.kubernetes.io/part-of: openlake
{{- end }}

{{/*
Common name prefix
*/}}
{{- define "openlake.name" -}}
{{- .Values.nameOverride | default "openlake" -}}
{{- end }}

{{/*
Generic service name helper
*/}}
{{- define "openlake.serviceName" -}}
{{- $component := .component | default "" -}}
{{- if $component -}}
{{- printf "%s-%s" (include "openlake.name" .context) $component -}}
{{- else -}}
{{- include "openlake.name" .context -}}
{{- end -}}
{{- end }}

{{/*
Postgres cluster name
*/}}
{{- define "openlake.postgres.clusterName" -}}
{{- printf "%s-postgres-cluster" (include "openlake.name" .) -}}
{{- end }}

{{/*
Hive Metastore config name
*/}}
{{- define "openlake.hive.configName" -}}
{{- printf "%s-hive-metastore-cfg" (include "openlake.name" .) -}}
{{- end }}
