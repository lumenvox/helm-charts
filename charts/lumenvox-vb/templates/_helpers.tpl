{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "voice-biometrics.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "lumenvox-vb.CLUSTER_LANGUAGES__VB_ACTIVE" }}
{{- $listStarted := false }}
{{- range .Values.global.vbLanguages }}
{{- $vbVersion := .version | default $.Values.global.vbDefaultVersion }}
{{- if $listStarted }};{{ end }}vba_mvimp_{{ .name }}-{{ $vbVersion }}
{{- $listStarted = true }}
{{- end }}
{{- end }}
