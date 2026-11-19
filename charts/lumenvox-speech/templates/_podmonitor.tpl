{{- /*
One PodMonitor (monitoring.coreos.com/v1) for a scaled speech Deployment, with the
Deployment's name and selector. Renders only when podMonitor.enabled resolves to
true.

Inputs (dict): root, service (key under global), name (Deployment name), and
optionally langCfg (the language's podMonitor overrides).

Each field resolves from langCfg, then global.<service>.podMonitor, then
global.podMonitor; labels merge key by key, the more specific value winning.

target:
  app    container http port, /metrics
  istio  Istio sidecar merged metrics, :15020/stats/prometheus (for strict mTLS)
  auto   (default) istio when global.serviceMesh.type is "istio", else app

Usage:
  {{- include "lumenvox-speech.PODMONITOR" (dict "root" $ "service" "grammar" "name" "grammar") }}
*/}}
{{- define "lumenvox-speech.PODMONITOR" }}
{{- $root := .root }}
{{- $service := .service }}
{{- $name := .name }}
{{- $langCfg := .langCfg | default (dict) }}
{{- $svcCfg := dig $service "podMonitor" (dict) $root.Values.global }}
{{- $globalCfg := dig "podMonitor" (dict) $root.Values.global }}
{{- $layers := list $langCfg $svcCfg $globalCfg }}
{{- $cfg := dict }}
{{- range $f := list "enabled" "target" "interval" "scrapeTimeout" }}
{{- $v := "" }}
{{- range $l := $layers }}
{{- if and (eq (toString $v) "") (hasKey $l $f) (not (kindIs "invalid" (index $l $f))) }}{{ $v = index $l $f }}{{ end }}
{{- end }}
{{- $_ := set $cfg $f $v }}
{{- end }}
{{- if eq (toString $cfg.enabled) "true" }}
{{- $at := printf "PodMonitor %s (global.%s.podMonitor)" $name $service }}
{{- $labels := dict }}
{{- range $l := reverse $layers }}
{{- $ls := dig "labels" (dict) $l }}
{{- if not (kindIs "map" $ls) }}
{{- fail (printf "\n\n%s: labels must be a map." $at) }}
{{- end }}
{{- $labels = merge (deepCopy $ls) $labels }}
{{- end }}
{{- $_ := unset $labels "app" }}
{{- $target := toString $cfg.target | default "auto" }}
{{- if not (has $target (list "auto" "app" "istio")) }}
{{- fail (printf "\n\n%s: target must be auto, app or istio, got %q." $at $target) }}
{{- end }}
{{- if eq $target "auto" }}
{{- $mesh := "" }}
{{- if hasKey $root.Values.global "serviceMesh" }}{{ $mesh = toString ($root.Values.global.serviceMesh.type | default "") }}{{ end }}
{{- $target = ternary "istio" "app" (eq $mesh "istio") }}
{{- end }}
{{- range $f := list "interval" "scrapeTimeout" }}
{{- $d := toString (index $cfg $f) }}
{{- if and (ne $d "") (not (regexMatch "^([0-9]+(ms|s|m|h))+$" $d)) }}
{{- fail (printf "\n\n%s: %s must be a duration such as \"15s\" or \"1m\", got %q." $at $f $d) }}
{{- end }}
{{- end }}
---
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: {{ $name }}
  namespace: {{ default $root.Release.Namespace $root.Values.global.defaultNamespace }}
  labels:
    app: {{ $name }}
    {{- range $k := keys $labels | sortAlpha }}
    {{ $k }}: {{ index $labels $k | toString | quote }}
    {{- end }}
spec:
  selector:
    matchLabels:
      app: {{ $name }}
  podMetricsEndpoints:
    {{- if eq $target "istio" }}
    - port: http-envoy-prom
      path: /stats/prometheus
      relabelings:
        - sourceLabels: [__address__]
          regex: '([^:]+)(?::\d+)?'
          replacement: '${1}:15020'
          targetLabel: __address__
          action: replace
    {{- else }}
    - port: http
      path: /metrics
    {{- end }}
      {{- with $cfg.interval }}
      interval: {{ . | quote }}
      {{- end }}
      {{- with $cfg.scrapeTimeout }}
      scrapeTimeout: {{ . | quote }}
      {{- end }}
{{- end }}
{{- end }}
