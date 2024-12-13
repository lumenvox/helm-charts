{{/* vim: set filetype=mustache: */}}

{{/*
Renders pod scheduling behavior, for those behaviors that are present.
Usage:
{{ template "lumenvox-common.deployments.podScheduling" $ }}
*/}}
{{- define "lumenvox-common.deployments.podScheduling" }}
{{- if .Values.global.deployments.nodeSelector }}
{{ println "nodeSelector:" | indent 6 }}
{{ include "common.tplvalues.render" ( dict "value" .Values.global.deployments.nodeSelector "context" $ ) | nindent 8 }}
{{- end }}
{{- if .Values.global.deployments.affinity }}
{{ println "affinity:" | indent 6 }}
{{ include "common.tplvalues.render" ( dict "value" .Values.global.deployments.affinity "context" $ ) | nindent 8 }}
{{- end }}
{{- if .Values.global.deployments.tolerations }}
{{ println "tolerations:" | indent 6 }}
{{ include "common.tplvalues.render" ( dict "value" .Values.global.deployments.tolerations "context" $ ) | nindent 8 }}
{{- end }}
{{- end }}
