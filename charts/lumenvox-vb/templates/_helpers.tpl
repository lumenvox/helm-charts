{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "voice-biometrics.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /* lumenvox-vb.CLUSTER_LANGUAGES__VB_ACTIVE is defined in lumenvox-common's
_helpers.tpl: lumenvox-common deployments reference it, and it must stay
available when this chart is disabled (global.enabled.lumenvoxVb: false). */}}
