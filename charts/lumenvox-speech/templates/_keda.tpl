{{- /*
One KEDA ScaledObject (Prometheus trigger) for a speech Deployment. Renders only
when global.keda.enabled and the service's autoscaling.enabled are both true.

Inputs (dict):
  root       chart context ($)
  service    key under global: asr, transcribeRealtime, transcribeBatch, itn,
             neuralTts, grammar, vad, session, lumenvoxApi, diarization or lid
  name       Deployment name; the ScaledObject is <name><global.keda.nameSuffix>
  lang       (optional) language entry, used to resolve GPU
  langCfg    (optional) the language's autoscaling overrides
  looped     (optional) true when the service has one Deployment per language
  langCount  (optional) number of those Deployments

Each field resolves from langCfg, then global.<service>.autoscaling, then
global.keda. With GPU on for an asr, transcribeRealtime or transcribeBatch
language, the threshold is the language's own threshold, else gpuThreshold.
The default selector is `app` for per-language services except itn, and
`namespace` otherwise; itn's default metric is emitted by the transcribe pods.
extraTriggers entries inherit unset query fields from the primary trigger.

Usage:
  {{- include "lumenvox-speech.SCALEDOBJECT" (dict "root" $ "service" "grammar" "name" "grammar") }}
*/}}
{{- define "lumenvox-speech.SCALEDOBJECT" }}
{{- $root := .root }}
{{- $service := .service }}
{{- $name := .name }}
{{- $lang := .lang | default (dict) }}
{{- $langCfg := .langCfg | default (dict) }}
{{- $looped := .looped | default false }}
{{- $langCount := .langCount | default 1 | int }}
{{- $svcCfg := dig $service "autoscaling" (dict) $root.Values.global }}
{{- $keda := $root.Values.global.keda }}
{{- $ns := default $root.Release.Namespace $root.Values.global.defaultNamespace }}
{{- $kedaDefaults := dict "pollingInterval" (dig "pollingInterval" "" $keda) "cooldownPeriod" (dig "cooldownPeriod" "" $keda) "scaleDownStabilizationSeconds" (dig "scaleDownStabilizationSeconds" "" $keda) "failureThreshold" (dig "fallback" "failureThreshold" "" $keda) "fallbackReplicas" (dig "fallback" "replicas" "" $keda) "fallbackBehavior" (dig "fallback" "behavior" "" $keda) "selector" (dig "query" "selector" "" $keda) "orVectorZero" (dig "query" "orVectorZero" true $keda) "metricType" (dig "metricType" "" $keda) }}
{{- $cfg := dict }}
{{- range $f := list "enabled" "minReplicas" "maxReplicas" "threshold" "gpuThreshold" "fallbackReplicas" "failureThreshold" "fallbackBehavior" "pollingInterval" "cooldownPeriod" "scaleDownStabilizationSeconds" "pausedReplicas" "metric" "metricName" "metricType" "selector" "selectorLabels" "orVectorZero" "pendingMetric" "pendingSelector" "pendingSelectorLabels" "extraTriggers" "query" "transcriptionThreshold" }}
{{- $v := "" }}
{{- if hasKey $langCfg $f }}{{ $v = index $langCfg $f }}
{{- else if hasKey $svcCfg $f }}{{ $v = index $svcCfg $f }}
{{- else if hasKey $kedaDefaults $f }}{{ $v = index $kedaDefaults $f }}
{{- end }}
{{- if kindIs "invalid" $v }}{{ $v = "" }}{{ end }}
{{- $_ := set $cfg $f $v }}
{{- end }}
{{- if and $keda.enabled $cfg.enabled }}
{{- $at := printf "ScaledObject %s (global.%s.autoscaling)" $name $service }}
{{- range $f := list "minReplicas" "maxReplicas" }}
{{- if eq (toString (index $cfg $f)) "" }}{{ fail (printf "\n\n%s: %s is required. Set it in global.%s.autoscaling or per language." $at $f $service) }}{{ end }}
{{- end }}
{{- if gt (int (index $cfg "minReplicas")) (int (index $cfg "maxReplicas")) }}
{{- fail (printf "\n\n%s: minReplicas (%v) is greater than maxReplicas (%v)." $at $cfg.minReplicas $cfg.maxReplicas) }}
{{- end }}
{{- if ne (toString $cfg.transcriptionThreshold) "" }}
{{- fail (printf "\n\n%s: transcriptionThreshold is no longer read. Use extraTriggers: [{metric: asr_active_transcription_requests, threshold: %v}]." $at $cfg.transcriptionThreshold) }}
{{- end }}
{{- $threshold := $cfg.threshold }}
{{- if and $lang (has $service (list "asr" "transcribeRealtime" "transcribeBatch")) }}
{{- $gpu := include "lumenvox-speech.RESOLVE_SERVICE_GPU" (dict "root" $root "lang" $lang "service" $service) | fromJson }}
{{- if and $gpu.enabled (not (hasKey $langCfg "threshold")) }}
{{- if ne (toString $cfg.gpuThreshold) "" }}{{ $threshold = $cfg.gpuThreshold }}
{{- else }}
{{- fail (printf "\n\n%s: gpuThreshold is required when GPU is enabled. Set it in global.%s.autoscaling or per language, below the pod's maxActiveRequests (%s); about 0.75 x that is a starting point." $at $service (ternary "not set" (toString $gpu.maxActiveRequests) (eq (toString $gpu.maxActiveRequests) ""))) }}
{{- end }}
{{- end }}
{{- end }}
{{- if eq (toString $threshold) "" }}
{{- fail (printf "\n\n%s: threshold is required (gpuThreshold when GPU is on). Set it in global.%s.autoscaling or per language." $at $service) }}
{{- end }}
{{- if eq (toString $keda.prometheus.serverAddress) "" }}
{{- fail (printf "\n\n%s: global.keda.prometheus.serverAddress is required when global.keda.enabled is true." $at) }}
{{- end }}
{{- if and (eq (toString $cfg.fallbackReplicas) "") (eq (toString (dig "requireFallback" false $keda)) "true") }}
{{- fail (printf "\n\n%s: global.keda.requireFallback is true but no fallback replicas are set. Set global.keda.fallback.replicas or fallbackReplicas." $at) }}
{{- end }}
{{- if ne (toString $cfg.fallbackBehavior) "" }}
{{- if not (has (toString $cfg.fallbackBehavior) (list "static" "currentReplicas" "currentReplicasIfHigher" "currentReplicasIfLower")) }}
{{- fail (printf "\n\n%s: fallback behavior %q is not supported. Use static, currentReplicas, currentReplicasIfHigher or currentReplicasIfLower." $at (toString $cfg.fallbackBehavior)) }}
{{- end }}
{{- if eq (toString $cfg.fallbackReplicas) "" }}
{{- fail (printf "\n\n%s: fallback behavior needs fallback replicas. Set global.keda.fallback.replicas or fallbackReplicas." $at) }}
{{- end }}
{{- end }}
{{- $metrics := dict "asr" "asr_active_asr_requests" "transcribeRealtime" "transcribe_realtime_active_requests" "transcribeBatch" "transcribe_batch_active_requests" "itn" "transcribe_realtime_active_transcription_requests" "neuralTts" "tts_active_requests" "grammar" "grammar_active_grammars" "vad" "vad_active_requests" "session" "session_active_streams" "lumenvoxApi" "lumenvox_api_active_requests" "diarization" "diarization_active_requests" "lid" "lid_active_requests" }}
{{- $metric := ternary (index $metrics $service) (toString $cfg.metric) (eq (toString $cfg.metric) "") }}
{{- $mode := ternary (ternary "app" "namespace" (and $looped (ne $service "itn"))) (toString $cfg.selector) (eq (toString $cfg.selector) "") }}
{{- $selector := include "lumenvox-speech.KEDA_SELECTOR" (dict "at" $at "mode" $mode "labels" $cfg.selectorLabels "looped" $looped "langCount" $langCount "deployment" $name "namespace" $ns "language" (toString (dig "name" "" $lang))) | trim }}
{{- $query := include "lumenvox-speech.KEDA_TERM" (dict "metric" $metric "selector" $selector "orVectorZero" $cfg.orVectorZero) | trim }}
{{- if ne (toString $cfg.pendingMetric) "" }}
{{- if and $looped (gt $langCount 1) }}
{{- fail (printf "\n\n%s: pending gauges have no language label, so pendingMetric is not supported with %d languages. Set it only when one language is deployed." $at $langCount) }}
{{- end }}
{{- $pendingMode := ternary "namespace" (toString $cfg.pendingSelector) (eq (toString $cfg.pendingSelector) "") }}
{{- $pendingSelector := include "lumenvox-speech.KEDA_SELECTOR" (dict "at" $at "mode" $pendingMode "labels" $cfg.pendingSelectorLabels "looped" false "langCount" 1 "deployment" $name "namespace" $ns "language" (toString (dig "name" "" $lang))) | trim }}
{{- $query = printf "%s + %s" $query (include "lumenvox-speech.KEDA_TERM" (dict "metric" $cfg.pendingMetric "selector" $pendingSelector "orVectorZero" $cfg.orVectorZero) | trim) }}
{{- end }}
{{- if ne (toString $cfg.query) "" }}{{ $query = toString $cfg.query }}{{ end }}
{{- $extra := list }}
{{- if hasKey $langCfg "extraTriggers" }}{{ $extra = index $langCfg "extraTriggers" }}
{{- else if hasKey $svcCfg "extraTriggers" }}{{ $extra = index $svcCfg "extraTriggers" }}
{{- end }}
{{- if kindIs "invalid" $extra }}{{ $extra = list }}{{ end }}
{{- if and $extra (not (kindIs "slice" $extra)) }}
{{- fail (printf "\n\n%s: extraTriggers must be a list of {metric, threshold, ...} entries." $at) }}
{{- end }}
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ $name }}{{ dig "nameSuffix" "" $keda }}
  namespace: {{ $ns }}
  {{- if ne (toString $cfg.pausedReplicas) "" }}
  annotations:
    autoscaling.keda.sh/paused-replicas: {{ toString $cfg.pausedReplicas | quote }}
  {{- end }}
