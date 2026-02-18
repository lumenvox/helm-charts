{{/*
Service mesh annotations helper function.
Returns the appropriate service mesh injection annotation based on the configured service mesh type.
Supports: linkerd, istio, or none (empty string)

Usage: {{- include "lumenvox-common.serviceMeshAnnotations" . | indent 8 }}
*/}}
{{- define "lumenvox-common.serviceMeshAnnotations" -}}
{{- $serviceMesh := "" }}
{{- if hasKey .Values.global "serviceMesh" }}
{{- $serviceMesh = .Values.global.serviceMesh.type | default "" }}
{{- else if hasKey .Values.global "linkerd" }}
{{- if .Values.global.linkerd.enabled }}
{{- $serviceMesh = "linkerd" }}
{{- end }}
{{- end }}
{{- if eq $serviceMesh "linkerd" }}
{{- $ingressMode := "" }}
{{- if hasKey .Values.global "serviceMesh" }}
{{- if hasKey .Values.global.serviceMesh "linkerd" }}
{{- $ingressMode = .Values.global.serviceMesh.linkerd.ingressMode | default "" }}
{{- end }}
{{- end }}
{{- if eq $ingressMode "traefik" }}
linkerd.io/inject: ingress
{{- else }}
linkerd.io/inject: enabled
{{- end }}
{{- else if eq $serviceMesh "istio" }}
sidecar.istio.io/inject: "true"
{{- $excludeOutboundPorts := "" }}
{{- $istioConfig := .Values.global.serviceMesh.istio | default dict }}
{{- if hasKey $istioConfig "excludeOutboundPorts" }}
{{- $excludeOutboundPorts = printf "%v" $istioConfig.excludeOutboundPorts }}
{{- else }}
{{- /* Default: exclude HTTPS port 443 to allow external HTTPS connections */}}
{{- $excludeOutboundPorts = "443" }}
{{- end }}
{{- end }}
{{- end }}
