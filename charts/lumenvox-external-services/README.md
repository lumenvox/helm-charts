# LumenVox External Services Helm Chart

This chart runs the external services needed by the LumenVox stack inside your Kubernetes cluster:

- MongoDB
- PostgreSQL
- RabbitMQ
- Redis

The services are installed and upgraded together with the stack using standard helm commands. The chart installs into the same namespace as the LumenVox stack and references four pre-created secrets the LumenVox chart reads.

## Quick start

### Create the secrets

The chart does not create secrets — you must create them in the release namespace before installing:

```bash
kubectl create secret generic mongodb-existing-secret -n lumenvox \
  --from-literal=mongodb-root-password=<password>

kubectl create secret generic postgres-existing-secret -n lumenvox \
  --from-literal=postgresql-password=<password>

kubectl create secret generic rabbitmq-existing-secret -n lumenvox \
  --from-literal=rabbitmq-password=<password>

kubectl create secret generic redis-existing-secret -n lumenvox \
  --from-literal=redis-password=<password>
```

Passwords must be alphanumeric only (no special characters), per the LumenVox install docs.

The install fails with the exact `kubectl create secret` command if any secret is missing or incomplete.

### Install

```bash
helm install external-services . -n lumenvox --create-namespace \
  --set redis.clusterMode.operator.storage.className=managed-csi
```

