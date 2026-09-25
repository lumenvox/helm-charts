# LumenVox Helm Chart

The LumenVox Helm chart provides a complete deployment solution for LumenVox's speech recognition, text-to-speech, and voice biometrics services on Kubernetes. This parent chart orchestrates the installation of multiple subcharts to deliver a full-featured voice processing platform.

## Overview

This chart primarily deploys the **LumenVox Speech** stack, which includes:
- Automatic Speech Recognition (ASR)
- Text-to-Speech (TTS)
- Inverse Text Normalization (ITN)
- Natural Language Understanding (NLU)
- Diarization
- Language Identification (LID)
- Neuron services

The chart also includes common infrastructure services such as licensing, configuration management, resource management, and administrative portals.

**Voice Biometrics Note**: The chart includes a legacy voice biometrics subchart (`lumenvox-vb`) that is not actively maintained. Voice Biometrics functionality is currently not supported for new deployments. If you have specific Voice Biometrics requirements, please contact LumenVox to discuss your needs.

## Prerequisites

- Kubernetes 1.35 or compatible version
- Helm 3+
- A valid LumenVox license (contact LumenVox for licensing information)
- External dependencies (or use the included test dependencies):
  - PostgreSQL database
  - MongoDB database
  - Redis cache
  - RabbitMQ message broker
- A service mesh is recommended for production deployments (Linkerd or Istio)

## Quick Start

1. Add the LumenVox Helm repository:

```shell
helm repo add lumenvox https://lumenvox.github.io/helm-charts
helm repo update
```

2. Create a values file with your configuration (see Configuration section below)

3. Install the chart:

```shell
helm install lumenvox lumenvox/lumenvox -f my-values.yaml -n lumenvox --create-namespace
```

## Architecture

The LumenVox chart is composed of three main subcharts:

- **lumenvox-common**: Core infrastructure services including deployment portal, configuration management, license management, and resource management
- **lumenvox-speech**: Speech services including ASR, TTS, ITN, and optional NLU, Diarization, LID, and Neuron
- **lumenvox-vb**: Voice Biometrics subchart (not actively maintained; contact LumenVox for Voice Biometrics requirements)

For typical deployments, enable `lumenvoxSpeech` along with `lumenvoxCommon`.

# Configuration

## General Configuration

| Parameter                                          | Description                                                         | Default                            |
|----------------------------------------------------|---------------------------------------------------------------------|------------------------------------|
| `timezone`                                         | Timezone for logs. Examples: UTC, America/New_York, Europe/Rome     | `UTC`                              |
| `global.licensing.clusterGuid`                     | License GUID obtained from LumenVox account                         | `"GET-CLUSTER-GUID-FROM-LUMENVOX"` |
| `global.hostnameSuffix`                            | Desired ingress suffix (include leading dot)                        | `".testmachine.com"`               |
| `global.lumenvox.ingress.className`                | Ingress class name; `"istio"` selects Gateway API mode              | `nginx`                            |
| `global.lumenvox.deploymentReconnectionTimeoutSec` | Deployment database connection timeout                              | `30`                               |
| `global.lumenvox.enableAudit`                      | Whether to enable audit logging                                     | `false`                            |
| `global.lumenvox.enforceLimits`                    | Whether to enforce resource limits                                  | `false`                            |
| `global.lumenvox.enforceReservations`              | Whether to enforce resource reservations (required for autoscaling) | `false`                            |
| `global.lumenvox.loggingVerbosity`                 | Cluster-level logging verbosity (debug, info, warn, error, etc.)    | `info`                             |
| `global.image.pullPolicy`                          | Pull policy when installing cluster                                 | `IfNotPresent`                     |
| `global.image.tag`                                 | Default image tag                                                   | `":8.0"`                           |

## Persistent Volume Configuration

| Parameter      | Description                                                                                                                 | Default    |
|----------------|-----------------------------------------------------------------------------------------------------------------------------|------------|
| `platform`     | Cluster platform: `cloud` or `minikube`. Used for persistent volume setup and resource sizing.                              | `minikube` |
| `provider`     | Platform provider: used for provider-specific optimizations. Currently only used for AWS EFS; specify `"aws"` in this case. | `""`       |
| `volumeRoot`   | Root of persistent data location. To specify the root of the file system, use `"/."`                                        | `"/data"`  |
| `volumeServer` | IP address of persistent data filesystem. Ignored for minikube.                                                             | `""`       |
| `directorySetup.runOnUpgrade` | Also run the storage directory setup job (`speech_dirs`) before each upgrade. It always runs after a fresh install. Helm waits for it, and it rewrites ownership and mode of every file on the volume, which can take 30+ minutes on NFS/EFS; enable it for one upgrade to repair ownership. | `false` |

Depending on the location of your cluster, the configuration for persistent volumes will differ:

- **Local/Minikube**: The defaults should suffice; they will map persistent volumes to directories under `/data`. To change the root location, set the `volumeRoot` value.
- **Cloud**: Set `volumeServer` to the IP address of your NFS server, set `platform` to `"cloud"`, and set `volumeRoot` to the appropriate root location.
- **AWS EFS**: Additionally set `provider` to `"aws"` for AWS-specific optimizations.

## Product Selection

| Parameter                       | Description                                                                   | Default |
|---------------------------------|-------------------------------------------------------------------------------|---------|
| `global.enabled.lumenvoxSpeech` | If `true`, enable LumenVox Speech stack                                       | `false` |
| `global.enabled.lumenvoxVb`     | If `true`, enable LumenVox Voice Biometrics (legacy, not actively maintained) | `false` |
| `global.enabled.lumenvoxCommon` | If `true`, enable common infrastructure                                       | `true`  |

**Typical Configuration**: Enable `lumenvoxSpeech` along with `lumenvoxCommon` for a standard deployment.

> **Note**: The Voice Biometrics subchart is not actively maintained and is not recommended for new deployments. Contact LumenVox if you have Voice Biometrics requirements.

## Feature Toggles

| Parameter                  | Description                                                                       | Default |
|----------------------------|-----------------------------------------------------------------------------------|---------|
| `global.enableNlu`         | Enable Natural Language Understanding service                                     | `false` |
| `global.enableDiarization` | Enable speaker diarization service                                                | `false` |
| `global.enableLanguageId`  | Enable language identification (LID) service                                      | `false` |
| `global.enableNeuron`      | Enable Neuron service                                                             | `false` |
| `global.enableFilestore`   | Enable Filestore service and deployment portal integration                        | `true`  |
| `global.minimalInstall`    | If `true`, install only CPA interactions (ASR and TTS services will not install)  | `false` |

