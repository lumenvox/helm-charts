# lumenvox-otel-collector

OpenTelemetry Collector for the LumenVox platform, in two tiers.

| Tier | Workload | Role |
|---|---|---|
| `agent` | DaemonSet, one per node | Receives OTLP on a hostPort (`$(NODE_IP):4317`). Optionally collects pod stdout logs and scrapes Prometheus-annotated pods. Reads kubelet stats. Forwards to the gateway. |
| `gateway` | Deployment, single replica | Tail sampling, cluster-level metrics, export to the backend. |

The pinned collector image is `otel/opentelemetry-collector-contrib:0.115.1`. Receiver
configuration changes between contrib versions; validate the rendered config with
`otelcol-contrib validate` before changing `image.tag`.

## Installing

The chart is published to the LumenVox chart repository at version 8.1.0 and installed as
a subchart of the `lumenvox` umbrella chart, gated on `global.enabled.otelCollector`. This
is independent of `global.otel.enabled`, which configures the services to export. Install
the collector first, confirm it is healthy, then enable export:

```yaml
global:
  enabled:
    otelCollector: true
  otel:
    enabled: true
    endpointMode: agent
```

With `global.otel.enabled: false` no `OTEL_*` environment is added to the services.

## Constraints

### Single gateway replica

`tail_sampling` requires every span of a trace to reach the same collector instance. Keep
`gateway.replicaCount: 1`; more replicas produce sampling decisions on partial traces.

### `decisionWait`

`gateway.tailSampling.decisionWait` (default `15s`) is how long a trace is held before the
sampling decision. A trace still open after that window is decided on the spans received
so far, so long sessions may be sampled on their opening spans only
(`otelcol_processor_tail_sampling_sampling_trace_dropped_too_early` counts these).

When Tempo's metrics-generator is used, keep `decisionWait` at or below about 25s. Tempo
discards spans older than `metrics_ingestion_time_range_slack` (30s, not settable through
the `grafana/tempo` chart); above that, trace search still works but TraceQL metrics and
Grafana Traces Drilldown return no data.

### Sampling

Sampling is applied by the gateway. Keep `global.otel.traces.sampler` at its default,
`parentbased_always_on`; a probabilistic SDK sampler decides at the root span and cannot
retain all error traces.

### Istio

With `global.serviceMesh.type: istio` and `endpointMode: agent`, Envoy captures traffic to
`$(NODE_IP):4317` and drops it. Exclude the port:

```yaml
global:
  serviceMesh:
    istio:
      excludeOutboundPorts: "443,4317"
```

Changing this annotation restarts every pod. Apply it in the same upgrade that sets
`global.otel.enabled: true`.

Alternatively, `endpointMode: gateway` sends directly to the gateway's ClusterIP Service
and needs no exclusion, but bypasses the node-local agent. This requires PERMISSIVE mTLS
(the Istio default); under a `STRICT` PeerAuthentication, the collector port needs an
exemption.

The collector pods are not meshed (`linkerd.io/inject: disabled`,
`sidecar.istio.io/inject: "false"`).

### Prometheus scrape bridge

`agent.prometheusScrape` scrapes pods annotated `prometheus.io/scrape` on the agent's node
and forwards the metrics through the gateway. Disable it
(`agent.prometheusScrape.enabled: false`) if the cluster already runs a Prometheus with the
standard `kubernetes-pods` job; otherwise the same metrics are collected twice.

### Buffering

The agent's sending queue is in memory. It survives a gateway restart but not an agent
restart.

### Not supported

- OTLP log export from the services. Keep `global.otel.logs.enabled: false` and collect
  logs with `agent.filelog`.
- `gateway.infraReceivers` (Redis, PostgreSQL, MongoDB) are off by default. RabbitMQ has no
  receiver; it is scraped through its `prometheus.io/scrape` annotations.

## Collecting service logs from stdout

