{{/*
Render-time checks for configurations that cannot start or that drop data.
Helm prints only the parent chart's NOTES, so these use `fail`.
Included from the agent and gateway ConfigMaps.
*/}}
{{- define "otelcol.validate" -}}
{{- $otel := default dict .Values.global.otel -}}

{{- if and .Values.gateway.enabled (eq .Values.gateway.backend "split") -}}
{{- $any := "" -}}
{{- range $signal := (list "traces" "metrics" "logs") -}}
{{- if (index $.Values.gateway.split $signal).endpoint -}}{{- $any = "yes" -}}{{- end -}}
{{- end -}}
{{- if not $any -}}
{{- fail "lumenvox-otel-collector: gateway.backend is \"split\" but no signal has an endpoint. Set at least one of gateway.split.{traces,metrics,logs}.endpoint." -}}
{{- end -}}
{{- end -}}

{{- if and $otel.enabled .Values.gateway.enabled (eq .Values.gateway.backend "split") -}}
{{- range $signal := (list "traces" "metrics" "logs") -}}
{{- $sdkOn := dig $signal "enabled" (ne $signal "logs") $otel -}}
{{- $dest := (index $.Values.gateway.split $signal).endpoint -}}
{{- if and $sdkOn (not $dest) -}}
{{- fail (printf "lumenvox-otel-collector: global.otel.%s.enabled is true but gateway.split.%s.endpoint is empty; %s would be dropped. Set the endpoint or global.otel.%s.enabled: false." $signal $signal $signal $signal) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- if and .Values.gateway.enabled (eq .Values.gateway.backend "split") -}}
{{- $known := list "otlp" "otlphttp" "splunk_hec" -}}
{{- range $signal := (list "traces" "metrics" "logs") -}}
{{- $cfg := index $.Values.gateway.split $signal -}}
{{- if $cfg.endpoint -}}
{{- $type := include "otelcol.signalExporterType" (dict "root" $ "signal" $signal) -}}
{{- if not (has $type $known) -}}
{{- fail (printf "lumenvox-otel-collector: gateway.split.%s.type %q is not one of: %s." $signal $type (join ", " $known)) -}}
{{- end -}}
{{- if and (eq $type "splunk_hec") (not $.Values.gateway.extraEnvFromSecrets) -}}
{{- fail (printf "lumenvox-otel-collector: gateway.split.%s.type is \"splunk_hec\" but gateway.extraEnvFromSecrets is empty. Provide a Secret exposing %s." $signal (default "SPLUNK_HEC_TOKEN" $cfg.tokenEnvVar)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- if .Values.gateway.enabled -}}
{{- range $c := (list "spanMetrics" "serviceGraph") -}}
{{- if (index $.Values.gateway $c).enabled -}}
{{- if not (include "otelcol.signalEnabled" (dict "root" $ "signal" "metrics")) -}}
{{- fail (printf "lumenvox-otel-collector: gateway.%s.enabled requires a metrics destination. Set gateway.split.metrics.endpoint (Prometheus requires --web.enable-otlp-receiver) or disable gateway.%s." $c $c) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- if and .Values.agent.enabled .Values.agent.filelog.enabled .Values.gateway.enabled -}}
{{- if not (include "otelcol.signalEnabled" (dict "root" $ "signal" "logs")) -}}
{{- fail "lumenvox-otel-collector: agent.filelog.enabled requires a logs destination. Set gateway.split.logs.endpoint or disable agent.filelog." -}}
{{- end -}}
{{- $lvl := upper (default "" .Values.agent.filelog.minLevel) -}}
{{- if and $lvl (not (has $lvl (list "DEBUG" "INFO" "WARN" "ERROR"))) -}}
{{- fail (printf "lumenvox-otel-collector: agent.filelog.minLevel is %q; use \"\", DEBUG, INFO, WARN or ERROR." .Values.agent.filelog.minLevel) -}}
{{- end -}}
{{- if not (has .Values.agent.filelog.startAt (list "end" "beginning")) -}}
{{- fail (printf "lumenvox-otel-collector: agent.filelog.startAt is %q; use end or beginning." .Values.agent.filelog.startAt) -}}
{{- end -}}
{{- if and .Values.global.otel .Values.global.otel.enabled (dig "logs" "enabled" false .Values.global.otel) -}}
{{- fail "lumenvox-otel-collector: agent.filelog.enabled and global.otel.logs.enabled are both true; each log line would be delivered twice. Set global.otel.logs.enabled: false." -}}
{{- end -}}
{{- end -}}

{{- if and $otel.enabled (eq (default "agent" $otel.endpointMode) "agent") (not .Values.agent.enabled) -}}
{{- fail "lumenvox-otel-collector: global.otel.endpointMode is \"agent\" but agent.enabled is false. Enable the agent or set global.otel.endpointMode: gateway." -}}
{{- end -}}

{{- end }}
