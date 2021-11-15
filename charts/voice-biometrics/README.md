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


## Uninstalling the Chart

To uninstall/delete the chart named `lumenvox-vb`:

```shell
helm uninstall lumenvox-vb
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

_See [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) for command documentation._


## Configuration

| Parameter                                 | Description                                   | Default                                                 |
|-------------------------------------------|-----------------------------------------------|---------------------------------------------------------|
| `hostnameSuffix`                          | Desired ingress suffix                        | `testmachine.com`                                       |
| `licensing.clusterGuid`                   | License GUID obtained from LumenVox account   | `GET-CLUSTER-GUID-FROM-LUMENVOX`                        |
| `licensing.reportFreqMins`                | License reporting frequency in minutes        | `1440`                                                  |
| `licensing.reportSyncHour`                | License preferred sync hour                   | `1`                                                     |
| `licensing.reportSyncMin`                 | License preferred sync minute                 | `0`                                                     |
| `redis.enabled`                           | Whether Redis helm chart is installed         | `true`                                                  |
| `redis.auth.password`                     | Redis password                                | `iJ3WX7icYL4j3d`                                        |
| `postgres.enabled`                        | Whether Postgres helm chart is installed      | `true`                                                  |
| `postgres.connection.url`                 | Postgres database URL                         | `lumenvox-postgresql.lumenvox`                          |
| `postgres.connection.port`                | Postgres connection Port                      | `5432`                                                  |
| `postgres.connection.user`                | Postgres username                             | `lvuser`                                                |
| `postgres.connection.password`            | Postgres password                             | `iJ3WX7icYL4j3d`                                        |
| `postgres.user`                           | Common username for postgres activity         | `lvuser`                                                |
| `postgres.password`                       | Common password for postgres activity         | `iJ3WX7icYL4j3d`                                        |
| `postgres.postgresDb`                     | Name of the main postgres database            | `postgres`                                              |
| `mongodb.enabled`                         | Whether MongoDB helm chart is installed       | `true`                                                  |
| `mongodb.auth.rootUser`                   | MongoDB root user                             | `lvuser`                                                |
| `mongodb.auth.rootPassword`               | MongoDB root password                         | `iJ3WX7icYL4j3d`                                        |
| `rabbitmq.enabled`                        | Whether RabbitMQ helm chart is installed      | `true`                                                  |
| `rabbitmq.connection.url`                 | RabbitMQ connection URL                       | `rabbitmq-url`                                          |
| `rabbitmq.connection.port`                | RabbitMQ connection Port                      | `5672`                                                  |
| `rabbitmq.connection.user`                | RabbitMQ username                             | `lvuser`                                                |
| `rabbitmq.connection.password`            | RabbitMQ password                             | `iJ3WX7icYL4j3d`                                        |
| `traefik.enabled`                         | Whether Traefik ingress helm chart installed  | `true`                                                  |
| `traefik.ingress.k8s.dashboardEnabled`    | Kubernetes dashboard ingress installed        | `true`                                                  |
| `web.commonUser`                          | Common username for web activity              | `lvuser`                                                |
| `web.commonPass`                          | Common password for web activity              | `iJ3WX7icYL4j3d`                                        |
| `logging.enableElasticsearch`             | Whether Elasticsearch output is enabled       | `false`                                                 |
| `logging.defaultLevel`                    | Default logging verbosity level               | `Information`                                           |
| `logging.overrideMicrosoftLevel`          | Microsoft override verbosity level            | `Information`                                           |
| `logging.overrideSystemLevel`             | System override verbosity level               | `Information`                                           |
| `logging.overrideGrpcLevel`               | gRPC override verbosity level                 | `Information`                                           |
| `imagePullSecrets`                        | Optional login credentials for image repo     | `nil`                                                   |
| `encryption.masterEncryptionKey`          | System master encryption key                  | `replace-this-master-encryption-key`                    |
| `encryption.useEncryption`                | Whether system-wide encryption is enabled     | `true`                                                  |
| `grafana.enabled`                         | Whether Grafana helm chart is installed       | `true`                                                  |
| `grafana.adminUser`                       | Grafana admin user                            | `lvuser`                                                |
| `grafana.adminPassword`                   | Grafana admin password                        | `iJ3WX7icYL4j3d`                                        |
| `prometheus.enabled`                      | Whether Prometheus helm chart is installed    | `true`                                                  |
