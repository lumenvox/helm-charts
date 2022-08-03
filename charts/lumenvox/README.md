# Configuration
### General Configuration
| Parameter                                          | Description                                                     | Default                            |
|----------------------------------------------------|-----------------------------------------------------------------|------------------------------------|
| `timezone`                                         | Timezone for logs. Examples: UTC, America/New_York, Europe/Rome | `UTC`                              |
| `lumenvox-common.licensing.clusterGuid`            | License GUID obtained from LumenVox account                     | `"GET-CLUSTER-GUID-FROM-LUMENVOX"` |
| `global.hostnameSuffix`                            | Desired ingress suffix                                          | `"testmachine.com"`                |
| `global.lumenvox.ingress.className`                | Ingress class name                                              | `nginx`                            |
| `global.lumenvox.deploymentReconnectionTimeoutSec` | Deployment database connection timeout                          | `30`                               |
| `global.lumenvox.enableAudit`                      | Whether to enable audit logging                                 | `false`                            |
| `global.lumenvox.enforceLimits`                    | Whether to enforce resource limits                              | `false`                            |
| `global.image.pullPolicy`                          | Pull policy when installing cluster                             | `IfNotPresent`                     |
| `global.image.tag`                                 | Default image tag                                               | `":3.2"`                           |

### Persistent Volume Configuration
| Parameter      | Description                                                                                                                 | Default    |
|----------------|-----------------------------------------------------------------------------------------------------------------------------|------------|
| `platform`     | Cluster platform: cloud or minikube. Used for persistent volume setup.                                                      | `minikube` |
| `provider`     | Platform provider: used for provider-specific optimizations. Currently only used for AWS EFS; specify `"aws"` in this case. | `""`       |
| `volumeRoot`   | Root of persistent data location. To specify the root of the file system, use `"/."`                                        | `"/data"`  |
| `volumeServer` | IP address of persistent data filesystem. Ignored for minikube.                                                             | `""`       |

### Dependency Toggles
| Parameter                            | Description                                                                                          | Default |
|--------------------------------------|------------------------------------------------------------------------------------------------------|---------|
| `lumenvox-common.rabbitmq.enabled`   | If `true`, install an in-cluster instance of RabbitMQ. Set to `false` to use an external instance.   | `true`  |
| `lumenvox-common.redis.enabled`      | If `true`, install an in-cluster instance of Redis. Set to `false` to use an external instance.      | `true`  |
| `lumenvox-common.mongodb.enabled`    | If `true`, install an in-cluster instance of MongoDB. Set to `false` to use an external instance.    | `true`  |
| `lumenvox-common.postgresql.enabled` | If `true`, install an in-cluster instance of PostgreSQL. Set to `false` to use an external instance. | `true`  |

### RabbitMQ Configuration
| Parameter                         | Description                   | Default                        |
|-----------------------------------|-------------------------------|--------------------------------|
| `global.rabbitmq.enableTLS`       | Connect to RabbitMQ with TLS  | `false`                        |
| `global.rabbitmq.connection.url`  | URL for RabbitMQ connection   | `"lumenvox-rabbitmq.lumenvox"` |
| `global.rabbitmq.connection.port` | Port for RabbitMQ connection  | `5672`                         |
| `global.rabbitmq.connection.user` | User for RabbitMQ connection  | `"lvuser"`                     |

By default, the chart will create a RabbitMQ instance. To switch to using an external instance, you must set
`lumenvox-common.rabbitmq.enabled` to `false` and then update the relevant values under `global.rabbitmq.connection`.

The installation expects an existing secret, `rabbitmq-existing-secret`. This secret should contain 1 field,
`rabbitmq-password`, the password for the instance.

### Redis Configuration
| Parameter                      | Description               | Default                            |
|--------------------------------|---------------------------|------------------------------------|
| `global.redis.enableTLS`       | Connect to Redis with TLS | `false`                            |
| `global.redis.connection.url`  | URL for Redis connection  | `"lumenvox-redis-master.lumenvox"` |
| `global.redis.connection.port` | Port for Redis connection | `6379`                             |

By default, the chart will create a Redis instance. To switch to using an external instance, you must set
`lumenvox-common.redis.enabled` to `false` and then update the relevant values under `global.redis.connection`.

The installation expects an existing secret, `redis-existing-secret`. This secret should contain 1 field,
`redis-password`, the password for the instance.

### MongoDB Configuration
| Parameter                        | Description                      | Default                       |
|----------------------------------|----------------------------------|-------------------------------|
| `global.mongodb.connection.url`  | URL for MongoDB connection       | `"lumenvox-mongodb.lumenvox"` |
| `global.mongodb.connection.port` | Port for MongoDB connection      | `27017`                       |
| `global.mongodb.atlas`           | Enable for MongoDB Atlas support | `false`                       |

By default, the chart will create a MongoDB instance. To switch to using an external instance, you must set
`lumenvox-common.mongodb.enabled` to `false` and then update the relevant values under `global.mongodb.connection`.

The installation expects an existing secret, `mongodb-existing-secret`. This secret should contain 1 field,
`mongodb-root-password`, which contains the MongoDB root password.

### PostgreSQL Configuration
| Parameter                           | Description                  | Default                          |
|-------------------------------------|------------------------------|----------------------------------|
|  `global.postgresql.connection.url` | URL for Postgres connection  | `"lumenvox-postgresql.lumenvox"` | 
| `global.postgresql.connection.port` | Port for Postgres connection | `5432`                           |
| `global.postgresql.connection.user` | User for RabbitMQ connection | `"lvuser"`                       |