## External Dependencies

The chart requires four external services: RabbitMQ, Redis, MongoDB, and PostgreSQL. Provide them yourself, or for testing and development run them in the cluster with the `lumenvox-external-services` subchart.

### Test/Development Setup

For non-production testing and development environments, the [`lumenvox-external-services`](../lumenvox-external-services) subchart runs these dependencies inside the cluster. Set `global.enabled.externalServices: true` after creating the four secrets listed in its README.

It includes:
- MongoDB 8.2
- PostgreSQL 17.5
- RabbitMQ 4.1.8 (with management interface)
- Redis 8.2.4

> **Important**: The subchart's defaults are sized **for testing/development only**. For production, use managed cloud services or self-hosted instances configured for high availability, persistence, and scale.

### RabbitMQ Configuration

| Parameter                         | Description                  | Default                                 |
|-----------------------------------|------------------------------|-----------------------------------------|
| `global.rabbitmq.enableTLS`       | Connect to RabbitMQ with TLS | `false`                                 |
| `global.rabbitmq.connection.url`  | URL for RabbitMQ connection  | `"external-services-rabbitmq.lumenvox"` |
| `global.rabbitmq.connection.port` | Port for RabbitMQ connection | `5672`                                  |
| `global.rabbitmq.connection.user` | User for RabbitMQ connection | `"lvuser"`                              |

The installation expects an existing Kubernetes secret named `rabbitmq-existing-secret` with one field:
- `rabbitmq-password`: The password for the RabbitMQ user

**TLS Configuration**: When `enableTLS` is true, provide base64-encoded certificates:
- `global.rabbitmq.caCertificate`: CA certificate
- `global.rabbitmq.clientCertificate`: Client certificate
- `global.rabbitmq.clientKey`: Client private key

### Redis Configuration

| Parameter                      | Description                               | Default                                     |
|--------------------------------|-------------------------------------------|---------------------------------------------|
| `global.redis.enableTLS`       | Connect to Redis with TLS                 | `false`                                     |
| `global.redis.connection.url`  | URL for Redis connection                  | `"external-services-redis-master.lumenvox"` |
| `global.redis.connection.port` | Port for Redis connection                 | `6379`                                      |
| `global.lumenvox.redisTtl`     | Time to live for certain objects in Redis | `3h`                                        |

Valid time units for `redisTtl`: "ns", "us" (or "µs"), "ms", "s", "m", "h", "d", "w", "y". Examples: "300ms", "-1.5h", "2h45m"

The installation expects an existing Kubernetes secret named `redis-existing-secret` with one field:
- `redis-password`: The password for the Redis instance

### MongoDB Configuration

| Parameter                        | Description                      | Default                                |
|----------------------------------|----------------------------------|----------------------------------------|
| `global.mongodb.connection.url`  | URL for MongoDB connection       | `"external-services-mongodb.lumenvox"` |
| `global.mongodb.connection.port` | Port for MongoDB connection      | `27017`                                |
| `global.mongodb.auth.rootUser`   | MongoDB root username            | `"lvuser"`                             |
| `global.mongodb.atlas`           | Enable for MongoDB Atlas support | `false`                                |

The installation expects an existing Kubernetes secret named `mongodb-existing-secret` with one field:
- `mongodb-root-password`: The MongoDB root password

### PostgreSQL Configuration

| Parameter                                        | Description                                      | Default                                   |
|--------------------------------------------------|--------------------------------------------------|-------------------------------------------|
| `global.postgresql.connection.url`               | URL for PostgreSQL connection                    | `"external-services-postgresql.lumenvox"` |
| `global.postgresql.connection.port`              | Port for PostgreSQL connection                   | `5432`                                    |
| `global.postgresql.connection.user`              | User for PostgreSQL connection                   | `"lvuser"`                                |
| `global.postgresql.connection.databaseName`      | Database name                                    | `"lumenvox_db"`                           |
| `global.postgresql.connection.databaseSchema`    | Database schema name                             | `"public"`                                |
| `global.postgresql.connection.ssl.mode`          | SSL Connection Mode: `disable` or `verify-ca`    | `"disable"`                               |
| `global.postgresql.connection.ssl.caCertificate` | CA certificate to verify server (base64-encoded) | `""`                                      |
| `global.postgresql.runMigrations`                | Run database migrations on deployment            | `"true"`                                  |
| `global.postgresql.exitAfterMigrations`          | Exit after migrations complete                   | `"false"`                                 |
| `global.postgresql.commandTimeoutSeconds`        | Command timeout in seconds                       | `100`                                     |

The installation expects an existing Kubernetes secret named `postgres-existing-secret` with two fields:
- `postgresql-password`: The password for the database user
- `postgresql-postgres-password`: The password for the postgres root user

**TLS Configuration**: To enable TLS, set `global.postgresql.connection.ssl.mode` to `verify-ca`. This causes the client to verify the certificate returned by the PostgreSQL server.

For self-signed certificates, base64-encode the signing CA certificate and store it in `global.postgresql.connection.ssl.caCertificate`:

```shell
base64 -w 0 ca.crt
```

## Service Mesh Configuration

A service mesh provides critical load-balancing and traffic management functionality for LumenVox services. While the chart can operate without a service mesh, it is **strongly recommended for production deployments** to ensure proper scaling and reliability.

| Parameter                                       | Description                                                        | Default     |
|-------------------------------------------------|--------------------------------------------------------------------|-------------|
| `global.serviceMesh.type`                       | Service mesh type: `linkerd`, `istio`, or `""` (none)              | `"linkerd"` |
| `global.serviceMesh.linkerd.ingressMode`        | Linkerd ingress mode: `nginx` or `traefik`                         | `"nginx"`   |
| `global.serviceMesh.istio.passThrough`          | Enable Istio passthrough mode                                      | `true`      |
| `global.serviceMesh.istio.excludeOutboundPorts` | Ports to exclude from Istio interception                           | `"443"`     |
| `global.linkerd.enabled`                        | Legacy linkerd toggle (deprecated, use `serviceMesh.type` instead) | `true`      |

### Linkerd Configuration

