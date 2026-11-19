{{- /*
One PodDisruptionBudget (policy/v1) for a scaled speech Deployment, with the
Deployment's name and selector. Renders only when podDisruptionBudget.enabled
resolves to true.

Inputs (dict): root, service (key under global), name (Deployment name), and
optionally langCfg (the language's podDisruptionBudget overrides).

Each field resolves from langCfg, then global.<service>.podDisruptionBudget, then
lumenvox-speech.transcribeBatch.podDisruptionBudget (transcribeBatch, when its
enabled is true), then global.podDisruptionBudget. minAvailable and
maxUnavailable are taken together from the first layer that sets either; the
default is minAvailable: 1.

Usage:
  {{- include "lumenvox-speech.PDB" (dict "root" $ "service" "grammar" "name" "grammar") }}
*/}}
{{- define "lumenvox-speech.PDB" }}
{{- $root := .root }}
{{- $service := .service }}
{{- $name := .name }}
{{- $langCfg := .langCfg | default (dict) }}
{{- $svcCfg := dig $service "podDisruptionBudget" (dict) $root.Values.global }}
{{- $globalCfg := dig "podDisruptionBudget" (dict) $root.Values.global }}
{{- $legacyCfg := dict }}
{{- if eq $service "transcribeBatch" }}
{{- $legacy := dig "podDisruptionBudget" (dict) ($root.Values.transcribeBatch | default (dict)) }}
{{- if eq (toString (dig "enabled" false $legacy)) "true" }}{{ $legacyCfg = $legacy }}{{ end }}
{{- end }}
{{- $layers := list $langCfg $svcCfg $legacyCfg $globalCfg }}
{{- $paths := list "its language entry's podDisruptionBudget" (printf "global.%s.podDisruptionBudget" $service) "lumenvox-speech.transcribeBatch.podDisruptionBudget" "global.podDisruptionBudget" }}
{{- $cfg := dict }}
{{- $from := dict }}
{{- range $f := list "enabled" "unhealthyPodEvictionPolicy" }}
{{- $v := "" }}
{{- range $i, $l := $layers }}
{{- if and (eq (toString $v) "") (hasKey $l $f) (not (kindIs "invalid" (index $l $f))) }}{{ $v = index $l $f }}{{ $_ := set $from $f (index $paths $i) }}{{ end }}
{{- end }}
{{- $_ := set $cfg $f $v }}
{{- end }}
{{- if eq (toString $cfg.enabled) "true" }}
{{- $budget := dict }}
{{- range $i, $l := $layers }}
{{- $at := printf "PodDisruptionBudget %s (%s)" $name (index $paths $i) }}
{{- if not $budget }}
{{- $min := dig "minAvailable" "" $l }}
{{- $max := dig "maxUnavailable" "" $l }}
{{- if kindIs "invalid" $min }}{{ $min = "" }}{{ end }}
{{- if kindIs "invalid" $max }}{{ $max = "" }}{{ end }}
{{- if and (ne (toString $min) "") (ne (toString $max) "") }}
{{- fail (printf "\n\n%s: set minAvailable (%v) or maxUnavailable (%v), not both." $at $min $max) }}
{{- end }}
{{- if ne (toString $min) "" }}{{ $budget = dict "field" "minAvailable" "value" $min "at" $at }}
{{- else if ne (toString $max) "" }}{{ $budget = dict "field" "maxUnavailable" "value" $max "at" $at }}
{{- end }}
{{- end }}
{{- end }}
{{- if not $budget }}{{ $budget = dict "field" "minAvailable" "value" 1 "at" "" }}{{ end }}
{{- $value := toString $budget.value }}
{{- if not (regexMatch "^[0-9]+%?$" $value) }}
{{- fail (printf "\n\n%s: %s must be a non-negative integer or a percentage such as \"50%%\", got %q." $budget.at $budget.field $value) }}
{{- end }}
{{- $policy := toString $cfg.unhealthyPodEvictionPolicy }}
{{- if and (ne $policy "") (not (has $policy (list "IfHealthyBudget" "AlwaysAllow"))) }}
{{- fail (printf "\n\n%s: unhealthyPodEvictionPolicy must be IfHealthyBudget or AlwaysAllow, got %q." (printf "PodDisruptionBudget %s (%s)" $name $from.unhealthyPodEvictionPolicy) $policy) }}
{{- end }}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ $name }}
  namespace: {{ default $root.Release.Namespace $root.Values.global.defaultNamespace }}
  labels:
    app: {{ $name }}
spec:
  {{- if hasSuffix "%" $value }}
  {{ $budget.field }}: {{ $value | quote }}
  {{- else }}
  {{ $budget.field }}: {{ $value | atoi }}
  {{- end }}
  {{- if $policy }}
  unhealthyPodEvictionPolicy: {{ $policy }}
  {{- end }}
  selector:
    matchLabels:
      app: {{ $name }}
{{- end }}
{{- end }}