By default, the chart will create a Postgres instance. To switch to using an external instance, you must set
`lumenvox-common.postgresql.enabled` to `false` and then update the relevant values under
`global.postgresql.connection`.

The installation expects an existing secret, `postgres-existing-secret`. This secret should contain 2 fields:
`postgresql-password` (the password for the database user) and `postgresql-postgres-password` (the password for the root
user).

### Product Selection
| Parameter                       | Description                                 | Default |
|---------------------------------|---------------------------------------------|---------|
| `global.enabled.lumenvoxSpeech` | If `true`, enable LumenVox Speech           | `false` |
| `global.enabled.lumenvoxVb`     | If `true`, enable LumenVox Voice Biometrics | `false` |

### ASR Language Configuration
| Parameter                  | Description                      | Default |
|----------------------------|----------------------------------|---------|
| `global.asrLanguages`      | List of ASR languages to install | `[]`    |
| `global.asrDefaultVersion` | Default ASR model version        | `"2.2"` |

To specify ASR languages, you must list your desired languages under `global.asrLanguages`. The list items must include
a name; specifying a version is optional. If the version is omitted, the one specified in `global.asrDefaultVersion`
will be used. For example, the following configuration would enable English 1.0.0 and Spanish 2.2.0:
```yaml
global:
  asrDefaultVersion: "2.2.0"
  asrLanguages:
    - name: "en"
      version: "1.0.0"
    - name: "es"
```

### TTS Language Configuration
| Parameter                  | Description                   | Default |
|----------------------------|-------------------------------|---------|
| `global.ttsLanguages`      | List of TTS voices to install | `[]`    |
| `global.ttsDefaultVersion` | Default TTS voice version     | `"1.0"` |

To specify TTS voices, you must list your desired voices under `global.ttsLanguages`. Each model will use the version
specified in `global.vbDefaultVersion` by default, but this may be overridden by including the version under
each language. The list items are composed of a region/language and a list of voices. For example, the following
configuration will install Chris 1.0 and Lindsey 1.3, both from the English-US group:
```yaml
global:
  ttsDefaultVersion: "1.0"
  ttsLanguages:
    - name: "en_us"
      voices:
        - name: "chris"
          sampleRate: "8"
        - name: "lindsey"
          sampleRate: "8"
          version: "1.3"
```

### VB Language Configuration
| Parameter                 | Description                     | Default   |
|---------------------------|---------------------------------|-----------|
| `global.vbLanguages`      | List of VB languages to install | `[]`      |
| `global.vbDefaultVersion` | Default VB model version        | `"2.1.1"` |

To specify VB languages, you must list your desired languages under `global.vbLanguages`. Each model will use the
version specified in `global.vbDefaultVersion` by default, but this may be overridden by including the version under
each language. For example, both of the following configurations would enable US English 2.1.1:
```yaml
global:
  vbDefaultVersion: "2.1.1"
  vbLanguages:
    - name: "en_US"
```
```yaml
global:
  vbDefaultVersion: "1.2"
  vbLanguages:
    - name: "en_US"
      version: "2.1.1"
```

# Notes
## Image Versioning
Our images make use of `MAJOR.MINOR.PATCH` semantic versioning. By default, the chart matches the major and minor
versions while pulling the most recent patch version. If you would like to have a fixed set of images, you must override
`global.images.tag` with a version including the patch number you want to run.

To use different image tag policies on different sets of images, you may utilize `lumenvox-common.images.tag`,
`lumenvox-speech.images.tag`, and `lumenvox-speech.images.tag`. These values will override the global image tag in the
relevant charts.

## Persistent Volume Configuration
Depending on the location of your cluster, the configuration for persistent volumes will differ. For local clusters on
minikube, the defaults should suffice; they will map persistent volumes to directories under `/data`. To change the root
location, set the `volumeRoot` value.

For installations in the cloud, you will likely be using an NFS server. In this case, you must set `volumeServer`
to the IP address of the server, set `platform` to `"cloud"`, and set `volumeRoot` to the appropriate root
location.

## Encryption
To set the master encryption key, create a secret `encryption-secret` with 1 field, `master-encryption-key`.

## TLS
For ingress into the Speech API, the cluster expects a pre-existing secret `speech-tls-secret`. For a temporary testing
example, run the following commands:
```shell
openssl genrsa -out server.key 2048
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650 -addext "subjectAltName = DNS:speech-api.testmachine.com"
kubectl create secret tls speech-tls-secret --key server.key --cert server.crt
```
The second command will prompt you for some information; all fields can be left blank, as the necessary information is
contained in the SAN. You should replace `testmachine.com` with whatever you have specified in `global.hostnameSuffix`.

Any clients making requests to the Speech API should be written to trust the certificate in the secret.

## Linkerd Service Mesh

A service mesh is required to provide load-balancing functionality across services, and the default LumenVox
configuration requires [linkerd](https://linkerd.io/2.11/getting-started/), which must be installed and configured
manually by the Kubernetes administrator.

> Note that linkerd may require certificates in order to operate
> correctly, and these certificates may require updates, which again
> should be handled by Kubernetes system administrators

Once installed, LumenVox services should automatically inject the linkerd proxy container into its pods to enable
load-balancing without needing further configuration.

It may be possible to configure and use a different service mesh, however this is beyond the scope of LumenVox' current
support policy.

Please contact LumenVox if you have specific questions relating to this.

This Helm Chart can be run without linkerd being installed, however load-balancing across the services
will not be performed, so scaling will be significantly impacted. This may be suitable for a test configuration, where
only one pod of each type is anticipated, however for production, using a Service Mesh is strongly recommended, with
linkerd being preferred.

We recommend installing linkerd before this Helm Chart.
