{{/*
Expand the name of the chart.
*/}}
{{- define "migrate.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "migrate.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "migrate.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "migrate.labels" -}}
helm.sh/chart: {{ include "migrate.chart" . }}
{{ include "migrate.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "migrate.selectorLabels" -}}
app.kubernetes.io/name: {{ include "migrate.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "migrate.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "migrate.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Build the migrate command arguments
*/}}
{{- define "migrate.args" -}}
{{- $args := list .Values.migration.command -}}
{{- if eq .Values.migration.command "analyze" -}}
  {{- if .Values.migration.source.connectionString -}}
    {{- $args = append $args "--source" -}}
    {{- $args = append $args .Values.migration.source.connectionString -}}
  {{- else if .Values.migration.source.sqlFile -}}
    {{- $args = append $args "--source" -}}
    {{- $args = append $args (printf "/sql/%s" .Values.migration.source.sqlFile) -}}
    {{- $args = append $args "--dialect" -}}
    {{- $args = append $args .Values.migration.source.dialect -}}
  {{- end -}}
  {{- if .Values.migration.output.format -}}
    {{- $args = append $args "--output" -}}
    {{- $args = append $args .Values.migration.output.format -}}
  {{- end -}}
{{- else if eq .Values.migration.command "diff" -}}
  {{- if .Values.migration.source.connectionString -}}
    {{- $args = append $args "--source" -}}
    {{- $args = append $args .Values.migration.source.connectionString -}}
  {{- else if .Values.migration.source.sqlFile -}}
    {{- $args = append $args "--source" -}}
    {{- $args = append $args (printf "/sql/%s" .Values.migration.source.sqlFile) -}}
  {{- end -}}
  {{- if .Values.migration.target.connectionString -}}
    {{- $args = append $args "--target" -}}
    {{- $args = append $args .Values.migration.target.connectionString -}}
  {{- else if .Values.migration.target.sqlFile -}}
    {{- $args = append $args "--target" -}}
    {{- $args = append $args (printf "/sql/%s" .Values.migration.target.sqlFile) -}}
  {{- end -}}
  {{- if .Values.migration.output.format -}}
    {{- $args = append $args "--output" -}}
    {{- $args = append $args .Values.migration.output.format -}}
  {{- end -}}
{{- else if eq .Values.migration.command "transform" -}}
  {{- $args = append $args "--input" -}}
  {{- $args = append $args (printf "/sql/%s" .Values.migration.transform.inputFile) -}}
  {{- $args = append $args "--from" -}}
  {{- $args = append $args .Values.migration.transform.fromDialect -}}
  {{- $args = append $args "--to" -}}
  {{- $args = append $args .Values.migration.transform.toDialect -}}
{{- end -}}
{{- toJson $args -}}
{{- end }}
