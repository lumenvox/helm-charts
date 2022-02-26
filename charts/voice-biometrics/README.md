# Voice Biometrics Helm Chart

* Installs the LumenVox Voice Biometrics suite of applications

## Get Repo Info

```shell
helm repo add lumenvox https://lumenvox.github.io/helm-charts
helm repo update
```

_See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation._


## Installing the Chart

To install the chart with the release name `lumenvox-vb`:

```shell
helm install lumenvox-vb lumenvox/voice-biometrics -f my-lumenvox-values.yaml
```
_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._


## Linkerd Service Mesh

A service mesh is required to provide load-balancing functionality
across services, and the default LumenVox configuration requires
[linkerd](https://linkerd.io/2.11/getting-started/), which must be
installed and configured manually by the Kubernetes administrator.

> Note that linkerd may require certificates in order to operate
> correctly, and these certificates may require updates, which again
> should be handled by Kubernetes system administrators

Once installed, LumenVox services should automatically inject the
linkerd proxy container into its pods to enable load-balancing
without needing further configuration.

It may be possible to configure and use a different service mesh,
however this is beyond the scope of LumenVox' current support
policy.

Please contact LumenVox if you have specific questions relating to
this.

This Voice Biometrics Helm Chart can be run without linkerd being
installed, however load-balancing across the services will not be
performed, so scaling will be significantly impacted. This may be
suitable for a test configuration, where only one pod of each type
is anticipated, however for production, using a Service Mesh is
strongly recommended, with linkerd being preferred.

We recommend installing linkerd before this Helm Chart.

## Uninstalling the Chart

To uninstall/delete the chart named `lumenvox-vb`:

```shell
helm uninstall lumenvox-vb
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

_See [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) for command documentation._


## Configuration

| Parameter                                   | Description                                  | Default                              |
|---------------------------------------------|----------------------------------------------|--------------------------------------|
| `hostnameSuffix`                            | Desired ingress suffix                       | `testmachine.com`                    |
| `lumenvox.deploymentStartDelaySeconds`      | Time to allow support services to start      | `0`                                  |
| `lumenvox.deploymentReconnectionTimeoutSec` | Deployment database connection timeout       | `30`                                 |
| `lumenvox.enforceLimits`                    | Whether to enforce resource limits           | `false`                              |
| `lumenvox.ingress.className`                | Optional service HTTP ingress className      | ``                                   |
| `licensing.clusterGuid`                     | License GUID obtained from LumenVox account  | `GET-CLUSTER-GUID-FROM-LUMENVOX`     |
| `licensing.reportFreqMins`                  | License reporting frequency in minutes       | `1440`                               |
| `licensing.reportSyncHour`                  | License preferred sync hour                  | `1`                                  |
| `licensing.reportSyncMin`                   | License preferred sync minute                | `0`                                  |
| `redis.enabled`                             | Whether Redis helm chart is installed        | `true`                               |
| `redis.auth.password`                       | Redis password                               | `iJ3WX7icYL4j3d`                     |
| `redis.connection.url`                      | Redis database URL                           | `lumenvox-redis-master.lumenvox`     |
| `redis.connection.port`                     | Redis connection port                        | `6379`                               |
| `postgresql.enabled`                        | Whether Postgres helm chart is installed     | `true`                               |
| `postgresql.connection.url`                 | Postgres database URL                        | `lumenvox-postgresql.lumenvox`       |
| `postgresql.connection.port`                | Postgres connection Port                     | `5432`                               |
| `postgresql.connection.user`                | Postgres username                            | `lvuser`                             |
| `postgresql.connection.password`            | Postgres password                            | `iJ3WX7icYL4j3d`                     |
| `postgresql.user`                           | Common username for postgres activity        | `lvuser`                             |
| `postgresql.password`                       | Common password for postgres activity        | `iJ3WX7icYL4j3d`                     |
| `postgresql.postgresqlDatabase`             | Name of the main postgres database           | `postgres`                           |
| `postgresql.postgresqlUsername`             | Common username for postgres activity        | `lvuser`                             |
| `postgresql.postgresqlPassword`             | Common password for postgres activity        | `iJ3WX7icYL4j3d`                     |
| `postgresql.existingSecret`                 | Location of password secret                  | `postgres-existing-secret`           |
| `mongodb.enabled`                           | Whether MongoDB helm chart is installed      | `true`                               |
| `mongodb.auth.rootUser`                     | MongoDB root user                            | `lvuser`                             |
| `mongodb.auth.rootPassword`                 | MongoDB root password                        | `iJ3WX7icYL4j3d`                     |
| `mongodb.auth.existingSecret`               | MongoDB root password secret                 | `mongodb-existing-secret`            |
| `rabbitmq.auth.existingPasswordSecret`      | RabbitMQ password secret                     | `rabbitmq-existing-secret`           |
| `mongodb.connection.url`                    | MongoDB connection url                       | `lumenvox-mongodb.lumenvox`          |
| `mongodb.connection.port`                   | MongoDB port                                 | `27017`                              |
| `rabbitmq.enabled`                          | Whether RabbitMQ helm chart is installed     | `true`                               |
| `rabbitmq.connection.url`                   | RabbitMQ connection URL                      | `lumenvox-rabbitmq.lumenvox`         |
| `rabbitmq.connection.port`                  | RabbitMQ connection Port                     | `5672`                               |
| `rabbitmq.connection.user`                  | RabbitMQ username                            | `lvuser`                             |
| `rabbitmq.connection.password`              | RabbitMQ password                            | `iJ3WX7icYL4j3d`                     |
| `traefik.enabled`                           | Whether Traefik ingress helm chart installed | `true`                               |
| `traefik.ingress.k8s.dashboardEnabled`      | Kubernetes dashboard ingress installed       | `true`                               |
| `web.commonUser`                            | Common username for web activity             | `lvuser`                             |
| `web.commonPass`                            | Common password for web activity             | `iJ3WX7icYL4j3d`                     |
| `logging.enableElasticsearch`               | Whether Elasticsearch output is enabled      | `false`                              |
| `logging.defaultLevel`                      | Default logging verbosity level              | `Information`                        |
| `logging.overrideMicrosoftLevel`            | Microsoft override verbosity level           | `Information`                        |
| `logging.overrideSystemLevel`               | System override verbosity level              | `Information`                        |
| `logging.overrideGrpcLevel`                 | gRPC override verbosity level                | `Information`                        |
| `imagePullSecrets`                          | Optional login credentials for image repo    | `nil`                                |
| `encryption.masterEncryptionKey`            | System master encryption key                 | `replace-this-master-encryption-key` |
| `encryption.useEncryption`                  | Whether system-wide encryption is enabled    | `true`                               |
| `grafana.enabled`                           | Whether Grafana helm chart is installed      | `true`                               |
| `grafana.adminUser`                         | Grafana admin user                           | `lvuser`                             |
| `grafana.adminPassword`                     | Grafana admin password                       | `iJ3WX7icYL4j3d`                     |
| `prometheus.enabled`                        | Whether Prometheus helm chart is installed   | `true`                               |