`managed-csi` is the AKS storage class. For other platforms see the [Storage class](#storage-class) table in the Redis Cluster mode section.

```bash
kubectl get pods -n lumenvox
```

9 pods should reach `Running` within a couple of minutes — six Redis pods (`external-services-redis-cluster-leader-{0-2}` and `external-services-redis-cluster-follower-{0-2}`, reconciled by the operator) plus `external-services-mongodb`, `-postgresql`, and `-rabbitmq`. The operator forms the cluster automatically; no separate init pod is needed. In single-instance mode (`--set redis.clusterMode.enabled=false`) there are no cluster pods and `external-services-redis-master` runs instead. PVCs may show `Pending` until pods are scheduled, which is normal.

## Options

### Storage

The chart uses your cluster's default storage class by default for MongoDB, PostgreSQL, RabbitMQ, and Redis single-instance mode. This works out of the box on EKS, AKS, and GKE. To use a specific class for those services:

```bash
--set storage.className=<name>
```

Each service also accepts its own `storageClassName`, which takes precedence over `storage.className`. The four have genuinely different needs — MongoDB wants capacity, PostgreSQL and RabbitMQ want IOPS — so they do not have to share a class:

```bash
--set postgresql.storageClassName=gp3-db --set mongodb.storageClassName=gp2
```

**Redis cluster mode has a separate, required storage class setting** (`redis.clusterMode.operator.storage.className`) with no default. It must be set explicitly — see [Storage class](#storage-class) in the Redis Cluster mode section.

On bare-metal clusters with no storage class, enable the bundled Rancher local-path provisioner:

```bash
--set localPathProvisioner.enabled=true --set storage.className=local-path
```

### Private registry

MongoDB, PostgreSQL, and RabbitMQ images are pulled from Docker Hub. Redis cluster mode pulls from `quay.io/opstree/redis` — not Docker Hub.

**Redis cluster mode (default)** — mirror five images and point the chart at them:

```bash
helm install external-services . -n lumenvox --create-namespace \
  --set mongodb.image.repository=registry.example.com/mongo \
  --set postgresql.image.repository=registry.example.com/postgres \
  --set rabbitmq.image.repository=registry.example.com/rabbitmq \
  --set redis.clusterMode.operator.image.repository=registry.example.com/opstree-redis \
  --set redis.clusterMode.operator.storage.className=managed-csi
```

The operator image (`quay.io/opstree/redis-operator`) runs as an init container (`init-config`) on every Redis cluster pod. It must also be mirrored and pointed at via the operator chart's own values when installing the operator.

**Redis single-instance mode** — use `redis.image.repository` instead of `redis.clusterMode.operator.image.repository`.

### Service mesh

If linkerd runs in the cluster, pass `--set linkerd.enabled=true`. Database ports are then marked opaque so the mesh carries them under mTLS without protocol detection. Exception: Redis Cluster ports skip the proxy entirely due to a known linkerd limitation with cluster bootstrap — cluster nodes connect to each other before passing readiness, and the inbound proxy rejects that traffic ([linkerd issue #13247](https://github.com/linkerd/linkerd2/issues/13247)).

### Redis: cluster or single instance

Redis Cluster (6-node, 3 masters + 3 replicas) is the default. For small test environments, switch to a single instance:

```bash
--set redis.clusterMode.enabled=false
```

See [Redis Cluster mode](#redis-cluster-mode) below for the client service name, the LumenVox chart values to set, and storage requirements.

### Tuning for load

The chart's default resources are POC minimums. Sizing them for sustained load
is a matter of setting `resources`, but four settings need more than a number,
because the failure they prevent is not "too slow" — it is a hard stop:

| Setting | Default | What it prevents |
|---|---|---|
| `redis.maxmemoryPercent` | `60` | Redis has no `maxmemory` boundary of its own, so it allocates past the container limit and is OOM-killed instead of evicting. On a cluster leader that is a shard failover, which every client sees as `MOVED`/`CLUSTERDOWN`. The margin is 40% because `maxmemory` bounds only the data set — client output buffers, replication backlog and fragmentation sit outside it and grow with connection count. |
| `rabbitmq.memoryHighWatermarkPercent` | `60` | Left to inference the watermark is 0.4 of whatever RabbitMQ believes total memory to be — the cgroup limit on some nodes (a watermark that can sit *under* real usage, blocking all publishers via flow control) or host memory on others (a watermark above the container limit, so the pod is OOM-killed before flow control engages). |
| `rabbitmq.schedulers` | auto | The Erlang VM sizes its scheduler pool from online *host* CPUs and ignores the cgroup CPU quota, so a pod limited to 1 core on a 16-core node still starts 16 schedulers to share that slice. Derived from `resources.limits.cpu` unless set explicitly. |
| `mongodb.wiredTigerCacheSizeGB` | unset | WiredTiger sizes its cache at 50% of (memory limit − 1GB) when left to infer, which reserves more than `requests` promised the scheduler — overcommit that surfaces as node memory pressure rather than a mongod error. |

Both percentages are resolved against the service's own `resources.limits.memory`
and rendered as absolute byte counts, so they cannot drift when a pod is resized.
Set `redis.maxmemoryPercent: 0` to omit `maxmemory` entirely.

Two more worth knowing about:

- **`redis.ioThreads`** (default `1`) — Redis serves its whole command path on
  one thread, and that thread also performs the socket reads and writes. Raising
  this moves the socket work off it, which is what a managed cache does with its
  own I/O threads. Only useful when the pod has more than one core.
- **`redis.clusterMode.operator.persistenceEnabled`** (default `false`) — writes
  an append-only file on every shard. For a cache with a TTL that repopulates on
  restart, AOF write volume tracks the SET rate while the data being protected is
  only the resident set, so it is off by default: the disk stays out of the
  command path and only the nodeConf volume is provisioned per pod. Set it `true`
  to restore AOF.

  > **Upgrading an existing install:** if the release currently has persistence
  > enabled, taking this default flips it off, and the operator then recreates
  > the StatefulSets without their data volumes — the cache starts cold and the
  > old data PVCs are left behind for you to delete. Schedule it, or pin
  > `persistenceEnabled: true` to keep the current behaviour.

> **Redis config changes need a pod restart.** The settings above are
> delivered through the `external-services-redis-extra-config` ConfigMap, and
> redis reads it only at startup. The operator restarts a pod when its own
> spec changes, so a change that touches ONLY the ConfigMap — `maxmemory`,
> `maxclients`, `io-threads`, `extraConfig` — leaves running pods on the old
> values indefinitely. Worse, it can leave the cluster split: observed on
> cloud-speech-1 with three pods on a new `maxmemory` and three still on the
> old one, because only one of the two StatefulSets had a spec change to
> trigger a roll. Either apply it at runtime
> (`redis-cli CONFIG SET maxmemory <bytes>`, which the file then matches on
> the next restart) or force a roll:
>
> ```bash
> kubectl rollout restart statefulset/<release>-redis-cluster-leader \
>   statefulset/<release>-redis-cluster-follower -n <namespace>
> ```
>
> Check what is actually live with `redis_memory_max_bytes`, not the
> ConfigMap.

> **Size both redis roles the same.** The operator names pods `leader-N` and
> `follower-N`, but Redis Cluster roles are dynamic: anything that rolls the
> leader StatefulSet — including a resource change — fails each master over to
> its replica, and the operator does not fail back. The pods named
> `follower-*` can therefore be the actual masters indefinitely. Giving
> `leader` and `follower` different resources means that after any failover
> the masters are running on whichever allocation is smaller, silently.
> Determine real roles from `redis_instance_info{role=...}` or
> `redis_connected_slaves`, never from the pod name. This also affects
> anything that writes: `FLUSHALL` against a `leader-*` pod returns
> `READONLY You can't write against a read only replica` when that pod is
> currently a replica.

`redis.clusterMode.operator.maxClients` (default `20000`) sets `maxclients` on
cluster nodes. Note that the top-level `redis.maxClients` only ever reached the
single-instance deployment; cluster mode previously inherited the operator image
default. Redis silently lowers `maxclients` when the container's file-descriptor
limit is below `maxclients + 32`, and logs it once at startup.

`postgresql.config` is a map of server settings, passed as `-c key=value` flags.
The upstream image ships stock defaults regardless of container size
(`shared_buffers=128MB`, `max_connections=100`, and `random_page_cost=4.0`, which
assumes a spinning disk), whereas a managed instance auto-tunes them:

```yaml
postgresql:
  config:
    max_connections: "200"
    shared_buffers: "512MB"
    random_page_cost: "1.1"
```

### Availability and placement

Probes are enabled by default on all four services (`<service>.probes.enabled`).
Without a readiness probe a Service endpoint goes live the moment the container
starts, so every client pod's init container hammers a database that cannot
answer yet — which matters most for a broker recovering a large queue topology.

Each service also gets a PodDisruptionBudget, on by default. PostgreSQL, MongoDB
and RabbitMQ use `maxUnavailable: 0`: they are single replicas on `ReadWriteOnce`
volumes, so no voluntary eviction is survivable and a drain should be a decision
rather than a side effect of node consolidation. Redis Cluster uses
`maxUnavailable: 1`, which permits a rolling drain without taking two cluster
members at once. Disable per service with
`<service>.podDisruptionBudget.enabled=false`.

All four accept `nodeSelector`, `tolerations`, `affinity`,
`topologySpreadConstraints`, `priorityClassName` and `podAnnotations`, all empty
by default. These matter more in-cluster than they did with managed services:
nothing otherwise stops a database being scheduled onto a node already running
the workload it serves at that node's packing target. `podAnnotations` is also
where autoscaler hints go — without `karpenter.sh/do-not-disrupt: "true"`,
routine consolidation will drain the node holding a single-replica database.

On AWS with Karpenter, [`examples/karpenter-nodepool.yaml`](examples/karpenter-nodepool.yaml)
is a dedicated, tainted node pool for these services, with the matching
`nodeSelector` and `tolerations` in its header.

## Connect the LumenVox chart

The LumenVox chart's built-in defaults for all four connection URLs are namespace-qualified with `.lumenvox`:

```
external-services-rabbitmq.lumenvox
external-services-redis-clustercfg.lumenvox
external-services-mongodb.lumenvox
external-services-postgresql.lumenvox
```

When this chart is installed with the release name `external-services` in the `lumenvox` namespace (as shown above), these defaults resolve correctly and **no connection URL overrides are needed for any of the four services**.

If this chart is installed in a different namespace, all four URLs need to be overridden to point to the correct namespace. For example, if installed in `myns`:

```yaml
rabbitmq:
  enableTLS: false
  connection:
    url: "external-services-rabbitmq.myns"
redis:
  enableTLS: false
  connection:
    url: "external-services-redis-clustercfg.myns"
mongodb:
  connection:
    url: "external-services-mongodb.myns"
postgresql:
  connection:
    url: "external-services-postgresql.myns"
    databaseName: "lumenvox_single_db"
    databaseSchema: "public"
```

In single-instance mode (`redis.clusterMode.enabled=false`) use `external-services-redis-master.<namespace>` for the Redis URL.

The four secrets below must be pre-created by the customer before installing (see [Create the secrets](#create-the-secrets) above). The names and keys match what the LumenVox chart expects, so no additional configuration is needed once they exist.

| Secret name | Required key |
|---|---|
| `mongodb-existing-secret` | `mongodb-root-password` |
| `postgres-existing-secret` | `postgresql-password` |
| `rabbitmq-existing-secret` | `rabbitmq-password` |
| `redis-existing-secret` | `redis-password` |

> **PostgreSQL database name:** this chart creates `lumenvox_single_db`, matching the LumenVox quick-start values. If your LumenVox values file sets a different `postgresql.connection.databaseName` (the chart's own built-in default is `lumenvox_db`), align the two: use the same name in both charts. PostgreSQL does not create databases automatically, so a mismatch shows up as services waiting for the database.

## Redis Cluster mode

By default Redis runs as a 6-node Cluster (3 masters + 3 replicas) managed by the [OpsTree Redis Operator](https://github.com/OT-CONTAINER-KIT/redis-operator).

> **The operator must be installed before installing or upgrading this chart.** The chart refuses to install or upgrade if the operator CRD is absent.

```bash
helm repo add ot-helm https://ot-container-kit.github.io/helm-charts/
helm repo update
helm install redis-operator ot-helm/redis-operator \
  -n ot-operators --create-namespace \
  --version 0.26.1 \
  --set featureGates.GenerateConfigInInitContainer=true
```

**`featureGates.GenerateConfigInInitContainer=true` is required.** Without it the operator does not inject the hostname announce configuration and the cluster cannot resolve peers by stable DNS name.

To confirm the feature gate is active, check the operator deployment's environment variables:

```bash
kubectl -n ot-operators get deploy redis-operator \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}'
```

Expected output includes `FEATURE_GATES=GenerateConfigInInitContainer=true` and `INIT_CONTAINER_IMAGE=quay.io/opstree/redis-operator:<version>`. The flag is set as an environment variable, not a command-line argument, so it does not appear in the deployment's `args`.

When the gate is on, each cluster pod gains an init container named `init-config`. Confirm on a running pod:

```bash
kubectl -n lumenvox get pod external-services-redis-cluster-leader-0 \
  -o jsonpath='{range .spec.initContainers[*]}{.name}{"\t"}{.image}{"\n"}{end}'
```

> **Note:** operator chart version `0.26.1` ships operator image `v0.26.0` — the chart version and image version numbers differ. A `v0.26.0` image is not evidence of a wrong install.

The client service is named `external-services-redis-clustercfg`. The name contains `clustercfg` on purpose: the LumenVox chart auto-detects cluster mode from that substring in the Redis URL — the same convention AWS ElastiCache uses in its configuration endpoints. So in the LumenVox chart values, point Redis at:

```yaml
redis:
  enableTLS: false
  connection:
    url: "external-services-redis-clustercfg"
```

and the connection scheme switches to `redis-cluster://` automatically. No other changes are needed — the password still comes from the same secret.

For small test environments that don't need the cluster overhead, switch to single-instance mode:

```yaml
redis:
  clusterMode:
    enabled: false
```

Note: cluster mode uses two persistent volumes per pod (data + node configuration, sized by `redis.clusterMode.operator.storage.size` and `nodeConfSize`); single-instance mode uses one.

### What the chart creates

In cluster mode the chart renders:

- A **RedisCluster CR** (`redis.redis.opstreelabs.in/v1beta2`) — the operator reconciles this into pods, headless services, and config.
- An **extra-config ConfigMap** (`external-services-redis-extra-config`) with `cluster-preferred-endpoint-type hostname`, referenced by the CR so nodes announce their stable DNS names.
- A **PodDisruptionBudget** (`maxUnavailable: 1`) — the operator ships none of its own.
- A **headless shim Service** named exactly `external-services-redis-clustercfg` — the LumenVox chart's `global.redis.connection.url` and the `clustercfg` scheme-switch require no change.

The `redis-existing-secret` secret (`redis-password` key) is read by the operator via `spec.kubernetesConfig.redisSecret`.

### Storage class

`redis.clusterMode.operator.storage.className` is required. There is no cluster-default because the chart provisions two PVC types per pod (data + nodeConf) and relies on the storage class supporting `ReadWriteOnce`. Typical values:

| Platform | className |
|---|---|
| AKS | `managed-csi` |
| EKS | `gp2` |
| Bare-metal with local-path | `local-path` |

Set it in the values file before installing:

```yaml
redis:
  clusterMode:
    operator:
      storage:
        className: managed-csi   # use managed-csi on AKS, gp2 on EKS
```

### Operational notes

**Scale-in is a maintenance-window operation.** When reducing `leaderReplicas` or `followerReplicas`, clients hold a slot-topology map cached from the previous cluster state. After the operator removes a node, clients hitting the removed shard's slot range get MOVED or CLUSTERDOWN errors until they refresh their topology; the number of errors depends on the client's refresh behaviour. Schedule scale-in during a low-traffic window and verify the client topology-refresh interval before proceeding.

**Deleting removed nodes' PVCs is mandatory.** After a scale-in, the PVCs for the removed ordinals (both data and nodeConf volumes) must be deleted manually before any scale-up. The operator's join procedure checks whether the node is empty; a PVC that still holds cluster data causes the new follower to loop indefinitely on "node is not empty" until a manual `flushall` + `cluster reset hard` is run on that node.

List PVCs before deleting to confirm the names on your install:

```bash
kubectl -n lumenvox get pvc | grep redis-cluster
```

Delete by ordinal, e.g. for a follower scale-in that removed follower-2:

```bash
kubectl delete pvc \
  external-services-redis-cluster-follower-external-services-redis-cluster-follower-2 \
  node-conf-external-services-redis-cluster-follower-2 \
  -n lumenvox
```

Note: the data PVC name repeats the cluster name twice — this is expected, not a typo.

> **Note:** Confirm PDB behavior under node drain in your environment before relying on `maxUnavailable: 1` for production drain operations.

### Upgrading from an earlier chart version

> **Warning:** Upgrading from a chart version that used the built-in StatefulSet replaces the Redis cluster. The operator takes ownership and creates a new cluster from scratch — existing cache data is not migrated. Plan for a maintenance window, coordinate with services that depend on Redis, and be prepared for a cold cache on restart.

After the upgrade completes, delete the orphaned StatefulSet PVCs manually (Helm does not remove them):

```bash
kubectl delete pvc \
  redis-cluster-data-external-services-redis-cluster-0 \
  redis-cluster-data-external-services-redis-cluster-1 \
  redis-cluster-data-external-services-redis-cluster-2 \
  redis-cluster-data-external-services-redis-cluster-3 \
  redis-cluster-data-external-services-redis-cluster-4 \
  redis-cluster-data-external-services-redis-cluster-5 \
  -n lumenvox --ignore-not-found
```

## Note for EKS: storage for the LumenVox stack itself

This chart covers the four external services only. The LumenVox stack additionally needs shared `ReadWriteMany` storage for its model files (used by the resource, asr, neural-tts, and itn services). On EKS this is provided by Amazon EFS: install the AWS EFS CSI driver, create an EFS file system in the same VPC as the cluster, and create a StorageClass backed by it. Without this, the model-serving pods will stay in `Pending` even though the databases are healthy. This is part of the LumenVox chart setup, not this chart. See the [Setup in Amazon Kubernetes Services (EKS)](https://privatecloud.capacity.com/article/602633/setup-in-amazon-kubernetes-services--eks-) guide on the Capacity private cloud documentation portal, which walks through installing the AWS EFS CSI driver, creating the EFS file system with mount targets in the cluster VPC, and defining the `efs-sc` StorageClass. Once EFS is in place, set `global.lumenvox.enforceReadWriteMany: true` and the matching `storageClass` value in the LumenVox chart values to point the model-serving pods at it.

## Production hardening

The chart handles connectivity and credentials. One additional control is recommended for production or regulated deployments — it is intentionally left to the platform team because the right configuration depends on the cluster:

- **NetworkPolicy**: restrict ingress to each database service to only LumenVox pods (matched by label selector). Without this, any pod in the namespace can open a connection to MongoDB, PostgreSQL, RabbitMQ, or Redis.

Redis Cluster mode ships three resilience features out of the box:

- **PodDisruptionBudget**: a PDB with `maxUnavailable: 1` is included in the chart (gated on `redis.clusterMode.enabled`). It prevents simultaneous eviction of multiple cluster nodes during node drains or rolling node upgrades.
- **Pod anti-affinity**: the RedisCluster CR includes a preferred (`weight: 100`) anti-affinity rule on `kubernetes.io/hostname` for both leader and follower pods, so the scheduler spreads the six Redis pods across nodes when capacity allows. This is soft — scheduling still proceeds on smaller clusters where strict placement cannot be satisfied.
- **Pod security context**: all Redis cluster pods run as a non-root user. The RedisCluster CR sets `spec.securityContext` to `runAsUser: 1000` and `fsGroup: 1000`.

## Install the LumenVox chart

Before installing, you will need a cluster GUID and license key from LumenVox and a values file configured for your environment.

Add the official LumenVox Helm repository:

```bash
helm repo add lumenvox https://lumenvox.github.io/helm-charts
helm repo update
```

Then install into the same namespace:

```bash
helm install lumenvox lumenvox/lumenvox -f my-lumenvox-values.yaml -n lumenvox --create-namespace
```

For EKS-specific setup (EFS storage, IAM configuration, and the required LumenVox chart values), see the [Setup in Amazon Kubernetes Services (EKS)](https://privatecloud.capacity.com/article/602633/setup-in-amazon-kubernetes-services--eks-) guide on the Capacity private cloud documentation portal. The chart source and release notes are in the [lumenvox/helm-charts](https://github.com/lumenvox/helm-charts) repository.

## Uninstall

```bash
helm uninstall external-services -n lumenvox
```

Two things are not removed automatically:

1. **PVCs** — all four standalone PVCs are annotated with `helm.sh/resource-policy: keep`, so Kubernetes will not delete them when the release is uninstalled. Your data is preserved by design. To remove the PVCs and delete the data:

```bash
kubectl delete pvc external-services-mongodb-pvc external-services-postgresql-pvc external-services-rabbitmq-pvc external-services-redis-pvc -n lumenvox --ignore-not-found
```

In Redis Cluster mode the operator-managed PVCs are not part of the Helm
release manifest — the operator creates them, so `helm uninstall` does not
remove them. They do carry `meta.helm.sh/release-name` annotations and
`managed-by=Helm` labels, copied from the CR by the operator; this metadata
does not imply Helm ownership. Delete them manually before reinstalling:

```bash
# List first to confirm names
kubectl -n lumenvox get pvc -l cluster=external-services-redis-cluster

kubectl delete pvc -l cluster=external-services-redis-cluster \
  -n lumenvox --ignore-not-found
```

Reusing old cluster volumes with a fresh install causes the operator's join procedure to fail — always delete them before reinstalling.