`agent.filelog.enabled: true` reads pod log files from `/var/log/pods` on each node and
sends them to the gateway's logs destination. JSON lines are parsed for `time`, `level`,
`trace.id`, `span.id` and `service.name`; the original line is kept as the body.

```yaml
lumenvox-otel-collector:
  agent:
    filelog:
      enabled: true
      minLevel: INFO        # "" keeps everything
  gateway:
    backend: split
    split:
      logs:
        endpoint: "http://loki.monitoring.svc.cluster.local:3100/otlp"
        type: otlphttp
```

- `global.otel.logs.enabled` must be `false`; the render fails otherwise. Stop any other
  log agent shipping the same namespaces to the same backend to avoid duplicates.
- Collected namespaces default to the release namespace; add others with
  `agent.filelog.namespaces`. Containers listed in `agent.filelog.excludeContainers` are
  skipped.
- The agent runs as root while filelog is enabled, mounts `/var/log/pods` read-only, and
  stores read offsets in a hostPath (`agent.filelog.checkpointPath`).
- In Loki, `service_name`, `k8s_namespace_name`, `k8s_pod_name` and `k8s_container_name`
  are labels and the trace ID is `trace_id` structured metadata:
  `{service_name="session"} | trace_id="<id>"`.

## Backends

`gateway.backend` accepts `datadog`, `otlp` or `split`; any other value fails the render.

- `otlp`: one OTLP destination (`gateway.otlp.endpoint`) for all signals.
- `datadog`: one Datadog destination. The API key must come from a Secret exposing
  `DD_API_KEY`, referenced by `gateway.datadog.existingSecret`.
- `split`: a separate destination per signal under `gateway.split.{traces,metrics,logs}`,
  each with its own `type` (`otlp`, `otlphttp` or `splunk_hec`). A signal with an empty
  endpoint has no pipeline. The older `protocol` field is still accepted (`grpc` maps to
  `otlp`, `http` to `otlphttp`).

| Backend | Configuration |
|---|---|
| Any OTLP backend (New Relic, Honeycomb, Elastic, Dynatrace, ...) | `backend: otlp`, or `split` with `type: otlp` / `otlphttp` |
| Grafana stack (Tempo / Prometheus / Loki) | `split`, one type per signal |
| Splunk Observability Cloud | `split` with `type: otlphttp` to the realm endpoint, token in `headers` |
| Splunk Enterprise / Cloud (HEC) | `split` with `type: splunk_hec` |
| Datadog | `backend: datadog` + `DD_API_KEY` Secret |

### Splunk

Signals can use different exporter types, for example Observability Cloud for traces and
metrics with HEC for logs:

```yaml
split:
  traces:  { type: otlphttp,   endpoint: "https://ingest.<realm>.signalfx.com/v2/trace/otlp" }
  metrics: { type: otlphttp,   endpoint: "https://ingest.<realm>.signalfx.com/v2/datapoint/otlp" }
  logs:    { type: splunk_hec, endpoint: "https://splunk:8088/services/collector" }
```

The HEC token is read from the environment. Mount a Secret exposing it with
`gateway.extraEnvFromSecrets`; the render fails if `splunk_hec` is selected without one.
See [examples/splunk-values.yaml](examples/splunk-values.yaml).

### Grafana stack

See [examples/grafana-stack-values.yaml](examples/grafana-stack-values.yaml). The
`otlphttp` exporter appends `/v1/<signal>` to the endpoint:

| Backend | Type | Endpoint | Receives at |
|---|---|---|---|
| Tempo | `otlp` | `tempo.monitoring:4317` | — |
| Prometheus | `otlphttp` | `http://prometheus-server.monitoring:80/api/v1/otlp` | `/api/v1/otlp/v1/metrics` |
| Loki | `otlphttp` | `http://loki.monitoring:3100/otlp` | `/otlp/v1/logs` |

