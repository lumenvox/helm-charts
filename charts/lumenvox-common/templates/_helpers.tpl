{{/*
Service mesh annotations helper function.
Returns the appropriate service mesh injection annotation based on the configured service mesh type.
Supports: linkerd, istio, or none (empty string)

Usage: {{- include "lumenvox-common.serviceMeshAnnotations" . | indent 8 }}
*/}}
{{/*
Returns the namespace where the Kubernetes Gateway resource is deployed.
*/}}
{{- define "lumenvox-common.gatewayNamespace" -}}
{{- .Values.global.lumenvox.gateway.namespace | default (default .Release.Namespace .Values.global.defaultNamespace) -}}
{{- end -}}

{{/*
Renders global.lumenvox.ingress.commonAnnotations plus grpcAnnotations or
httpAnnotations (per "kind") onto an nginx Ingress. Each is a list of
{name, value} entries, the same shape and defaults as 7.x values files, so
ssl-redirect and backend-protocol come from these lists, as they did in 7.x.
On a duplicate name, the kind-specific entry wins over the common one.
Keys passed in "skip" are left out, for a route that writes them itself, as are
keys starting with any "skipPrefix" entry (e.g. every auth-* key on a route that
must never inherit authentication).
A non-empty "allowlist" (list of CIDRs) renders whitelist-source-range from it and
wins over any whitelist-source-range entry in the lists.
Indentation is baked in (not left to the caller's nindent) so an empty result
renders nothing at all.
Usage: {{- include "lumenvox-common.nginxAnnotations" (dict "kind" "grpc" "root" $ "skip" (list "nginx.ingress.kubernetes.io/proxy-body-size")) }}
*/}}
{{- define "lumenvox-common.nginxAnnotations" -}}
{{- $ingress := .root.Values.global.lumenvox.ingress -}}
{{- $skip := .skip | default list -}}
{{- $skipPrefix := .skipPrefix | default list -}}
{{- with .allowlist }}
{{- $skip = append $skip "nginx.ingress.kubernetes.io/whitelist-source-range" }}
    nginx.ingress.kubernetes.io/whitelist-source-range: {{ join "," . | quote }}
{{- end }}
{{- $kindAnnotations := $ingress.httpAnnotations }}
{{- if eq .kind "grpc" }}
{{- $kindAnnotations = $ingress.grpcAnnotations }}
{{- end }}
{{- $merged := dict }}
{{- range concat ($ingress.commonAnnotations | default list) ($kindAnnotations | default list) }}
{{- $_ := set $merged .name (toString .value) }}
{{- end }}
{{- range $name, $value := $merged }}
{{- $skipped := has $name $skip }}
{{- range $skipPrefix }}
{{- if hasPrefix . $name }}{{ $skipped = true }}{{ end }}
{{- end }}
{{- if not $skipped }}
    {{ $name }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

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
{{- /* sidecar.istio.io/inject moved to labels (serviceMeshLabels helper) */}}
{{- $excludeOutboundPorts := "443" }}
{{- $istioConfig := .Values.global.serviceMesh.istio | default dict }}
{{- if hasKey $istioConfig "excludeOutboundPorts" }}
{{- $excludeOutboundPorts = printf "%v" $istioConfig.excludeOutboundPorts }}
{{- end }}
{{- if $excludeOutboundPorts }}
traffic.sidecar.istio.io/excludeOutboundPorts: {{ $excludeOutboundPorts | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- /*
Companion helper to serviceMeshAnnotations. Emits pod template LABELS needed for
service mesh sidecar injection. Currently only Istio needs a label (1.22+ webhook
object-selector requires sidecar.istio.io/inject as a LABEL, not annotation).
Linkerd uses annotations only, so this helper emits nothing for linkerd mode.

Usage in deployment templates:
  metadata:
    labels:
      app: my-service
{{- include "lumenvox-common.serviceMeshLabels" . | indent 8 }}
*/}}
{{- define "lumenvox-common.serviceMeshLabels" -}}
{{- $serviceMesh := "" }}
{{- if hasKey .Values.global "serviceMesh" }}
{{- $serviceMesh = .Values.global.serviceMesh.type | default "" }}
{{- else if hasKey .Values.global "linkerd" }}
{{- if .Values.global.linkerd.enabled }}
{{- $serviceMesh = "linkerd" }}
{{- end }}
{{- end }}
{{- if eq $serviceMesh "istio" }}
sidecar.istio.io/inject: "true"
{{- end }}
{{- end -}}

{{- /*
Language/model list helpers. These keep their historical "lumenvox-speech.*" /
"lumenvox-vb.*" names (all call sites reference those), but they are DEFINED here
in lumenvox-common because lumenvox-common's deployments (configuration, resource,
admin-portal, deployment-portal) call them: named templates from a disabled
subchart are never loaded, so defining them in the speech/vb charts breaks any
install with global.enabled.lumenvoxSpeech/lumenvoxVb set to false. They read
only .Values.global.* so they render identically from any chart's context.
*/}}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__ASR_LANGUAGES_VERSION" }}
{{- $listStarted := false }}
{{- $hasDistPkg := false }}
{{- range .Values.global.asrLanguages }}
{{- $asrVersion := .version | default $.Values.global.asrDefaultVersion }}
{{- if $listStarted }};{{ end }}{{ .name }}{{ if $asrVersion }}-{{ $asrVersion }}{{ end }}{{ if .fineTuned }};asr_finetuned_model_{{ .name }}{{ end }}
{{- $listStarted = true }}
{{- range .extraModels }}
{{- $extraVersion := .version | default $.Values.global.asrDefaultVersion }}
{{- if eq .name "dist_package_model_asr" }}{{ $hasDistPkg = true }}{{ end }}
{{- if $listStarted }};{{ end }}{{ .name }}{{ if $extraVersion }}-{{ $extraVersion }}{{ end }}
{{- end }}
{{- end }}
{{- range .Values.global.customAsrModels }}
{{- $asrVersion := .version | default $.Values.global.asrDefaultVersion }}
{{- if eq .name "dist_package_model_asr" }}{{ $hasDistPkg = true }}{{ end }}
{{- if $listStarted }};{{ end }}{{ .name }}{{ if $asrVersion }}-{{ $asrVersion }}{{ end }}
{{- $listStarted = true }}
{{- end }}
{{- if and $listStarted (not $hasDistPkg) }};dist_package_model_asr-{{ $.Values.global.asrDistPackageVersion }}{{ end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__ASR_LANGUAGES" }}
{{- $listStarted := false }}
{{- range .Values.global.asrLanguages }}
{{- if $listStarted }};{{ end }}{{ .name }}
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{- /*
Per-service ASR model loading (ASR_ENCODERS/ASR_DECODERS, TRANS_RT_ENCODERS/
TRANS_RT_DECODERS, TRANS_BATCH_ENCODERS/TRANS_BATCH_DECODERS). Each of
asr/transcribe-realtime/transcribe-batch loads ONLY the models listed in its
own mandatory, semicolon-separated env var instead of glob-loading every
model under /EuropaAsrModels. This helper builds one such list for a single
language (an entry of global.asrLanguages) and a single service.

  - The base (suffix-less) model is always emitted first when included,
    since the service only allows the base model to be listed first.
  - global.asrLanguages[].services.<service>.base (bool; default: true)
    controls whether the base ENCODER for this language loads on <service> -
    set to false to narrow a hidef-only service. Only encoders have a
    "default model" fallback concept, so this does not gate the base
    decoder: every service always loads the base decoder for its language,
    in addition to any extraModels decoders it's assigned.
  - global.asrLanguages[].decoderLocale overrides the locale used for the
    base decoder package name when it differs from the language name itself
    (e.g. decoderLocale: "en_us" for name: "en").
  - Additional (non-base) models come from global.asrLanguages[].extraModels,
    nested under the language they belong to. Each entry optionally takes
    `services: [...]` (default: all three) to scope which service(s) load
    it. global.customAsrModels stays reserved for shared, non-per-language
    download-only packages (e.g. dist_package_model_asr, backend_dnn_model_p)
    and is never loaded by these per-service env vars.
  - Fails the render if a service/language combination resolves to no
    models at all, since the target env var is mandatory and an empty value
    would just crash-loop the pod instead.

Usage (from inside `range .Values.global.asrLanguages` so `.` is the language):
  {{ template "lumenvox-speech.SERVICE_ASR_MODELS" (dict "root" $ "lang" . "service" "asr" "kind" "encoder") }}
kind is "encoder" or "decoder"; service is "asr", "transcribeRealtime", or "transcribeBatch".
*/}}
{{- define "lumenvox-speech.SERVICE_ASR_MODELS" }}
{{- $root := .root }}
{{- $lang := .lang }}
{{- $service := .service }}
{{- $kind := .kind }}
{{- $prefix := printf "asr_%s_" $kind }}
{{- $version := $lang.version | default $root.Values.global.asrDefaultVersion }}
{{- $baseName := $lang.name }}
{{- if eq $kind "decoder" }}
{{- /* Known cases where the installed base decoder locale differs from the
language name itself (confirmed via resource-service logs: "en" installs as
asr_decoder_model_en_us, there is no bare asr_decoder_model_en). Extend or
override this globally with global.asrDecoderLocaleDefaults (e.g. to add a
newly-confirmed language everywhere at once) - global.asrLanguages[].decoderLocale
still wins over both for a one-off exception. */}}
{{- $knownDecoderLocales := merge (dig "asrDecoderLocaleDefaults" (dict) $root.Values.global) (dict "en" "en_us") }}
{{- $defaultDecoderLocale := dig $lang.name $lang.name $knownDecoderLocales }}
{{- $baseName = dig "decoderLocale" $defaultDecoderLocale $lang }}
{{- end }}
{{- $listStarted := false }}
{{- $includeBase := true }}
{{- if eq $kind "encoder" }}
{{- $includeBase = dig "services" $service "base" true $lang }}
{{- end }}
{{- if $includeBase }}{{ $prefix }}model_{{ $baseName }}{{ if $version }}-{{ $version }}{{ end }}
{{- $listStarted = true }}
{{- end }}
{{- range dig "extraModels" (list) $lang }}
{{- if hasPrefix $prefix .name }}
{{- $modelServices := dig "services" (list "asr" "transcribeRealtime" "transcribeBatch") . }}
{{- if has $service $modelServices }}
{{- if $listStarted }};{{ end }}{{ .name }}{{ if .version }}-{{ .version }}{{ end }}
{{- $listStarted = true }}
{{- end }}
{{- end }}
{{- end }}
{{- if not $listStarted }}{{ fail (printf "lumenvox-speech: no %s models resolved for service=%s language=%s - check global.asrLanguages[].services.%s.base and .extraModels[].services" $kind $service $lang.name $service) }}
{{- end }}
{{- end }}

{{- /*
Resolves the effective GPU configuration for one language + service, merging:
  - global.gpu.<service> (count, visibleDevices, runtimeClassName;
    enabled defaults to false) - the chart-wide default for the service.
  - global.asrLanguages[].services.<service>.gpu, which may be a bare bool
    (shorthand for overriding just `enabled`) or an object overriding any
    subset of the same fields for this one language.
Per-language wins field-by-field; anything it doesn't set falls back to the
global default. Returns a JSON object; callers parse it with `fromJson`
since named templates can otherwise only return strings.

Usage (from inside `range .Values.global.asrLanguages` so `.` is the language):
  {{- $asrGpu := include "lumenvox-speech.RESOLVE_SERVICE_GPU" (dict "root" $ "lang" . "service" "asr") | fromJson }}
service is "asr", "transcribeRealtime", or "transcribeBatch".
*/}}
{{- define "lumenvox-speech.RESOLVE_SERVICE_GPU" }}
{{- $root := .root }}
{{- $lang := .lang }}
{{- $service := .service }}
{{- $globalGpu := dig "gpu" $service (dict) $root.Values.global }}
{{- $langGpu := dig "services" $service "gpu" (dict) $lang }}
{{- if kindIs "bool" $langGpu }}
{{- $langGpu = dict "enabled" $langGpu }}
{{- end }}
{{- dict
  "enabled" (dig "enabled" (dig "enabled" false $globalGpu) $langGpu)
  "count" (dig "count" (dig "count" 1 $globalGpu) $langGpu)
  "visibleDevices" (dig "visibleDevices" (dig "visibleDevices" "" $globalGpu) $langGpu)
  "runtimeClassName" (dig "runtimeClassName" (dig "runtimeClassName" "" $globalGpu) $langGpu)
  "maxActiveRequests" (dig "maxActiveRequests" (dig "maxActiveRequests" "" $globalGpu) $langGpu)
  "resources" (dig "resources" (dig "resources" (dict) $globalGpu) $langGpu)
  "tolerations" (dig "tolerations" (dig "tolerations" (include "lumenvox-common.DEFAULT_GPU_TOLERATIONS" . | fromYamlArray) $globalGpu) $langGpu)
  | toJson }}
{{- end }}

{{- /*
Default GPU pod tolerations (when global.gpu.<service>.tolerations is not set) and
nlu's tolerations: the NVIDIA device plugin taint and the AKS spot node pool taint.
*/}}
{{- define "lumenvox-common.DEFAULT_GPU_TOLERATIONS" }}
- effect: NoSchedule
  key: nvidia.com/gpu
  operator: Exists
- effect: NoSchedule
  key: kubernetes.azure.com/scalesetpriority
  operator: Equal
  value: spot
{{- end }}

{{- /*
Renders the pod spec scheduling fields that are set: tolerations,
topologySpreadConstraints, nodeSelector, affinity and priorityClassName.

Inputs (dict):
  root             chart context ($)
  service          key under global (e.g. "asr", "grammar", "adminPortal")
  name             Deployment name, used in the topology spread selector
  langCfg          (optional) asrLanguages[].services.<service> for the asr family,
                   or the itnLanguages / ttsLanguages entry
  baseTolerations  (optional) chart tolerations (GPU pods, nlu), placed before the
                   user's

nodeSelector, affinity, tolerations and priorityClassName come whole from the first
level that has the key: langCfg, global.<service>, global.lumenvox. An explicit {}
or [] clears a wider setting. topologySpread resolves field by field in the same
order; for asr, global.lumenvox.decodeTopologySpread comes before
global.lumenvox.topologySpread.

Usage:
  {{- include "lumenvox-common.POD_SCHEDULING" (dict "root" $ "service" "grammar" "name" "grammar") }}
*/}}
{{- define "lumenvox-common.POD_SCHEDULING" }}
{{- $root := .root }}
{{- $service := .service }}
{{- $langCfg := .langCfg | default (dict) }}
{{- $svcCfg := dig $service (dict) $root.Values.global }}
{{- if not (kindIs "map" $svcCfg) }}{{ $svcCfg = dict }}{{ end }}
{{- if not (kindIs "map" $langCfg) }}{{ $langCfg = dict }}{{ end }}
{{- $chartCfg := $root.Values.global.lumenvox | default (dict) }}
{{- $layers := list $langCfg $svcCfg $chartCfg }}
{{- $at := printf "%s (global.%s)" .name $service }}
{{- $cfg := dict }}
{{- range $f := list "nodeSelector" "affinity" "tolerations" "priorityClassName" }}
{{- $v := "" }}
{{- $found := false }}
{{- range $l := $layers }}
{{- if and (not $found) (kindIs "map" $l) (hasKey $l $f) }}{{ $v = index $l $f }}{{ $found = true }}{{ end }}
{{- end }}
{{- if kindIs "invalid" $v }}{{ $v = "" }}{{ end }}
{{- $_ := set $cfg $f $v }}
{{- end }}
{{- range $f := list "nodeSelector" "affinity" }}
{{- $v := index $cfg $f }}
{{- if and $v (not (kindIs "map" $v)) }}{{ fail (printf "\n\n%s: %s must be a map." $at $f) }}{{ end }}
{{- end }}
{{- if and $cfg.tolerations (not (kindIs "slice" $cfg.tolerations)) }}{{ fail (printf "\n\n%s: tolerations must be a list." $at) }}{{ end }}
{{- if and $cfg.priorityClassName (not (kindIs "string" $cfg.priorityClassName)) }}{{ fail (printf "\n\n%s: priorityClassName must be a string." $at) }}{{ end }}
{{- $tolerations := concat (.baseTolerations | default (list)) ($cfg.tolerations | default (list)) }}
{{- $spreadLayers := list $langCfg $svcCfg }}
{{- if eq $service "asr" }}{{ $spreadLayers = append $spreadLayers (dig "decodeTopologySpread" (dict) $chartCfg) }}{{ end }}
{{- $spreadLayers = append $spreadLayers (dig "topologySpread" (dict) $chartCfg) }}
{{- $spread := dict }}
{{- range $f := list "enabled" "maxSkew" "topologyKey" "whenUnsatisfiable" "nodeTaintsPolicy" }}
{{- $v := "" }}
{{- range $i, $l := $spreadLayers }}
{{- $m := $l }}
{{- if lt $i 2 }}{{ $m = dig "topologySpread" (dict) $l }}{{ end }}
{{- if and (eq (toString $v) "") (kindIs "map" $m) (hasKey $m $f) (not (kindIs "invalid" (index $m $f))) }}{{ $v = index $m $f }}{{ end }}
{{- end }}
{{- $_ := set $spread $f $v }}
{{- end }}
{{- if $tolerations }}
      tolerations:
{{ toYaml $tolerations | indent 8 }}
{{- end }}
{{- if eq (toString $spread.enabled) "true" }}
      topologySpreadConstraints:
        - maxSkew: {{ $spread.maxSkew | default 1 }}
          topologyKey: {{ $spread.topologyKey | default "kubernetes.io/hostname" }}
          whenUnsatisfiable: {{ $spread.whenUnsatisfiable | default "ScheduleAnyway" }}
          nodeTaintsPolicy: {{ $spread.nodeTaintsPolicy | default "Honor" }}
          labelSelector:
            matchLabels:
              app: {{ .name }}
{{- end }}
{{- if $cfg.nodeSelector }}
      nodeSelector:
{{ toYaml $cfg.nodeSelector | indent 8 }}
{{- end }}
{{- if $cfg.affinity }}
      affinity:
{{ toYaml $cfg.affinity | indent 8 }}
{{- end }}
{{- if $cfg.priorityClassName }}
      priorityClassName: {{ $cfg.priorityClassName }}
{{- end }}
{{- end }}

{{- /*
Renders extra pod annotations, merged key by key from global.lumenvox.podAnnotations,
global.<service>.podAnnotations and the language's podAnnotations (most specific
wins). Keys the chart sets itself (prometheus.io/scrape, prometheus.io/port and the
service mesh annotations) are reserved and fail the render.

Usage:
  {{- include "lumenvox-common.POD_ANNOTATIONS" (dict "root" $ "service" "grammar" "name" "grammar") }}
*/}}
{{- define "lumenvox-common.POD_ANNOTATIONS" }}
{{- $root := .root }}
{{- $service := .service }}
{{- $langCfg := .langCfg | default (dict) }}
{{- $merged := dict }}
{{- $svcCfg := dig $service (dict) $root.Values.global }}
{{- if not (kindIs "map" $svcCfg) }}{{ $svcCfg = dict }}{{ end }}
{{- if not (kindIs "map" $langCfg) }}{{ $langCfg = dict }}{{ end }}
{{- range $src := list (dig "lumenvox" "podAnnotations" (dict) $root.Values.global) (dig "podAnnotations" (dict) $svcCfg) (dig "podAnnotations" (dict) $langCfg) }}
{{- if and $src (not (kindIs "map" $src)) }}{{ fail (printf "\n\n%s (global.%s): podAnnotations must be a map." $.name $service) }}{{ end }}
{{- range $k, $v := ($src | default (dict)) }}{{ $_ := set $merged $k (toString $v) }}{{ end }}
{{- end }}
{{- if $merged }}
{{- $reserved := list "prometheus.io/scrape" "prometheus.io/port" }}
{{- range $k, $_ := (include "lumenvox-common.serviceMeshAnnotations" $root | fromYaml) }}{{ $reserved = append $reserved $k }}{{ end }}
{{- range $k := keys $merged | sortAlpha }}
{{- if has $k $reserved }}{{ fail (printf "\n\n%s (global.%s): podAnnotations sets %q, which is reserved for the chart (metrics scraping or service mesh)." $.name $service $k) }}{{ end }}
        {{ $k }}: {{ index $merged $k | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- /*
Resolves the CPU and memory requests, or limits, for one service (or one language
of the asr family). "kind" is "requests" (default) or "limits". Each field resolves
on its own, first match wins:
  1. global.asrLanguages[].services.<service>.resources.<kind> (pass "lang")
  2. global.<service>.resources.<kind>
  3. "legacy" values from a deprecated key (e.g. tts.neuralTtsResources.requests)
  4. the built-in default ("cpu"/"memory"), only when the kind's flag is true
     (enforceReservations or enforceLimits) or "always" is true
An explicit "" or null omits the field. Returns JSON {"cpu": "...", "memory": "..."},
where "" means not rendered; parse with fromJson. For limits, pass the resolved
requests as "requests" to fail the render when a limit is below its request.

Usage:
  {{- $res := include "lumenvox-common.RESOLVE_SERVICE_RESOURCES" (dict "root" $ "lang" . "service" "asr" "cpu" "1000m" "memory" "4000Mi") | fromJson }}
  {{- $lim := include "lumenvox-common.RESOLVE_SERVICE_RESOURCES" (dict "root" $ "lang" . "service" "asr" "kind" "limits" "cpu" "1500m" "memory" "8000Mi" "requests" $res) | fromJson }}
*/}}
{{- define "lumenvox-common.RESOLVE_SERVICE_RESOURCES" }}
{{- $root := .root }}
{{- $service := .service }}
{{- $kind := .kind | default "requests" }}
{{- $defaults := dict "cpu" (.cpu | default "") "memory" (.memory | default "") }}
{{- $always := .always | default false }}
{{- $flag := ternary $root.Values.global.lumenvox.enforceLimits $root.Values.global.lumenvox.enforceReservations (eq $kind "limits") }}
{{- /* Values of the wrong type are ignored here; VALIDATE_SERVICE_RESOURCES reports them. */}}
{{- $langReq := dict }}
{{- if .lang }}
{{- $langRes := dig "services" $service "resources" (dict) .lang }}
{{- if kindIs "map" $langRes }}
{{- $q := index $langRes $kind }}
{{- if kindIs "map" $q }}{{ $langReq = $q }}{{ end }}
{{- end }}
{{- end }}
{{- $globalReq := dict }}
{{- $globalRes := dig $service "resources" (dict) $root.Values.global }}
{{- if kindIs "map" $globalRes }}
{{- $q := index $globalRes $kind }}
{{- if kindIs "map" $q }}{{ $globalReq = $q }}{{ end }}
{{- end }}
{{- $legacyReq := .legacy | default (dict) }}
{{- $out := dict }}
{{- range $field := list "cpu" "memory" }}
{{- $v := "" }}
{{- if hasKey $langReq $field }}
{{- $v = index $langReq $field }}
{{- else if hasKey $globalReq $field }}
{{- $v = index $globalReq $field }}
{{- else if hasKey $legacyReq $field }}
{{- $v = index $legacyReq $field }}
{{- else if or $flag $always }}
{{- $v = index $defaults $field }}
{{- end }}
{{- if kindIs "invalid" $v }}{{ $v = "" }}{{ end }}
{{- $_ := set $out $field (toString $v) }}
{{- end }}
{{- if and (eq $kind "limits") .requests }}
{{- $at := printf "global.%s.resources" $service }}
{{- if .lang }}{{ $at = printf "%s (language %s)" $at (toString .lang.name) }}{{ end }}
{{- range $field := list "cpu" "memory" }}
{{- $req := toString (index $.requests $field | default "") }}
{{- $lim := index $out $field }}
{{- if and $req $lim }}
{{- $reqN := include "lumenvox-common.QUANTITY_VALUE" $req }}
{{- $limN := include "lumenvox-common.QUANTITY_VALUE" $lim }}
{{- if and $reqN $limN (lt (float64 $limN) (float64 $reqN)) }}
{{- fail (printf "\n\n%s: limits.%s (%s) is lower than requests.%s (%s), and Kubernetes rejects such a pod. Raise the limit, lower the request, or set the limit to \"\" to leave it out." $at $field $lim $field $req) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- $out | toJson }}
{{- end }}

{{- /*
Converts a Kubernetes quantity (e.g. 1500m, 2, 512Mi, 8Gi) to a number in base
units (cores or bytes). Returns "" if it can't be parsed (e.g. 1e3).
*/}}
{{- define "lumenvox-common.QUANTITY_VALUE" }}
{{- $s := toString . }}
{{- if regexMatch "^([0-9]+(\\.[0-9]*)?|\\.[0-9]+)(m|k|M|G|T|P|E|Ki|Mi|Gi|Ti|Pi|Ei)?$" $s }}
{{- $num := float64 (regexReplaceAll "[a-zA-Z]+$" $s "") }}
{{- $suffix := regexReplaceAll "^[0-9.]+" $s "" }}
{{- $mult := dict "" 1 "k" 1000 "M" 1000000 "G" 1000000000 "T" 1000000000000 "P" 1000000000000000 "E" 1000000000000000000 "Ki" 1024 "Mi" 1048576 "Gi" 1073741824 "Ti" 1099511627776 "Pi" 1125899906842624 "Ei" 1152921504606846976 }}
{{- if eq $suffix "m" }}
{{- divf $num 1000 }}
{{- else }}
{{- mulf $num (index $mult $suffix) }}
{{- end }}
{{- end }}
{{- end }}

{{- /*
Returns a JSON list of problems in global.<service>.resources and
global.asrLanguages[].services.<service>.resources: only "requests" and "limits" are
read, each may hold only cpu and memory, and each value must be a Kubernetes quantity.

Usage:
  {{- $problems = concat $problems (include "lumenvox-common.VALIDATE_SERVICE_RESOURCES" (dict "root" $ "services" (list "asr" "grammar")) | fromJsonArray) }}
*/}}
{{- define "lumenvox-common.VALIDATE_SERVICE_RESOURCES" }}
{{- $root := .root }}
{{- $problems := list }}
{{- $targets := list }}
{{- range $service := .services }}
{{- $res := dig $service "resources" (dict) $root.Values.global }}
{{- $targets = append $targets (dict "at" (printf "global.%s.resources" $service) "res" $res) }}
{{- range $i, $lang := $root.Values.global.asrLanguages }}
{{- $langRes := dig "services" $service "resources" (dict) $lang }}
{{- $targets = append $targets (dict "at" (printf "global.asrLanguages[%d] (%s).services.%s.resources" $i (toString $lang.name) $service) "res" $langRes) }}
{{- end }}
{{- end }}
{{- range $t := $targets }}
{{- if not (kindIs "map" $t.res) }}
{{- $problems = append $problems (printf "%s: must be a map with a \"requests\" and/or \"limits\" section" $t.at) }}
{{- else }}
{{- range $key := keys $t.res | sortAlpha }}
{{- if not (has $key (list "requests" "limits")) }}
{{- $problems = append $problems (printf "%s.%s: not supported, only \"requests\" and \"limits\" are read" $t.at $key) }}
{{- end }}
{{- end }}
{{- range $kind := list "requests" "limits" }}
{{- $req := index $t.res $kind | default (dict) }}
{{- if not (kindIs "map" $req) }}
{{- $problems = append $problems (printf "%s.%s: must be a map with cpu and/or memory" $t.at $kind) }}
{{- else }}
{{- range $key := keys $req | sortAlpha }}
{{- if not (has $key (list "cpu" "memory")) }}
{{- $problems = append $problems (printf "%s.%s.%s: unknown key, use cpu or memory" $t.at $kind $key) }}
{{- else }}
{{- $v := index $req $key }}
{{- if not (or (kindIs "invalid" $v) (eq (toString $v) "")) }}
{{- if not (or (kindIs "string" $v) (kindIs "int" $v) (kindIs "int64" $v) (kindIs "float64" $v)) }}
{{- $problems = append $problems (printf "%s.%s.%s: must be a quantity such as 1000m or 8Gi" $t.at $kind $key) }}
{{- else if not (regexMatch "^([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([eE][+-]?[0-9]+|[mkMGTPE]|[KMGTPE]i)?$" (toString $v)) }}
{{- $problems = append $problems (printf "%s.%s.%s: %q is not a Kubernetes quantity, e.g. 1000m, 2, 512Mi or 8Gi" $t.at $kind $key (toString $v)) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- $problems | toJson }}
{{- end }}

{{- /*
Returns a JSON list of keys under global that hold a "resources" section but are not
one of the given services (e.g. a misspelled global.sesion).

Usage:
  {{- $problems = concat $problems (include "lumenvox-common.UNKNOWN_RESOURCE_SERVICES" (dict "root" $ "services" (list "asr" "grammar")) | fromJsonArray) }}
*/}}
{{- define "lumenvox-common.UNKNOWN_RESOURCE_SERVICES" }}
{{- $problems := list }}
{{- range $key := keys .root.Values.global | sortAlpha }}
{{- $v := index $.root.Values.global $key }}
{{- if and (kindIs "map" $v) (hasKey $v "resources") (not (has $key $.services)) }}
{{- $problems = append $problems (printf "global.%s.resources: %s is not a service with per-service resources" $key $key) }}
{{- end }}
{{- end }}
{{- $problems | toJson }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__ITN_LANGUAGES" }}
{{- $listStarted := false }}
{{- range .Values.global.itnLanguages }}
{{- if $listStarted }};{{ end }}{{ .name }}
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__DNN_MODULES" }}
{{- $fineTunedEnabled := false }}
{{- $nluEnabled := false }}
{{- $asrLangsDetected := false }}
{{- $itnLangsDetected := false }}
{{- if .Values.global.enableNlu }}{{ $nluEnabled = true }}{{ end }}
{{- range .Values.global.asrLanguages }}{{ $asrLangsDetected = true }}
{{- if .fineTuned }}{{ $fineTunedEnabled = true }}{{ end }}
{{- end }}
{{- if .Values.global.itnLanguages }}{{ $itnLangsDetected = true }}{{ end }}backend_dnn_model_p;dist_package_model_en
{{- if $fineTunedEnabled }};dist_package_model_finetuned{{ end }}
{{- if $nluEnabled }};dist_package_model_nlu{{ end }}
{{- if $asrLangsDetected }};backend_dnn_model_7-{{ .Values.global.dnnBackendVersion }}{{ end }}
{{- if $itnLangsDetected }};dist_package_model_itn-{{ .Values.global.itnDistPackageVersion }}{{ end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__TTS_LANGUAGES" }}
{{- $listStarted := false }}
{{- range .Values.global.ttsLanguages }}
{{- if $listStarted }};{{ end }}{{ .name | replace "_" "-" }}
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__TTS_VOICES" }}
{{- $listStarted := false }}
{{- $langRegion := "" }}
{{- range .Values.global.ttsLanguages }}
{{- $langRegion = .name }}
{{- range .voices }}
{{- if $listStarted }};{{ end }}tts_{{ $langRegion }}_{{ .name }}_22
{{- $listStarted = true }}
{{- end }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__NEURON_MODELS" }}
{{- $listStarted := false }}
{{- range .Values.global.neuronModels }}
{{- if $listStarted }};{{ end }}neuron{{ if .language }}_{{ .language }}{{ end }}_{{ .name }}{{ if .version }}-{{ .version }}{{ end }}
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__TTS_VOICES_VERSION" }}
{{- $listStarted := false }}
{{- $langRegion := "" }}
{{- $voiceVersion := "" }}
{{- range .Values.global.ttsLanguages }}
{{- if .legacyEnabled }}
{{- $langRegion = .name }}
{{- range .voices }}
{{- $voiceVersion = .version | default $.Values.global.ttsDefaultVersion }}
{{- if $listStarted }};{{ end }}tts_{{ $langRegion }}_{{ .name }}_22{{ if $voiceVersion }}-{{ $voiceVersion }}{{ end }}
{{- $listStarted = true }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- /* Renders "true" or nothing, so callers can use it directly in an if. */}}
{{- define "lumenvox-speech.CLUSTER_LANGUAGES__TTS_VOICES_ENABLED" }}
{{- range .Values.global.ttsLanguages }}
{{- if .legacyEnabled }}true{{- end }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.TTS_SETTINGS__SERVICE_VOICES" }}
{{- $listStarted := false }}
{{- $langRegion := .name }}
{{- range .voices }}
{{- if $listStarted }};{{ end }}tts_{{ $langRegion }}_{{ .name }}_22
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__NEURAL_TTS_LANGUAGES" }}
{{- $listStarted := false }}
{{- range .Values.global.ttsLanguages }}
{{- if $listStarted }};{{ end }}{{ .name | replace "_" "-" }}
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__NEURAL_TTS_VOICES" }}
{{- $listStarted := false }}
{{- $langRegion := "" }}
{{- range .Values.global.ttsLanguages }}
{{- $langRegion = .name }}
{{- range .voices }}
{{- if $listStarted }};{{ end }}neural_tts_{{ $langRegion }}_{{ .name }}
{{- $listStarted = true }}
{{- end }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__NEURAL_TTS_VOICES_VERSION" }}
{{- $listStarted := false }}
{{- $langRegion := "" }}
{{- $voiceVersion := "" }}
{{- range .Values.global.ttsLanguages }}
{{- if not .legacyEnabled }}
{{- $langRegion = .name }}
{{- range .voices }}
{{- $voiceVersion = .version | default $.Values.global.neuralttsDefaultVersion }}
{{- if $listStarted }};{{ end }}neural_tts_{{ $langRegion }}_{{ .name }}{{ if $voiceVersion }}-{{ $voiceVersion }}{{ end }}
{{- $listStarted = true }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- /* Renders "true" or nothing, so callers can use it directly in an if. */}}
{{- define "lumenvox-speech.CLUSTER_LANGUAGES__NEURAL_TTS_VOICES_ENABLED" }}
{{- range .Values.global.ttsLanguages }}
{{- if not .legacyEnabled }}true{{- end }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.NEURAL_TTS_SETTINGS__SERVICE_VOICES" }}
{{- $listStarted := false }}
{{- $langRegion := .name }}
{{- range .voices }}
{{- if $listStarted }};{{ end }}neural_tts_{{ $langRegion }}_{{ .name }}
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{- define "lumenvox-vb.CLUSTER_LANGUAGES__VB_ACTIVE" }}
{{- $listStarted := false }}
{{- range .Values.global.vbLanguages }}
{{- $vbVersion := .version | default $.Values.global.vbDefaultVersion }}
{{- if $listStarted }};{{ end }}vba_mvimp_{{ .name }}-{{ $vbVersion }}
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{/*
OpenTelemetry environment for application containers. Emits nothing unless
global.otel.enabled is true.

  {{- include "lumenvox-common.otelEnv" (dict "root" $ "service" "asr") | nindent 12 }}

"service" sets OTEL_SERVICE_NAME. NODE_IP must precede any $(NODE_IP) reference.
*/}}
{{- define "lumenvox-common.otelEnv" -}}
{{- $root := .root -}}
{{- $service := .service -}}
{{- $otel := default dict $root.Values.global.otel -}}
{{- if $otel.enabled -}}
{{- $ns := default $root.Release.Namespace $root.Values.global.defaultNamespace -}}
{{- $port := default 4317 $otel.port -}}
{{- $mode := default "agent" $otel.endpointMode -}}
{{- $traces := default dict $otel.traces -}}
{{- $metrics := default dict $otel.metrics -}}
{{- $logs := default dict $otel.logs -}}
{{- if eq $mode "agent" }}
- name: NODE_IP
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: 'http://$(NODE_IP):{{ $port }}'
{{- else }}
{{- /* Must match the collector chart's gateway naming. */}}
{{- $base := default (default $root.Release.Name $otel.releaseName) $otel.collectorName -}}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: '{{ default (printf "http://%s-gateway.%s:%v" $base $ns $port) $otel.gatewayEndpoint }}'
{{- end }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: '{{ default "grpc" $otel.protocol }}'
- name: OTEL_SERVICE_NAME
  value: '{{ $service }}'
- name: OTEL_RESOURCE_ATTRIBUTES
  value: '{{ template "lumenvox-common.otelResourceAttributes" (dict "root" $root) }}'
- name: OTEL_TRACES_SAMPLER
  value: '{{ default "parentbased_always_on" $traces.sampler }}'
{{- if $traces.samplerArg }}
- name: OTEL_TRACES_SAMPLER_ARG
  value: '{{ $traces.samplerArg }}'
{{- end }}
{{- /* dig, not default: default treats an explicit false as unset. */}}
- name: OTEL_TRACES_EXPORTER
  value: '{{ if dig "enabled" true $traces }}otlp{{ else }}none{{ end }}'
- name: OTEL_METRICS_EXPORTER
  value: '{{ if dig "enabled" true $metrics }}otlp{{ else }}none{{ end }}'
- name: OTEL_LOGS_EXPORTER
  value: '{{ if dig "enabled" false $logs }}otlp{{ else }}none{{ end }}'
{{- range $k, $v := $otel.extraEnv }}
- name: {{ $k }}
  value: '{{ $v }}'
{{- end }}
{{- end }}
{{- end }}

{{/*
OTEL_RESOURCE_ATTRIBUTES value. k8s.* attributes are added by the collector.
*/}}
{{- define "lumenvox-common.otelResourceAttributes" -}}
{{- $root := .root -}}
{{- $otel := default dict $root.Values.global.otel -}}
{{- $attrs := list -}}
{{- $attrs = append $attrs (printf "service.namespace=%s" (default "lumenvox" $otel.serviceNamespace)) -}}
{{- if $otel.environment -}}
{{- $attrs = append $attrs (printf "deployment.environment=%s" $otel.environment) -}}
{{- end -}}
{{- with $root.Values.global.licensing -}}
{{- if .clusterGuid -}}
{{- $attrs = append $attrs (printf "lumenvox.cluster.guid=%s" .clusterGuid) -}}
{{- end -}}
{{- end -}}
{{- range $k, $v := $otel.resourceAttributes -}}
{{- $attrs = append $attrs (printf "%s=%s" $k $v) -}}
{{- end -}}
{{- join "," $attrs -}}
{{- end }}