[Linkerd](https://linkerd.io/) is the default and recommended service mesh for LumenVox deployments. Linkerd must be installed separately before deploying the LumenVox chart.

**Installation Requirements:**
- Linkerd 2.12 or later must be installed in the cluster
- Linkerd may require certificate management (handled by Kubernetes administrators)

When `serviceMesh.type` is set to `"linkerd"`, the chart automatically configures pods to inject the Linkerd proxy container. The `ingressMode` setting controls how ingress resources interact with Linkerd:
- `nginx`: Uses `linkerd.io/inject: enabled` annotation
- `traefik`: Uses `linkerd.io/inject: ingress` annotation

### Istio Configuration

LumenVox also supports [Istio](https://istio.io/) as an alternative service mesh. To use Istio:

```yaml
global:
  serviceMesh:
    type: "istio"
    istio:
      passThrough: true
      externalServices:
        - assets.lumenvox.com
        - license.lumenvox.com
      excludeOutboundPorts: "443"
```

**Istio Configuration Options:**
- `externalServices`: List of external HTTPS endpoints requiring ServiceEntry resources
- `excludeOutboundPorts`: Ports to exclude from Istio interception (default `"443"` allows direct HTTPS without ServiceEntry)

### Running Without a Service Mesh

If you need to run without a service mesh (e.g., for testing):

```yaml
global:
  serviceMesh:
    type: ""
```

> **Warning**: Without a service mesh, load-balancing across service replicas will not function properly. This configuration is only suitable for test environments where a single pod of each service type is deployed. **Production deployments must use a service mesh.**

## Trusted Root CA Configuration

| Parameter                  | Description                                 | Default |
|----------------------------|---------------------------------------------|---------|
| `global.extraRootCaCerts`  | If `true`, read extra root CAs from secret  | `false` |

When receiving a grammar referenced via URL, the Grammar Manager will fetch from the specified URL. To support fetching from servers signed with custom certificate authorities, you can add a set of extra root CAs to trust.

To use this feature:

1. Create a file containing the set of root CA certificates (`extra_cas.pem`):

```text
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
```

2. Create a Kubernetes secret from this file:

```shell
kubectl create secret generic extra-root-ca-secret -n lumenvox --from-file=extra-root-ca-certs=./extra_cas.pem
```

3. Enable the feature in your values:

```yaml
global:
  extraRootCaCerts: true
```

## Language and Model Configuration

### ASR (Automatic Speech Recognition)

| Parameter                             | Description                                             | Default   |
|----------------------------------------|---------------------------------------------------------|-----------|
| `global.asrLanguages`                  | List of ASR languages to install                        | `[]`      |
| `global.asrDefaultVersion`             | Default ASR model version                                | `"8.0.0"` |
| `global.customAsrModels`               | Shared, non-per-language ASR download packages           | `[]`      |
| `global.gpu`                           | Chart-wide default GPU sizing per speech service (see [GPU](#gpu)) | see below |
| `global.asr.enabled`, `global.transcribeRealtime.enabled`, `global.transcribeBatch.enabled` | Deploy that service for every `asrLanguages` entry | `true` |
| `lumenvox-speech.asr.cacheMaxEntries`  | Maximum cache entries                                    | `500`     |
| `lumenvox-speech.asr.cacheMaxSizeMb`   | Maximum cache size in MB                                 | `1000`    |

To specify ASR languages, list your desired languages under `global.asrLanguages`. Each item must include a `name`; the `version` is optional and defaults to `asrDefaultVersion`. Everything else about a language — GPU use, which services load which models — lives nested inside that same entry rather than in a separate list.

**Example:**

```yaml
global:
  asrDefaultVersion: "8.0.0"
  asrLanguages:
    - name: "en"
      version: "8.0.0"
    - name: "es"
      version: "8.0.0"
    - name: "fr"  # Uses default version
```

**Shared ASR download packages:**

```yaml
global:
  customAsrModels:
    - name: "custom1"
      version: "1.0.0"
    - name: "custom2"
```

`global.customAsrModels` is for packages that aren't tied to any one language and are download-only (e.g. `dist_package_model_asr`, `backend_dnn_model_p`). A model that a *specific language* should load belongs under that language's `asrLanguages[].extraModels` instead — see below.

**ASR Cache**: The ASR service uses a cache to speed up processing of frequently used grammars. Configure the cache size with `cacheMaxEntries` and `cacheMaxSizeMb`.

**Per-service model loading (ASR_ENCODERS/ASR_DECODERS):** The `asr`, `transcribe-realtime`, and `transcribe-batch` services each load only the encoder/decoder models listed in their own mandatory env var (`ASR_ENCODERS`/`ASR_DECODERS`, `TRANS_RT_ENCODERS`/`TRANS_RT_DECODERS`, `TRANS_BATCH_ENCODERS`/`TRANS_BATCH_DECODERS`) instead of glob-loading every model under `/EuropaAsrModels`. The chart builds these automatically per language and per service:

- The base (suffix-less) model for a language — e.g. `asr_encoder_model_en` / `asr_decoder_model_en` — is loaded by every service unless narrowed. `asrLanguages[].services.<service>.base: false` excludes the base **encoder** from that service (for a hidef-only service, say); the base **decoder** has no such "default model" concept and is always loaded by every service regardless of this setting.
- `decoderLocale` overrides the locale used in the base decoder's package name when it differs from the language's `name`. **You don't need to set this for `en`** — the chart already defaults it to `"en_us"` (confirmed via resource-service logs: the installed package is `asr_decoder_model_en_us`, there's no bare `asr_decoder_model_en`). Only set `decoderLocale` for a language the chart doesn't already know about, or to override the built-in default for one specific language entry. To add/override a known exception for *every* `asrLanguages` entry in an install at once instead of repeating `decoderLocale` per language, set `global.asrDecoderLocaleDefaults` (e.g. `{ en: "en_us", fr: "fr_fr" }`). Get this wrong for a language and `asr`/`transcribe-realtime`/`transcribe-batch` fail fast at startup with a "model ... is not installed" error.
- Extra models (hidef or other variants) come from `asrLanguages[].extraModels`, nested under the language they belong to, and optionally take `services: [...]` (default: all three) to scope which service(s) load it.
- GPU use is controlled by `asrLanguages[].services.<service>.gpu` — see [GPU](#gpu) below.
- Helm fails the render (rather than deploying a pod that will crash-loop) if a service/language combination resolves to zero models, since the target env var is mandatory.

**Example:**

```yaml
global:
  asrLanguages:
    - name: "en"
      version: "8.0.0"
      # no decoderLocale needed - "en_us" is the chart's built-in default
      services:
        transcribeRealtime:
          base: false   # transcribeRealtime only uses the hidef model below
      extraModels:
        - name: "asr_encoder_hidef_model_en"
          version: "8.0.0"
          # services omitted -> loaded by asr, transcribeRealtime, and transcribeBatch
        - name: "asr_decoder_hidef_model_en_us"
          version: "8.0.0"
          services: ["asr"]             # only the asr service loads this decoder
    - name: "es"
      version: "8.0.0"
```

This renders, for the `en` language:

| Service              | `*_ENCODERS`                                                    | `*_DECODERS`                                                          |
|----------------------|------------------------------------------------------------------|------------------------------------------------------------------------|
| `asr`                | `asr_encoder_model_en-8.0.0;asr_encoder_hidef_model_en-8.0.0`     | `asr_decoder_model_en_us-8.0.0;asr_decoder_hidef_model_en_us-8.0.0` |
| `transcribe-realtime`| `asr_encoder_hidef_model_en-8.0.0`                                | `asr_decoder_model_en_us-8.0.0`                                         |
| `transcribe-batch`   | `asr_encoder_model_en-8.0.0;asr_encoder_hidef_model_en-8.0.0`     | `asr_decoder_model_en_us-8.0.0`                                         |

### GPU

| Parameter                          | Description                                              | Default |
|-------------------------------------|-----------------------------------------------------------|---------|
| `global.gpu.<service>.enabled`      | Chart-wide default: run `<service>` pods with GPU inference | `false` |
| `global.gpu.<service>.count`        | `nvidia.com/gpu` device count requested when enabled       | `1`     |
| `global.gpu.<service>.visibleDevices` | Sets `NVIDIA_VISIBLE_DEVICES`, e.g. `"all"`               | `""`    |
| `global.gpu.<service>.runtimeClassName` | Pod `runtimeClassName` for GPU pods, e.g. `"nvidia"`  | `""`    |

`<service>` is one of `asr`, `transcribeRealtime`, `transcribeBatch`. GPU-accelerated inference is opt-in; when enabled it sets `ASR_SETTINGS__ENABLE_GPU=true`, requests `count` `nvidia.com/gpu` device(s), and exposes the NVIDIA driver capabilities. `visibleDevices` ensures the CUDA compute libraries (`libcuda.so`) are mounted; needed on clusters where the device plugin sets `NVIDIA_VISIBLE_DEVICES=void`. Requires GPU nodes with the NVIDIA device plugin installed.

Every field above is a chart-wide default that can be overridden **per language, per service** via `global.asrLanguages[].services.<service>.gpu`:
- a bare bool overrides just `enabled` (the rest still comes from the `global.gpu.<service>` default);
- an object overrides any subset of `enabled`/`count`/`visibleDevices`/`runtimeClassName` for that one language+service.

**Example:**

```yaml
global:
  gpu:
    asr:
      enabled: false   # off by default for every language
  asrLanguages:
    - name: "en"
      services:
        asr:
          gpu: true                                                  # turn GPU on just for English's asr pods
        transcribeRealtime:
          gpu: true
        transcribeBatch:
          gpu: false
    - name: "es"
      services:
        asr:
          gpu: { enabled: true, count: 2, visibleDevices: "all" }    # size it differently for Spanish
    - name: "fr"   # no gpu block -> uses the global.gpu default (off) for every service
```

### ITN (Inverse Text Normalization)

| Parameter             | Description                      | Default |
|-----------------------|----------------------------------|---------|
| `global.itnLanguages` | List of ITN languages to install | `[]`    |

**Example:**

```yaml
global:
  itnLanguages:
    - name: "en"
    - name: "es"
    - name: "fr"
```

### TTS (Text-to-Speech)

| Parameter                        | Description                    | Default |
|----------------------------------|--------------------------------|---------|
| `global.ttsLanguages`            | List of  TTS voices to install | `[]`    |
| `global.ttsDefaultVersion`       | Default TTS voice version      | `"1.0"` |
| `global.neuralttsDefaultVersion` | Default Neural TTS version     | `"8"`   |
| `global.neuralTts.enabled`       | Deploy neural TTS for each `ttsLanguages` entry | `true` |

TTS voices are organized by region/language, with each region supporting multiple voices. Each voice uses the version specified in `ttsDefaultVersion` by default, but this can be overridden per voice.

**Example:**

```yaml
global:
  ttsDefaultVersion: "1.0"
  neuralttsDefaultVersion: "8"
  ttsLanguages:
    - name: "en_us"
      voices:
        - name: "chris"
        - name: "lindsey"
          version: "1.3"
```

**Legacy TTS**: Neural TTS is active by default. To use the legacy TTS engine for a specific language:

```yaml
global:
  ttsLanguages:
    - name: "en_us"
      legacyEnabled: true
      voices:
        - name: "chris"
```

### VB (Voice Biometrics)

| Parameter                 | Description                     | Default    |
|---------------------------|---------------------------------|------------|
| `global.vbLanguages`      | List of VB languages to install | `[]`       |
| `global.vbDefaultVersion` | Default VB model version        | `"2.1.15"` |

Each model uses the version specified in `vbDefaultVersion` by default, but can be overridden per language.

**Example:**

```yaml
global:
  vbDefaultVersion: "2.1.15"
  vbLanguages:
    - name: "en_US"
    - name: "es_MX"
      version: "2.1.13"
```

### LID (Language Identification)

| Parameter           | Description       | Default   |
|---------------------|-------------------|-----------|
| `global.lidVersion` | LID model version | `"2.0.0"` |

Language identification must be enabled via `global.enableLanguageId: true`.

## Advanced Configuration

### Grammar Manager

| Parameter                                       | Description                                | Default |
|-------------------------------------------------|--------------------------------------------|---------|
| `lumenvox-speech.grammar.maxGrammarTransitions` | Maximum grammar complexity (0 = unlimited) | `0`     |

### Resource Management

| Parameter                                  | Description                                | Default                          |
|--------------------------------------------|--------------------------------------------|----------------------------------|
| `global.lumenvox.resourceDownloadEndpoint` | Download endpoint for models and manifests | `"https://assets.lumenvox.com/"` |

### HTTP Proxy Configuration

| Parameter                   | Description                                           | Default                                          |
|-----------------------------|-------------------------------------------------------|--------------------------------------------------|
| `global.httpProxy.enabled`  | Enable HTTP proxy for external connections            | `false`                                          |
| `global.httpProxy.proxyUrl` | HTTP/HTTPS proxy URL                                  | `"http://PROXYURL.CONFIG.REQUIRED.invalid:3128"` |
| `global.httpProxy.noProxy`  | Comma-separated list of domains to exclude from proxy | `".local,.lumenvox"`                             |

HTTP proxy settings apply to services that make external HTTP/HTTPS connections (grammar, license, neural-tts, resource).

**Example:**

```yaml
global:
  httpProxy:
    enabled: true
    proxyUrl: "http://proxy.mycompany.com:8080"
    noProxy: ".local,.lumenvox,.internal.mycompany.com"
```

### Ingress Configuration

| Parameter                                   | Description                             | Default    |
|---------------------------------------------|-----------------------------------------|------------|
| `global.lumenvox.ingress.disableTls`        | Leave TLS off the Ingresses (e.g. TLS terminated at the load balancer) | `false` |
| `global.lumenvox.ingress.commonAnnotations` | nginx annotations for the API, portal and file-store Ingresses | See values |
| `global.lumenvox.ingress.grpcAnnotations`   | Added to the gRPC Ingresses (lumenvox-api, reporting-api) | See values |
| `global.lumenvox.ingress.httpAnnotations`   | Added to the HTTP Ingresses (portals, file-store, management-api, health check) | See values |
| `global.lumenvox.ingress.internalAllowlist` | Source-IP allowlist (CIDRs) for the internal-staff routes (portals, file-store, management-api, reporting-api) | `[]` |
| `global.lumenvox.ingress.lumenvoxApiAllowlist` | Source-IP allowlist (CIDRs) for the customer-facing lumenvox-api route | `[]` |
| `global.lumenvox.ingress.disableTokenAuth`  | Set to `false` to require a bearer token on lumenvox-api | `true` |
| `global.lumenvox.ingress.jwtAuth.*`         | How tokens are validated when token auth is on (see below) | See values |
| `global.enableLumenvoxapiHealthcheck`       | Enable external access to `/health`     | `false`    |

#### Access Control for lumenvox-api

The customer-facing `lumenvox-api` route is open by default, as in 7.x. Two opt-in controls work the same way in nginx and Istio mode:

- **Source-IP allowlist**: set `lumenvoxApiAllowlist` to the CIDRs allowed to call the API. nginx applies it as `whitelist-source-range`; Istio renders a DENY `AuthorizationPolicy`.
- **Token authentication**: set `disableTokenAuth: false`. With the default `jwtAuth.provider: token-auth-service`, an external auth service validates each request. nginx calls `jwtAuth.tokenAuthUrl` through `auth-url` (the ingress-nginx controller must allow snippet annotations). Istio delegates to the extension provider named by `jwtAuth.tokenAuthProvider`, which must be declared in the mesh config. With `jwtAuth.provider: istio-native` (Istio only), the gateway validates JWTs itself against `jwtAuth.issuer`, optionally checking `audiences` and `requiredClaims`.

When both are set, either one grants access: allowlisted clients need no token, and clients with a valid token need not be allowlisted. `/health`, `/metrics` and `/ready` on the same hostname are never restricted.

The internal-staff routes (admin-portal, deployment-portal, file-store, management-api, reporting-api) have no token authentication. Restrict them with `internalAllowlist`.

```yaml
global:
  lumenvox:
    ingress:
      lumenvoxApiAllowlist: ["203.0.113.0/24"]
      disableTokenAuth: false
      jwtAuth:
        provider: token-auth-service
        tokenAuthUrl: "http://token-auth-service.token-auth.svc.cluster.local:8082/auth"
      internalAllowlist: ["10.0.0.0/8"]
```

### Istio Gateway API Ingress Mode

The chart supports two ingress modes selected via `global.lumenvox.ingress.className`:

| Value | Result |
|---|---|
| `"nginx"` (default), or any other Ingress class such as `"nginx-public"` | Standard Ingress resources with that `ingressClassName` |
| `"istio"` | Kubernetes Gateway API resources (Gateway + HTTPRoutes) |

> **Note**: This is independent of the service mesh setting. You can use the Istio Gateway API for ingress while running Linkerd as the service mesh, or vice versa.

#### Prerequisites for Istio Mode

Before installing with `className: "istio"`, the cluster must have:
- **Istio installed** (provides the `istio` GatewayClass)
- **Gateway API CRDs installed** (`gateway.networking.k8s.io/v1`)

Install Gateway API CRDs:
```shell
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

Download Istio CLI
```shell
curl -L https://istio.io/downloadIstio | sh -
```

Install Istio CLI
```shell
export PATH=$HOME/istio-1.30.1/bin:$PATH
```

Install Istio with the default profile:
```shell
istioctl install --set profile=default -y
```

Verify:
```shell
kubectl get pods -n istio-system          # istio should be Running
kubectl get gatewayclass                  # "istio" class should be Accepted
```

#### Gateway Configuration

When using Istio mode, configure the gateway block in your values file:

```yaml
global:
  lumenvox:
    ingress:
      className: "istio"
    gateway:
      className: istio                  # GatewayClass name (provided by Istio)
      name: lumenvox-gateway            # Name of the Gateway resource
      namespace: "istio-ingress"        # Namespace for the Gateway + proxy
      disableTls: false                 # false = TLS terminated at gateway
      tlsSecretName: speech-tls-secret  # TLS secret (in release namespace)
      backendTimeout: "350s"            # Covers long-running gRPC streams
      annotations: {}                   # LoadBalancer Service annotations
```

| Parameter | Description | Default |
|---|---|---|
| `gateway.className` | GatewayClass name provided by Istio | `istio` |
| `gateway.name` | Name of the Gateway resource | `lumenvox-gateway` |
| `gateway.namespace` | Namespace where the Gateway and Istio proxy live | `istio-ingress` |
| `gateway.createIstioNamespace` | Render the gateway Namespace; set `false` when another release owns it | `true` |
| `gateway.disableTls` | If `true`, gateway listens on HTTP only (port 80) | `false` |
| `gateway.tlsSecretName` | TLS secret name (must exist in release namespace) | `speech-tls-secret` |
| `gateway.backendTimeout` | HTTPRoute backend request timeout | `350s` |
| `gateway.annotations` | Annotations propagated to the LoadBalancer Service | `{}` |
| `gateway.serviceExtraPorts` | Extra `{name, port, targetPort, protocol}` ports on the generated gateway Service (e.g. 443 for NLB-terminated TLS) | `[]` |

#### TLS Secret Behavior

When `disableTls: false`, the Gateway terminates TLS in the gateway namespace
(`istio-ingress`), but the TLS secret normally lives in the release namespace.
The chart ships a `tls-secret-copy-job` that copies the secret from the release
namespace into the gateway namespace automatically. Ensure the secret exists
in your release namespace before deploying (same requirement as nginx mode).

#### Cloud LoadBalancer Annotations

When deploying to a cloud provider, set provider-specific annotations under
`gateway.annotations`. These are propagated to the generated LoadBalancer Service.

**AWS NLB (internet-facing):**
```yaml
global:
  lumenvox:
    gateway:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "external"
        service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```

**GCP (external passthrough LB):**
```yaml
global:
  lumenvox:
    gateway:
      annotations:
        cloud.google.com/load-balancer-type: "External"
```

**Azure (public LB):**
```yaml
global:
  lumenvox:
    gateway:
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-internal: "false"
```

#### gRPC Routing

The nginx GRPC backend-protocol annotations are not needed in Istio mode.
The chart uses HTTPRoute with `timeouts.request: "0s"` (unlimited streaming)
for gRPC services (`lumenvox-api`, `reporting-api`), and the services carry
`appProtocol: kubernetes.io/h2c` so Istio detects HTTP/2 correctly. No values
configuration is required — this is automatic.

#### minikube Note

The chart includes a `gateway-patch-job` that patches the gateway Service
with a node IP. This job only runs when `global.platform: minikube`. On
cloud clusters and bare-metal kubeadm, the job is skipped — cloud
LoadBalancers assign an external IP automatically.

#### Switching Between nginx and Istio

**To switch from nginx to Istio:**
1. Install Istio and Gateway API CRDs (see Prerequisites above)
2. Ensure the TLS secret exists in your release namespace
3. In your values file, change `className: "nginx"` to `className: "istio"`
4. Add the `gateway:` block under `global.lumenvox`
5. Run `helm upgrade lumenvox lumenvox/lumenvox -f my-values.yaml -n lumenvox`

**To switch from Istio back to nginx:**
1. Change `className: "istio"` to `className: "nginx"` in your values file
2. Remove the `gateway:` block (or leave it — it's ignored in nginx mode)
3. Run `helm upgrade lumenvox lumenvox/lumenvox -f my-values.yaml -n lumenvox`

### Licensing Configuration

| Parameter                         | Description                           | Default |
|-----------------------------------|---------------------------------------|---------|
| `global.licensing.reportFreqMins` | License reporting frequency (minutes) | `1440`  |
| `global.licensing.reportSyncHour` | Hour to sync reporting (0-23)         | `1`     |
| `global.licensing.reportSyncMin`  | Minute to sync reporting (0-59)       | `0`     |

### RabbitMQ Advanced Settings

| Parameter                                      | Description                                | Default  |
|------------------------------------------------|--------------------------------------------|----------|
| `global.lumenvox.rabbitmqQueueExpirationMs`    | Default queue expiration in milliseconds   | `180000` |
| `rabbitmq.retryTime`                           | Retry time for RabbitMQ connections        | `60`     |
| `global.rabbitmq.init.checkManagementEndpoint` | Check RabbitMQ management endpoint on init | `false`  |

# Installation

## Prerequisites

Before installing, ensure you have:

1. **Valid LumenVox License**: Contact your LumenVox account manager to obtain a cluster GUID
2. **External Services**: PostgreSQL, MongoDB, Redis, and RabbitMQ (or use the test `external-services` chart)
3. **TLS Certificate**: Create a TLS secret for ingress (see TLS section below)
4. **Database Secrets**: Create secrets for database passwords (see External Dependencies sections above)
5. **Encryption Key**: Create a secret with your master encryption key (see Encryption section below)

## Creating Required Secrets

> **Security Note**: The commands below create secrets directly from command-line literals, which is convenient for testing but may expose sensitive data in shell history and process listings. For production deployments, consult your security team and use secure secret management practices (e.g., HashiCorp Vault, sealed secrets, or your cloud provider's secret management service).

### Database Passwords

```shell
# RabbitMQ
kubectl create secret generic rabbitmq-existing-secret -n lumenvox \
  --from-literal=rabbitmq-password='YOUR_RABBITMQ_PASSWORD'

# Redis
kubectl create secret generic redis-existing-secret -n lumenvox \
  --from-literal=redis-password='YOUR_REDIS_PASSWORD'

# MongoDB
kubectl create secret generic mongodb-existing-secret -n lumenvox \
  --from-literal=mongodb-root-password='YOUR_MONGODB_PASSWORD'

# PostgreSQL
kubectl create secret generic postgres-existing-secret -n lumenvox \
  --from-literal=postgresql-password='YOUR_POSTGRES_USER_PASSWORD' \
  --from-literal=postgresql-postgres-password='YOUR_POSTGRES_ROOT_PASSWORD'
```

### Encryption Secret

```shell
kubectl create secret generic encryption-secret -n lumenvox \
  --from-literal=master-encryption-key='YOUR_ENCRYPTION_KEY'
```

### TLS Certificate

The chart requires a TLS secret named `speech-tls-secret` for securing ingress traffic. For gRPC endpoints, proper SANs are required for traffic to be correctly routed.

> **Security Note**: The certificate generation commands below are provided for testing and development purposes only. For production deployments, consult your security team and use certificates issued by a trusted Certificate Authority with appropriate security controls.

**Recommended certificate (standard deployment):**

For most deployments, you need SANs for the core functional endpoints:

```shell
openssl genrsa -out server.key 2048
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650 \
  -addext "subjectAltName = \
    DNS:lumenvox-api.testmachine.com, \
    DNS:deployment-portal.testmachine.com, \
    DNS:admin-portal.testmachine.com, \
    DNS:management-api.testmachine.com, \
    DNS:reporting-api.testmachine.com, \
    DNS:file-store.testmachine.com"

kubectl create secret tls speech-tls-secret -n lumenvox --key server.key --cert server.crt
```

**Notes:**
- Replace `.testmachine.com` with your `global.hostnameSuffix` value
- The openssl command will prompt for certificate information; all fields can be left blank as the necessary information is in the SAN extension
- **All application functionality** is accessed through the `lumenvox-api` endpoint; this is the primary API for client interactions

**Optional: Developer/Metrics Access**

Individual service ingresses (ASR, TTS, Grammar, Session, etc.) expose health check and metrics endpoints, typically used only for development and debugging. These are not required for normal operation as all functional API calls go through `lumenvox-api`. 

If you need to access these developer endpoints, add their hostnames to your certificate:

```shell
openssl genrsa -out server.key 2048
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650 \
  -addext "subjectAltName = \
    DNS:lumenvox-api.testmachine.com, \
    DNS:deployment-portal.testmachine.com, \
    DNS:admin-portal.testmachine.com, \
    DNS:management-api.testmachine.com, \
    DNS:reporting-api.testmachine.com, \
    DNS:file-store.testmachine.com, \
    DNS:grammar.testmachine.com, \
    DNS:session.testmachine.com, \
    DNS:vad.testmachine.com, \
    DNS:nlu.testmachine.com, \
    DNS:diarization.testmachine.com, \
    DNS:lid.testmachine.com"

kubectl create secret tls speech-tls-secret -n lumenvox --key server.key --cert server.crt
```

**Wildcard Certificate Alternative:**

For environments requiring access to many service endpoints (including language-specific services like `asr-en.testmachine.com`, `tts-en-us.testmachine.com`, etc.), consider using a wildcard certificate:

```shell
openssl genrsa -out server.key 2048
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650 \
  -addext "subjectAltName = DNS:*.testmachine.com, DNS:testmachine.com"

kubectl create secret tls speech-tls-secret -n lumenvox --key server.key --cert server.crt
```

## Installation Steps

1. **Add the Helm repository:**

```shell
helm repo add lumenvox https://lumenvox.github.io/helm-charts
helm repo update
```

2. **Create a values file** (`my-values.yaml`) with your configuration:

```yaml
global:
  licensing:
    clusterGuid: "YOUR-CLUSTER-GUID-FROM-LUMENVOX"
  hostnameSuffix: ".your-domain.com"
  enabled:
    lumenvoxSpeech: true
    lumenvoxVb: false
  asrLanguages:
    - name: "en"
  ttsLanguages:
    - name: "en_us"
      voices:
        - name: "chris"
```

3. **Install the chart:**

```shell
helm install lumenvox lumenvox/lumenvox \
  -f my-values.yaml \
  -n lumenvox \
  --create-namespace
```

4. **Verify the installation:**

```shell
kubectl get pods -n lumenvox
helm status lumenvox -n lumenvox
```

## Upgrading

To upgrade an existing installation:

```shell
helm repo update
helm upgrade lumenvox lumenvox/lumenvox \
  -f my-values.yaml \
  -n lumenvox
```

> **Important**: Review the release notes before upgrading between major versions. Database migrations will run automatically unless disabled.

## Uninstallation

```shell
helm uninstall lumenvox -n lumenvox
```

This removes all Kubernetes resources associated with the chart. Note that:
- Secrets are not automatically deleted
- Persistent volumes may be retained depending on your configuration
- External services (databases) are not affected

# Operational Notes
## Image Versioning

LumenVox images use `MAJOR.MINOR.PATCH` semantic versioning. By default, the chart matches the major and minor versions while pulling the most recent patch version. For example, a tag of `:8.0` will pull the latest `8.0.x` patch version.

**Default Behavior**: The default configuration (`tag: ":8.0"`) automatically pulls the latest patch releases. This is recommended for most deployments, as patch releases only fix bugs and never introduce breaking changes.

### Controlling Image Updates

To control when images are updated, use the `pullPolicy` setting:

```yaml
global:
  image:
    tag: ":8.0"
    pullPolicy: IfNotPresent  # Only pull if image not already present
```

**Pull Policy Options:**
- `IfNotPresent` (default): Pull only if the image isn't already on the node. This keeps your running images stable while allowing new deployments to get the latest patches.
- `Always`: Always pull the latest image matching the tag. Use with caution in production.
- `Never`: Never pull; only use locally available images.

### Subchart Image Overrides

To use different image tag policies for different components:

```yaml
# Override common infrastructure images
lumenvox-common:
  image:
    tag: ":8.0"
    pullPolicy: IfNotPresent

# Override speech service images
lumenvox-speech:
  image:
    tag: ":8.0"
    pullPolicy: IfNotPresent

# Override voice biometrics images
lumenvox-vb:
  image:
    tag: ":8.0"
    pullPolicy: IfNotPresent
```

> **Note**: Due to LumenVox's patch release process where individual services are patched independently, specifying a specific patch version (e.g., `:8.0.1`) is not recommended. Instead, use the `pullPolicy` to control update behavior.

## Accessing the Services

After installation, the following endpoints will be available (assuming `hostnameSuffix: ".testmachine.com"`):

### Primary Endpoints

These are the main endpoints for production use:

- **LumenVox API**: `https://lumenvox-api.testmachine.com` - **Primary API endpoint for all speech functionality** (ASR, TTS, etc.)
- **Deployment Portal**: `https://deployment-portal.testmachine.com` - Administrative interface for system configuration
- **Admin Portal**: `https://admin-portal.testmachine.com` - User and configuration management
- **Management API**: `https://management-api.testmachine.com` - Management interface
- **Reporting API**: `https://reporting-api.testmachine.com` - Reporting and analytics
- **File Store**: `https://file-store.testmachine.com` - File storage interface (if enabled)

### Developer/Debugging Endpoints

The following endpoints expose health checks and metrics for individual services. These are intended for development and debugging purposes and are not required for normal operation:

**Speech Services** (when enabled via `global.lumenvox.metrics.enableEndpoints: true`):
- **Grammar**: `https://grammar.testmachine.com`
- **Session**: `https://session.testmachine.com`
- **VAD**: `https://vad.testmachine.com`
- **NLU**: `https://nlu.testmachine.com` (if `global.enableNlu: true`)
- **Diarization**: `https://diarization.testmachine.com` (if `global.enableDiarization: true`)
- **LID**: `https://lid.testmachine.com` (if `global.enableLanguageId: true`)

**Language-Specific Service Endpoints**: ASR, TTS, Neural TTS, and ITN create per-language health/metrics endpoints:
- `https://asr-{language}.testmachine.com` (e.g., `asr-en.testmachine.com`)
- `https://tts-{language}.testmachine.com` (e.g., `tts-en-us.testmachine.com`)
- `https://neural-tts-{language}.testmachine.com`
- `https://itn-{language}.testmachine.com`

> **Note**: All application functionality (speech recognition, synthesis, etc.) is accessed through the `lumenvox-api` endpoint. Individual service endpoints are for monitoring and debugging only.

Clients making requests to these APIs should trust the TLS certificate configured in the `speech-tls-secret`.

## Monitoring and Observability

LumenVox services expose metrics endpoints that can be scraped by Prometheus. To enable ingress for internal service metrics (typically used only for development):

```yaml
global:
  lumenvox:
    metrics:
      enableEndpoints: true
```

## Health Checks

All services include health check endpoints for Kubernetes liveness and readiness probes:

| Parameter                                       | Description                  | Default |
|-------------------------------------------------|------------------------------|---------|
| `global.lumenvox.probes.periodSeconds`          | Probe check frequency        | `5`     |
| `global.lumenvox.service.startDelaySeconds`     | Delay before starting probes | `5`     |
| `global.lumenvox.service.livenessProbe.enabled` | Enable liveness probes       | `true`  |

To enable external access to the LumenVox API health check endpoint (`/health`):

```yaml
global:
  enableLumenvoxapiHealthcheck: true
```

## Resource Management

### Resource Limits and Reservations

| Parameter                             | Description                                      | Default |
|---------------------------------------|--------------------------------------------------|---------|
| `global.lumenvox.enforceLimits`       | Enforce resource limits on all services          | `false` |
| `global.lumenvox.enforceReservations` | Enforce resource reservations (required for HPA) | `false` |

**Resource Reservations** are required for Horizontal Pod Autoscaling (HPA) in cloud deployments. They are typically disabled for kubeadm-based installations.

### Scheduler Configuration

To use a custom Kubernetes scheduler:

```yaml
global:
  lumenvox:
    schedulerName: "my-custom-scheduler"
```

## Troubleshooting

### Common Issues

**Pods stuck in Pending state:**
- Check that your cluster has sufficient resources
- Verify persistent volume provisioning is working
- Check for node selector or affinity issues

**Database connection timeouts:**
- Verify database services are accessible from the cluster
- Check database credentials in secrets
- Increase `global.lumenvox.deploymentReconnectionTimeoutSec` if needed

**License errors:**
- Verify `global.licensing.clusterGuid` is set correctly
- Ensure the license service can reach `https://license.lumenvox.com`
- Check network policies and firewall rules

**Model download failures:**
- Verify network connectivity to `https://assets.lumenvox.com`
- Check HTTP proxy configuration if behind a corporate proxy
- Verify `global.lumenvox.resourceDownloadEndpoint` is accessible

**Linkerd issues:**
- Ensure Linkerd is installed before the LumenVox chart
- Check Linkerd certificates haven't expired
- Verify the service mesh type is set correctly

### Checking Logs

View logs for a specific service:

```shell
# List pods
kubectl get pods -n lumenvox

# View logs for a specific pod
kubectl logs <pod-name> -n lumenvox

# Follow logs in real-time
kubectl logs -f <pod-name> -n lumenvox

# For pods with multiple containers
kubectl logs <pod-name> -c <container-name> -n lumenvox
```

### Debugging Database Migrations

To check migration status:

```shell
kubectl logs -l app.kubernetes.io/name=deployment -n lumenvox
```

To skip automatic migrations:

```yaml
global:
  postgresql:
    runMigrations: 'false'
```

### Validating Configuration

Check current configuration values:

```shell
helm get values lumenvox -n lumenvox
```

View all computed values (including defaults):

```shell
helm get values lumenvox -n lumenvox --all
```

Test a configuration before installing:

```shell
helm template lumenvox lumenvox/lumenvox -f my-values.yaml
```

# Testing Environment

## Test Dependencies

For non-production testing and development, enable the [`lumenvox-external-services`](../lumenvox-external-services) subchart (`global.enabled.externalServices: true`) to deploy the required dependencies (RabbitMQ, Redis, MongoDB, and PostgreSQL) inside the cluster. See its README for the secrets to create first.

It includes:
- MongoDB 8.2
- PostgreSQL 17.5
- RabbitMQ 4.1.8 (with management interface)
- Redis 8.2.4

> **Warning**: The subchart's defaults are sized for a proof of concept, not for production scale or high availability.

## Minimum Resource Requirements

The following are minimum requirements for a testing/lab environment. **For production sizing, contact LumenVox.**

### Cluster Resources

- **LumenVox Speech**: Minimum of 3 nodes with at least 8 CPUs and 16GB memory each

### External Service Resources

|                    | RabbitMQ | MongoDB | PostgreSQL | Redis | Persistent Storage |
|--------------------|----------|---------|------------|-------|--------------------|
| **CPU**            | 1        | 2       | 2          | -     | -                  |
| **Memory**         | 2GB      | 16GB    | 8GB        | 5GB   | -                  |
| **Boot Disk Size** | 10GB     | 10GB    | 10GB       | -     | -                  |
| **Data Storage**   | -        | 300GB   | 30GB       | -     | 300GB              |

## Grafana Monitoring (Test Environments)

In a test environment, you can optionally configure Grafana for monitoring:

1. Access the Grafana UI
2. Add Prometheus as a data source
3. Import a Kubernetes monitoring dashboard (e.g., dashboard ID 12740)

# Support and Contact

For assistance with LumenVox deployments:

- **Pre-Installation**: Contact your LumenVox account manager for licensing and configuration planning
- **Technical Support**: Work with the LumenVox support team for deployment assistance
- **Documentation**: Visit [https://lumenvox.com](https://lumenvox.com) for additional resources

# Chart Information

- **Home**: [https://lumenvox.com](https://lumenvox.com)
- **Source**: [https://github.com/lumenvox/helm-charts](https://github.com/lumenvox/helm-charts)

# License

Copyright © LumenVox. See LICENSE file for details.
