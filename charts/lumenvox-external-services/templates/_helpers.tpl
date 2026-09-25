{{/*
Standard labels
*/}}
{{- define "lumenvox-external-services.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Convert a Kubernetes quantity (512Mi, 5Gi, 1G, 100M, or plain bytes) to an
integer byte count.

Used to derive redis `maxmemory` from the container memory limit so the two can
never drift apart. Redis accepts a raw byte count, which avoids any unit-syntax
mismatch between Kubernetes (Mi/Gi = binary) and redis.conf (mb/gb = decimal,
MB/GB = binary) -- a distinction that is easy to get wrong by hand.

Usage: {{ include "lumenvox-external-services.toBytes" "512Mi" }}
*/}}
{{- define "lumenvox-external-services.toBytes" -}}
{{- $q := . | toString | trim -}}
{{- if hasSuffix "Ki" $q -}}
{{- mulf (trimSuffix "Ki" $q | float64) 1024 | int64 -}}
{{- else if hasSuffix "Mi" $q -}}
{{- mulf (trimSuffix "Mi" $q | float64) 1048576 | int64 -}}
{{- else if hasSuffix "Gi" $q -}}
{{- mulf (trimSuffix "Gi" $q | float64) 1073741824 | int64 -}}
{{- else if hasSuffix "Ti" $q -}}
{{- mulf (trimSuffix "Ti" $q | float64) 1099511627776 | int64 -}}
{{- else if hasSuffix "k" $q -}}
{{- mulf (trimSuffix "k" $q | float64) 1000 | int64 -}}
{{- else if hasSuffix "M" $q -}}
{{- mulf (trimSuffix "M" $q | float64) 1000000 | int64 -}}
{{- else if hasSuffix "G" $q -}}
{{- mulf (trimSuffix "G" $q | float64) 1000000000 | int64 -}}
{{- else if hasSuffix "T" $q -}}
{{- mulf (trimSuffix "T" $q | float64) 1000000000000 | int64 -}}
{{- else -}}
{{- $q | float64 | int64 -}}
{{- end -}}
{{- end }}

{{/*
Derive redis `maxmemory` (in bytes) as a percentage of a memory limit.

Without maxmemory set, redis has no boundary to respect: it allocates past the
container limit and the kernel OOM-kills it instead of the configured eviction
policy running. For a cluster leader that is a shard failover, which surfaces to
every client as MOVED/CLUSTERDOWN. Deriving it from the limit means the two
cannot drift when someone resizes the pod.

Usage: {{ include "lumenvox-external-services.maxmemory" (dict "limit" "512Mi" "percent" 75) }}
*/}}
{{- define "lumenvox-external-services.maxmemory" -}}
{{- $bytes := include "lumenvox-external-services.toBytes" .limit | float64 -}}
{{- mulf $bytes (divf (.percent | float64) 100.0) | int64 -}}
{{- end }}

{{/*
Derive an Erlang scheduler count from a Kubernetes CPU quantity ("2", "500m").

The Erlang VM sizes its scheduler pool from the number of online HOST CPUs and
ignores the cgroup CPU quota, so a pod limited to 1 core on a 16-core node
still starts 16 schedulers that then contend for that single slice. Deriving
the count from the limit keeps the two in step automatically, so resizing the
pod cannot leave a stale +S behind.

Rounds up and never returns less than 1 (a sub-core limit still needs one
scheduler to run at all).

Usage: {{ include "lumenvox-external-services.schedulers" "2" }}
*/}}
{{- define "lumenvox-external-services.schedulers" -}}
{{- $c := . | toString | trim -}}
{{- $cores := 0.0 -}}
{{- if hasSuffix "m" $c -}}
{{- $cores = divf (trimSuffix "m" $c | float64) 1000.0 -}}
{{- else -}}
{{- $cores = $c | float64 -}}
{{- end -}}
{{- max 1 (ceil $cores | int64) -}}
{{- end }}

{{/*
Shared pod scheduling block: nodeSelector, tolerations, affinity,
topologySpreadConstraints, priorityClassName.

Kept in one place because all four services need the identical treatment: in
the managed-service topology these databases were off-cluster with no
contention, so nothing stopped them from being scheduled onto a node that is
already running decode pods at its packing target.

Usage (from a pod spec, at the right indentation):
  {{- include "lumenvox-external-services.scheduling" .Values.postgresql | nindent 6 }}
*/}}
{{- define "lumenvox-external-services.scheduling" -}}
{{- with .nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- end }}

{{/*
Shared pod annotations: service-mesh handling (unchanged behaviour) plus a
per-service passthrough.

The passthrough exists mainly for cluster-autoscaler and Karpenter hints --
without `karpenter.sh/do-not-disrupt`, routine consolidation will drain the node
holding a single-replica database mid-test.

Usage: {{- include "lumenvox-external-services.podAnnotations" (dict "svc" .Values.postgresql "root" . "ports" "5432") | nindent 6 }}
*/}}
{{- define "lumenvox-external-services.podAnnotations" -}}
{{- $root := .root -}}
{{- /* Assembled as a map and serialised once, rather than emitted line by
       line: hand-written lines have to get their own leading newlines right,
       and a missing one silently concatenates two annotations into a single
       invalid key. */ -}}
{{- $a := dict -}}
{{- if $root.Values.linkerd.enabled -}}
{{- $_ := set $a "config.linkerd.io/opaque-ports" (.ports | toString) -}}
{{- end -}}
{{- if not $root.Values.global.serviceMesh.istio.injectDatabaseSidecars -}}
{{- $_ := set $a "sidecar.istio.io/inject" "false" -}}
{{- end -}}
{{- with .svc.podAnnotations -}}
{{- $a = mergeOverwrite $a (deepCopy .) -}}
{{- end -}}
{{- if $a -}}
{{- toYaml $a -}}
{{- end -}}
{{- end }}
