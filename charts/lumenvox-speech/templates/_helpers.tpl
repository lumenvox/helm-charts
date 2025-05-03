{{- define "lumenvox-speech.CLUSTER_LANGUAGES__ASR_LANGUAGES_VERSION" }}
{{- $listStarted := false }}
{{- range .Values.global.asrLanguages }}
{{- if $listStarted }};{{ end }}{{ .name }}{{ if .version }}-{{ .version }}{{ end }}{{ if .enableFineTuned }};asr_finetuned_model_{{ .name }}{{ end }}
{{- $listStarted = true }}
{{- end }}
{{- range .Values.global.customAsrModels }}
{{- if $listStarted }};{{ end }}{{ .name }}{{ if .version }}-{{ .version }}{{ end }}
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__ASR_LANGUAGES" }}
{{- $listStarted := false }}
{{- range .Values.global.asrLanguages }}
{{- if $listStarted }};{{ end }}{{ .name }}
{{- $listStarted = true }}
{{- end }}
{{- end }}

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__DNN_MODULES" }}
{{- $fineTunedEnabled := false }}
{{- $nluEnabled := false }}
{{- if .Values.global.enableNlu }}{{ $nluEnabled = true }}{{ end }}
{{- range .Values.global.asrLanguages }}
{{- if .enableFineTuned }}{{ $fineTunedEnabled = true }}{{ end }}
{{- end }}backend_dnn_model_p;dist_package_model_en{{ if $fineTunedEnabled }};dist_package_model_finetuned{{ end }}
{{- if $nluEnabled }};dist_package_model_nlu{{ end }}
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

{{- define "lumenvox-speech.CLUSTER_LANGUAGES__TTS_VOICES_VERSION" }}
{{- $listStarted := false }}
{{- $langRegion := "" }}
{{- $voiceVersion := "" }}
{{- range .Values.global.ttsLanguages }}
{{- $langRegion = .name }}
{{- range .voices }}
{{- $voiceVersion = .version | default $.Values.global.ttsDefaultVersion }}
{{- if $listStarted }};{{ end }}tts_{{ $langRegion }}_{{ .name }}_22{{ if $voiceVersion }}-{{ $voiceVersion }}{{ end }}
{{- $listStarted = true }}
{{- end }}
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
{{- $langRegion = .name }}
{{- range .voices }}
{{- $voiceVersion = .version | default $.Values.global.ttsDefaultVersion }}
{{- if $listStarted }};{{ end }}neural_tts_{{ $langRegion }}_{{ .name }}{{ if $voiceVersion }}-{{ $voiceVersion }}{{ end }}
{{- $listStarted = true }}
{{- end }}
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