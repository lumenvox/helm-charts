{{- define "lumenvox-common.deployments.podScheduling" }}
{{- with .nodeSelector }}
{{- println "nodeSelector:" | nindent 6 }}
{{- toYaml . | nindent 8 }}
{{- end }}
{{- with .affinity }}
{{- println "affinity:" | nindent 6 }}
{{- toYaml . | nindent 8 }}
{{- end }}
{{- with .tolerations }}
{{- println "tolerations:" | nindent 6 }}
{{- toYaml . | nindent 8 }}
{{- end }}
{{- end }}
