{{/*
Base name for both tiers: global.otel.collectorName, else the release name.
lumenvox-common.otelEnv reads the same value to derive the gateway address.
*/}}
{{- define "otelcol.baseName" -}}
{{- $otel := default dict .Values.global.otel -}}
{{- default .Release.Name $otel.collectorName -}}
{{- end }}

{{- define "otelcol.agentName" -}}
{{ include "otelcol.baseName" . }}-agent
{{- end }}

{{/*
Gateway Deployment and Service name.
*/}}
{{- define "otelcol.gatewayName" -}}
{{ include "otelcol.baseName" . }}-gateway
{{- end }}

{{- define "otelcol.namespace" -}}
{{ default .Release.Namespace .Values.global.defaultNamespace }}
{{- end }}

{{- define "otelcol.serviceAccountName" -}}
{{ default (printf "%s-collector" .Release.Name) .Values.serviceAccount.name }}
{{- end }}

{{- define "otelcol.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end }}

{{- define "otelcol.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Exporter id for one signal.
Call as: include "otelcol.signalExporter" (dict "root" $ "signal" "traces")
*/}}
{{- define "otelcol.signalExporter" -}}
{{- $root := .root -}}
{{- $signal := .signal -}}
{{- $backend := $root.Values.gateway.backend -}}
{{- if eq $backend "datadog" -}}
datadog
{{- else if eq $backend "otlp" -}}
otlp/backend
{{- else if eq $backend "split" -}}
{{ include "otelcol.signalExporterType" (dict "root" $root "signal" $signal) }}/{{ $signal }}
{{- else -}}
{{- fail (printf "gateway.backend must be \"datadog\", \"otlp\" or \"split\", got %q" $backend) -}}
{{- end -}}
{{- end }}

{{/*
Whether a signal has a destination. In split mode, a signal with no endpoint
gets no pipeline.
*/}}
{{- define "otelcol.signalEnabled" -}}
{{- $root := .root -}}
{{- $signal := .signal -}}
{{- if eq $root.Values.gateway.backend "split" -}}
{{- $cfg := index $root.Values.gateway.split $signal -}}
{{- if $cfg.endpoint }}true{{ end -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{/*
GOMEMLIMIT from a Kubernetes memory quantity. Go requires KiB/MiB/GiB/TiB, so
Ki/Mi/Gi/Ti get a "B" suffix and bare byte counts pass through. Anything else
renders empty: a malformed GOMEMLIMIT aborts the Go runtime at startup.
*/}}
{{- define "otelcol.goMemLimit" -}}
{{- $v := . | toString -}}
{{- if regexMatch "^[0-9]+(Ki|Mi|Gi|Ti)$" $v -}}
{{- printf "%sB" $v -}}
{{- else if regexMatch "^[0-9]+$" $v -}}
{{- $v -}}
{{- end -}}
{{- end }}

{{/*
Exporter type for one signal in split mode. `type` takes precedence; otherwise
`protocol` maps grpc -> otlp, http -> otlphttp.
*/}}
{{- define "otelcol.signalExporterType" -}}
{{- $cfg := index .root.Values.gateway.split .signal -}}
{{- if $cfg.type -}}
{{- $cfg.type -}}
{{- else if eq (default "grpc" $cfg.protocol) "http" -}}
otlphttp
{{- else -}}
otlp
{{- end -}}
{{- end }}
