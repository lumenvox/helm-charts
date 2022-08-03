# LumenVox Kubernetes Helm Charts

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/lumenvox)](https://artifacthub.io/packages/search?repo=lumenvox)

This code is provided as-is with no warranties
 
## Usage

[Helm](https://helm.sh/) must be installed to use charts. Please refer
to Helm's [documentation](https://helm.sh/docs/) to get started

## Prerequisites

* Kubernetes 1.19+
* Helm 3+

## Get Repo Info

Once Helm is set up correctly, add the repo as shown here:

```shell
helm repo add lumenvox https://lumenvox.github.io/helm-charts
helm repo update
```
_See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation._

You can then run `helm search repo lumenvox` to see the charts

_See [helm search repo](https://helm.sh/docs/helm/helm_search_repo/) for details_

## Contributing

We'd love to have you contribute! Please contact us for details

## LumenVox Chart

The LumenVox chart serves as a root chart through which various
combinations of products can be managed. Using this chart, you
can install our Speech stack, our Voice Biometrics stack, or
both.

To install the LumenVox chart using Helm, you should contact
LumenVox first and obtain license and configuration information
that is needed before you can start.

You will also need to provision the following, ideally in a
hosted cloud environment for production, but locally can be
used during testing or development:

* Postgres Database
* MongoDB Database
* Redis
* RabbitMQ

_See the **Dependencies** section below for important details_

### Configuration

You will need to work with your LumenVox account manager and the support
team before running LumenVox application in Kubernetes. This is needed
to provide you with the necessary license configuration as well as
overall system configuration steps

To see all configurable options, visit the chart's values.yaml,
or run the following:

```shell
helm show values lumenvox/lumenvox
```

### Installation

```shell
helm install lumenvox lumenvox/lumenvox -f my-lumenvox-values.yaml -n lumenvox
```

_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

### Uninstallation

```shell
helm delete lumenvox
```

This removes all the Kubernetes components associated with the chart and
deletes the release.

## Voice-Biometrics Chart

This chart can be used to install the voice biometrics stack.
This has been migrated to a subchart of the LumenVox chart,
and it will be deprecated in the near future.

To install LumenVox Voice Biometrics using Helm, you should
contact LumenVox first and obtain license and configuration
information that is needed before you can start.

You will also need to provision the following, ideally in a
hosted cloud environment for production, but locally can be
used during testing or development:

* Postgres Database
* MongoDB Database
* Redis
* RabbitMQ

_See the **Dependencies** section below for important details_

### Configuration

You will need to work with your LumenVox account manager and the support
team before running LumenVox application in Kubernetes. This is needed
to provide you with the necessary license configuration as well as
overall system configuration steps

To see all configurable options, visit the chart's values.yaml,
or run the following:

```shell
helm show values lumenvox/voice-biometrics
```

### Installation

```shell
helm install lumenvox-vb lumenvox/voice-biometrics -f my-lumenvox-values.yaml -n lumenvox
```
 
_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

### Uninstallation

```shell
helm delete lumenvox-vb
```

## Dependencies

The following dependencies can optionally be installed:

```shell
  - name: "redis"
    version: 15
    repository: "https://charts.bitnami.com/bitnami"

  - name: "mongodb"
    version: 10
    repository: "https://charts.bitnami.com/bitnami"

  - name: "rabbitmq"
    version: 8
    repository: "https://charts.bitnami.com/bitnami"

  - name: "postgresql"
    version: 10
    repository: "https://charts.bitnami.com/bitnami"

  - name: "grafana"
    version: 7
    repository: "https://charts.bitnami.com/bitnami"
```
> Note that these dependencies are provided for setting up a test environment only.

We recommend that when creating a production environment, you provision your
own cloud-hosted services to replace these test dependencies, which are not
configured for persistence or scale.

Each of these dependencies can be disabled in the `values.yaml` file in their
respective sections. For example, to disable the redis dependency when using your
own, set the `redis.enabled` setting to false in your `values.yaml` file. The
same can be done for all of these dependencies, allowing you to easily use the
LumenVox Helm Charts in either test or production configurations. 

To configure Grafana for monitoring, when setting up the test environment
with the optional dependencies enabled, log into Grafana and specify a
dashboard to use with Prometheus monitoring, for example:

* 12740 (Select Prometheus at the bottom) - Kubernetes Monitoring Dashboard

## Testing Environment: Minimum Resource Requirements

Provided below are the minimum requirements for a testing/lab environment. For
production environments, please contact LumenVox for assistance with sizing.

### Cluster Resources

* LumenVox Speech: minimum of 2 nodes with at least 8CPUs and 8GB memory each.
* LumenVox Voice Biometrics: minimum of 1 node with at least 4CPUs and 16GB memory.

### External Resources

|                    | RabbitMQ | MongoDB | Postgres | Redis | Persistent Storage |
|--------------------|----------|---------|----------|-------|--------------------|
| **CPU**            | 1        | 2       | 2        | -     | -                  |
| **Memory**         | 2GB      | 16GB    | 8GB      | 5GB   | -                  |
| **Boot Disk Size** | 10GB     | 10GB    | 10GB     | -     | -                  |
| **Data Storage**   | -        | 300GB   | 30GB     | -     | 300 GB             |
