{{/*
Expand the name of the chart.
*/}}
{{- define "streamingapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "streamingapp.fullname" -}}
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
{{- define "streamingapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "streamingapp.labels" -}}
helm.sh/chart: {{ include "streamingapp.chart" . }}
{{ include "streamingapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "streamingapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "streamingapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "streamingapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "streamingapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate MongoDB URI
*/}}
{{- define "streamingapp.mongoUri" -}}
{{- if .Values.mongodb.enabled }}
{{- printf "mongodb://mongodb:27017/%s" .Values.mongodb.env.MONGO_DB }}
{{- else }}
{{- .Values.mongodb.externalUri }}
{{- end }}
{{- end }}

{{/*
Image pull policy
*/}}
{{- define "streamingapp.imagePullPolicy" -}}
{{- .Values.imageRegistry.pullPolicy | default "Always" }}
{{- end }}

{{/*
Full image name
*/}}
{{- define "streamingapp.image" -}}
{{- $registry := .Values.imageRegistry.url }}
{{- $repository := .repository }}
{{- $tag := .tag | default $.Values.imageTag }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}