Prometheus must be started with `--web.enable-otlp-receiver`
([examples/backends/prometheus-otlp-receiver.yaml](examples/backends/prometheus-otlp-receiver.yaml)).
Leave `gateway.split.metrics.endpoint` empty until it is.

Tempo is installed separately:

```bash
helm upgrade --install tempo grafana/tempo -n monitoring
```

The `grafana/tempo` chart is deprecated (use `grafana/tempo-distributed` for production),
stores traces on the container filesystem by default, and retains them for 24h. For
persistent storage see
[examples/backends/tempo-persistence.yaml](examples/backends/tempo-persistence.yaml); for
TraceQL metrics see
[examples/backends/tempo-traceql-metrics.yaml](examples/backends/tempo-traceql-metrics.yaml).

### Derived metrics

Two connectors generate metrics from spans. Both are off by default and require a metrics
destination; the render fails without one.

- `gateway.spanMetrics`: request rate, errors and duration per service and span name.
- `gateway.serviceGraph`: metrics for calls between pairs of services, used by Grafana's
  Service Graph.

Both are computed from all spans before tail sampling, so rates are not affected by the
sampling percentage.

Do not add per-request attributes (`sessionId`, `interactionId`, `correlationId`) to
`gateway.spanMetrics.dimensions`; each distinct value creates a Prometheus series.

The metrics are `lumenvox_spanmetrics_calls_total`,
`lumenvox_spanmetrics_duration_milliseconds_*` and `traces_service_graph_request_*`,
labelled `service_name`, `span_name` and `status_code`.
[examples/backends/grafana-tempo-datasource.yaml](examples/backends/grafana-tempo-datasource.yaml)
configures the Grafana Tempo datasource for the service map, span-to-metrics,
span-to-logs, log-to-trace and exemplar links. Exemplars require Prometheus started with
`--enable-feature=exemplar-storage`.

> **Data handling:** telemetry can carry transcripts, audio metadata and per-tenant
> identifiers, more so at debug verbosity. Confirm the destination is approved for that
> data before exporting to a third-party backend.

## Troubleshooting

With `selfTelemetry.enabled: true` (default), the collector exposes its own metrics on
`:8888` with `prometheus.io/*` annotations for an annotation-scraping Prometheus. These
series appear only after the first span is observed.

| Question | Metric |
|---|---|
| Received? | `otelcol_receiver_accepted_spans` |
| Rejected on arrival? | `otelcol_receiver_refused_spans` |
| Sampled? | `otelcol_processor_tail_sampling_count_traces_sampled` |
| Exported? | `otelcol_exporter_sent_spans` |
| Export failed? | `otelcol_exporter_send_failed_spans` |
| Queue backing up? | `otelcol_exporter_queue_size` vs `otelcol_exporter_queue_capacity` |
| Processor dropping data? | `otelcol_processor_incoming_items` vs `otelcol_processor_outgoing_items` |
| Evicted before a sampling decision? | `otelcol_processor_tail_sampling_sampling_trace_dropped_too_early` |

- Agent `accepted_spans` at zero: the service is not exporting, or Envoy is capturing the
  traffic (see Istio).
- Agent `sent_spans` rising, gateway `accepted_spans` flat: check the agent's
  `send_failed_spans` and logs.
- `accepted_spans` healthy but few traces in the backend: compare `count_traces_sampled`;
  at `gateway.tailSampling.baselinePercentage: 10` most non-error traces are not
  retained.
- `dropped_too_early` non-zero: sessions outlast `decisionWait`.

`selfTelemetry.level: detailed` adds per-processor histograms. Set
`selfTelemetry.prometheusAnnotations: false` if no annotation-scraping Prometheus exists.

## Values

See [values.yaml](values.yaml). Commonly changed: `gateway.backend`,
`gateway.otlp.endpoint`, `gateway.datadog.existingSecret`, `gateway.split.*`,
`gateway.tailSampling.*`, `agent.filelog.*` and `agent.resources`.
