{{- /*
Resolves drainTimeoutSeconds for asr, transcribeRealtime, transcribeBatch, session
and lumenvoxApi from langCfg, then global.<service>.

Inputs (dict): root, service (key under global), name (Deployment name, for
errors), grace (terminationGracePeriodSeconds when no drain is set), and
optionally langCfg (the language's services.<service> entry).

When set, terminationGracePeriodSeconds becomes the larger of grace and
preStop (15) + drainTimeoutSeconds + 30. Returns JSON
{"seconds": "<drain or empty>", "grace": "<seconds>"}; parse with fromJson.

Usage:
  {{- $drain := include "lumenvox-speech.DRAIN" (dict "root" $ "service" "session" "name" "session" "grace" 300) | fromJson }}
*/}}
{{- define "lumenvox-speech.DRAIN" }}
{{- $langCfg := .langCfg | default (dict) }}
{{- if not (kindIs "map" $langCfg) }}{{ $langCfg = dict }}{{ end }}
{{- $svcCfg := dig .service (dict) .root.Values.global }}
{{- if not (kindIs "map" $svcCfg) }}{{ $svcCfg = dict }}{{ end }}
{{- $v := "" }}
{{- $at := "" }}
{{- range $i, $l := list $langCfg $svcCfg }}
{{- if and (eq (toString $v) "") (hasKey $l "drainTimeoutSeconds") (not (kindIs "invalid" (index $l "drainTimeoutSeconds"))) }}
{{- $v = index $l "drainTimeoutSeconds" }}
{{- $at = ternary (printf "asrLanguages[].services.%s" $.service) (printf "global.%s" $.service) (eq $i 0) }}
{{- end }}
{{- end }}
{{- $seconds := toString $v }}
{{- $grace := int .grace }}
{{- if ne $seconds "" }}
{{- if not (regexMatch "^[1-9][0-9]*$" $seconds) }}
{{- fail (printf "\n\n%s (%s): drainTimeoutSeconds must be a whole number of seconds above 0, got %q." .name $at $seconds) }}
{{- end }}
{{- $grace = max $grace (add 15 (atoi $seconds) 30) }}
{{- end }}
{{- dict "seconds" $seconds "grace" (toString $grace) | toJson }}
{{- end }}