spec:
  scaleTargetRef:
    name: {{ $name }}
  {{- if ne (toString $cfg.pollingInterval) "" }}
  pollingInterval: {{ int $cfg.pollingInterval }}
  {{- end }}
  {{- if ne (toString $cfg.cooldownPeriod) "" }}
  cooldownPeriod: {{ int $cfg.cooldownPeriod }}
  {{- end }}
  minReplicaCount: {{ int $cfg.minReplicas }}
  maxReplicaCount: {{ int $cfg.maxReplicas }}
  {{- if ne (toString $cfg.fallbackReplicas) "" }}
  fallback:
    failureThreshold: {{ int (default 3 $cfg.failureThreshold) }}
    replicas: {{ int $cfg.fallbackReplicas }}
    {{- if ne (toString $cfg.fallbackBehavior) "" }}
    behavior: {{ $cfg.fallbackBehavior }}
    {{- end }}
  {{- end }}
  {{- if ne (toString $cfg.scaleDownStabilizationSeconds) "" }}
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: {{ int $cfg.scaleDownStabilizationSeconds }}
  {{- end }}
  triggers:
    {{- include "lumenvox-speech.KEDA_TRIGGER" (dict "serverAddress" $keda.prometheus.serverAddress "metricType" $cfg.metricType "metricName" $cfg.metricName "query" $query "threshold" $threshold) }}
    {{- range $i, $t := $extra }}
    {{- $tat := printf "%s extraTriggers[%d]" $at $i }}
    {{- if not (kindIs "map" $t) }}{{ fail (printf "\n\n%s must be a map with metric and threshold." $tat) }}{{ end }}
    {{- if or (eq (toString (dig "metric" "" $t)) "") (eq (toString (dig "threshold" "" $t)) "") }}{{ fail (printf "\n\n%s: metric and threshold are required." $tat) }}{{ end }}
    {{- $tmode := ternary $mode (toString (dig "selector" "" $t)) (eq (toString (dig "selector" "" $t)) "") }}
    {{- $tlabels := ternary $cfg.selectorLabels (dig "selectorLabels" (dict) $t) (not (hasKey $t "selectorLabels")) }}
    {{- $tsel := include "lumenvox-speech.KEDA_SELECTOR" (dict "at" $tat "mode" $tmode "labels" $tlabels "looped" $looped "langCount" $langCount "deployment" $name "namespace" $ns "language" (toString (dig "name" "" $lang))) | trim }}
    {{- $tvec := ternary $cfg.orVectorZero (dig "orVectorZero" false $t) (not (hasKey $t "orVectorZero")) }}
    {{- $tquery := include "lumenvox-speech.KEDA_TERM" (dict "metric" $t.metric "selector" $tsel "orVectorZero" $tvec) | trim }}
    {{- include "lumenvox-speech.KEDA_TRIGGER" (dict "serverAddress" $keda.prometheus.serverAddress "metricType" (ternary $cfg.metricType (toString (dig "metricType" "" $t)) (not (hasKey $t "metricType"))) "metricName" (toString (dig "metricName" "" $t)) "query" $tquery "threshold" $t.threshold) }}
    {{- end }}
{{- end }}
{{- end }}

