# LumenVox Kubernetes Helm Charts

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/lumenvox)](https://artifacthub.io/packages/search?repo=lumenvox)

This code is provided as-is with no warranties
 
## Usage

[Helm](https://helm.sh/) must be installed to use charts. Please refer
to Helm's [documentation](https://helm.sh/docs/) to get started

## Prerequisites

* Kubernetes 1.33 (and below)
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

The LumenVox chart serves as a root chart through which the LumenVox Speech
stack can be managed, including ASR, TTS, and other voice AI services.

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

### NOTE
When making use of a custom DNS hostname suffix, please be sure to enter the
full suffix including the leading dot, as shown in the example below:

```yaml
global:
  hostnameSuffix: ".domain-name.com"
```

To see all configurable options, visit the chart's values.yaml,
or run the following:

```shell
helm show values lumenvox/lumenvox
```

### Installation

```shell
helm install lumenvox lumenvox/lumenvox -f my-lumenvox-values.yaml -n lumenvox --create-namespace
```

_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

### Uninstallation

```shell
helm uninstall lumenvox -n lumenvox
```

This removes all the Kubernetes components associated with the chart and
deletes the release.

## Voice-Biometrics Chart

**Note**: This standalone chart is deprecated and not actively maintained. Voice Biometrics functionality is currently not supported for new deployments. If you have specific Voice Biometrics requirements, please contact LumenVox to discuss your needs.

## Dependencies

For testing and development environments, LumenVox provides a Docker Compose configuration that includes the required external services. See the [external-services repository](https://github.com/lumenvox/external-services) for installation instructions.

The Docker Compose setup includes:

```yaml
dependencies:
  - MongoDB 8.2
  - PostgreSQL 17.5
  - RabbitMQ 4.1.8 (with management interface)
  - Redis 8.2.4
```

> **Important**: These dependencies are provided for setting up a test environment only.

We recommend that when creating a production environment, you provision your
own cloud-hosted services to replace these test dependencies, which are not
configured for persistence or scale.

For production, use your own managed database services and configure the connection details
in the main `lumenvox` chart values. 

To configure Grafana for monitoring in test environments with the Docker Compose dependencies,
log into Grafana and add Prometheus as a data source, then import a Kubernetes monitoring dashboard.
For example:

* Dashboard ID 12740: Kubernetes Monitoring Dashboard (select Prometheus as the data source)

## Testing Environment: Minimum Resource Requirements

Provided below are the minimum requirements for a testing/lab environment. For
production environments, please contact LumenVox for assistance with sizing.

### Cluster Resources

* LumenVox Speech: minimum of 3 nodes with at least 8 CPUs and 16GB memory each

### External Resources

|                    | RabbitMQ | MongoDB | Postgres | Redis | Persistent Storage |
|--------------------|----------|---------|----------|-------|--------------------|
| **CPU**            | 1        | 2       | 2        | -     | -                  |
| **Memory**         | 2GB      | 16GB    | 8GB      | 5GB   | -                  |
| **Boot Disk Size** | 10GB     | 10GB    | 10GB     | -     | -                  |
| **Data Storage**   | -        | 300GB   | 30GB     | -     | 300 GB             |
