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
  | toJson }}
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