{{- /* One Prometheus trigger. Inputs: serverAddress, query, threshold, metricType, metricName. */}}
{{- define "lumenvox-speech.KEDA_TRIGGER" }}
    - type: prometheus
      {{- if ne (toString .metricType) "" }}
      metricType: {{ .metricType }}
      {{- end }}
      metadata:
        serverAddress: {{ .serverAddress | quote }}
        {{- if ne (toString .metricName) "" }}
        metricName: {{ .metricName }}
        {{- end }}
        query: {{ .query | quote }}
        threshold: {{ toString .threshold | quote }}
{{- end }}

{{- /*
The label selector (text between the braces). Inputs: at, mode, labels, looped,
langCount, deployment, namespace, language. A non-empty `labels` map wins over `mode`.
*/}}
{{- define "lumenvox-speech.KEDA_SELECTOR" }}
{{- $parts := list }}
{{- if and (kindIs "map" .labels) .labels }}
{{- range $k, $v := .labels }}
{{- $parts = append $parts (printf "%s=%s" $k (toString $v | replace "$(deployment)" $.deployment | replace "$(namespace)" $.namespace | replace "$(language)" $.language | quote)) }}
{{- end }}
{{- else }}
{{- if not (has .mode (list "app" "namespace" "appAndNamespace")) }}
{{- fail (printf "\n\n%s: selector must be app, namespace or appAndNamespace, got %q." .at .mode) }}
{{- end }}
{{- if and .looped (gt (int .langCount) 1) (eq .mode "namespace") }}
{{- fail (printf "\n\n%s: selector \"namespace\" sums all %d languages into each scaler. Use \"app\" or selectorLabels." .at (int .langCount)) }}
{{- end }}
{{- if or (eq .mode "app") (eq .mode "appAndNamespace") }}
{{- $parts = append $parts (printf "app=%s" (.deployment | quote)) }}
{{- end }}
{{- if or (eq .mode "namespace") (eq .mode "appAndNamespace") }}
{{- $parts = append $parts (printf "namespace=%s" (.namespace | quote)) }}
{{- end }}
{{- end }}
{{- join "," $parts }}
{{- end }}

{{- /* One query term, sum(<metric>{<selector>}). Inputs: metric, selector, orVectorZero. */}}
{{- define "lumenvox-speech.KEDA_TERM" }}
{{- if eq (toString .orVectorZero) "true" }}
{{- printf "sum(%s{%s} or vector(0))" .metric .selector }}
{{- else }}
{{- printf "sum(%s{%s})" .metric .selector }}
{{- end }}
{{- end }}
