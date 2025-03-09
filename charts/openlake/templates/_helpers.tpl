{{/*
Common labels
*/}}
{{- define "openlake.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: openlake
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "openlake.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Postgres cluster name
*/}}
{{- define "openlake.postgres.clusterName" -}}
{{- .Values.postgres.clusterName | default (printf "%s-postgres-cluster" .Release.Name) }}
{{- end }}

{{/*
Database credentials secret name pattern
*/}}
{{- define "openlake.postgres.credentialsSecretName" -}}
{{- $user := . -}}
{{- $root := index . 0 -}}
{{- $username := index . 1 -}}
{{- $clusterName := include "openlake.postgres.clusterName" $root -}}
{{- printf "%s.%s.credentials.postgresql.acid.zalan.do" $username $clusterName }}
{{- end }} 