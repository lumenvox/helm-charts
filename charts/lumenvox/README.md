# Configuration
### General Configuration
| Parameter                                          | Description                                                     | Default                            |
|----------------------------------------------------|-----------------------------------------------------------------|------------------------------------|
| `timezone`                                         | Timezone for logs. Examples: UTC, America/New_York, Europe/Rome | `UTC`                              |
| `lumenvox-common.licensing.clusterGuid`            | License GUID obtained from LumenVox account                     | `"GET-CLUSTER-GUID-FROM-LUMENVOX"` |
| `global.hostnameSuffix`                            | Desired ingress suffix                                          | `".testmachine.com"`               |
| `global.lumenvox.ingress.className`                | Ingress class name                                              | `nginx`                            |
| `global.lumenvox.deploymentReconnectionTimeoutSec` | Deployment database connection timeout                          | `30`                               |
| `global.lumenvox.enableAudit`                      | Whether to enable audit logging                                 | `false`                            |
| `global.lumenvox.enforceLimits`                    | Whether to enforce resource limits                              | `false`                            |
| `global.image.pullPolicy`                          | Pull policy when installing cluster                             | `IfNotPresent`                     |
| `global.image.tag`                                 | Default image tag                                               | `":6.3"`                           |

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
| Parameter                      | Description                               | Default                            |
|--------------------------------|-------------------------------------------|------------------------------------|
| `global.redis.enableTLS`       | Connect to Redis with TLS                 | `false`                            |
| `global.redis.connection.url`  | URL for Redis connection                  | `"lumenvox-redis-master.lumenvox"` |
| `global.redis.connection.port` | Port for Redis connection                 | `6379`                             |
| `global.lumenvox.redisTtl`     | Time to live for certain objects in Redis | `3h`                               |

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
| Parameter                                        | Description                               | Default                          |
|--------------------------------------------------|-------------------------------------------|----------------------------------|
| `global.postgresql.connection.url`               | URL for Postgres connection               | `"lumenvox-postgresql.lumenvox"` | 
| `global.postgresql.connection.port`              | Port for Postgres connection              | `5432`                           |
| `global.postgresql.connection.user`              | User for RabbitMQ connection              | `"lvuser"`                       |
| `global.postgresql.connection.ssl.mode`          | SSL Connection Mode: disable or verify-ca | `"disable"`                      |
| `global.postgresql.connection.ssl.caCertificate` | CA certificate to verify server           | `""`                             |

By default, the chart will create a Postgres instance. To switch to using an external instance, you must set
`lumenvox-common.postgresql.enabled` to `false` and then update the relevant values under
`global.postgresql.connection`.

The installation expects an existing secret, `postgres-existing-secret`. This secret should contain 2 fields:
`postgresql-password` (the password for the database user) and `postgresql-postgres-password` (the password for the root
user).

To enable TLS, set `global.postgresql.connection.ssl.mode` to `verify-ca`. This will cause the client to verify the
certificate returned by the Postgres server.

If you would like to verify against a self-signed certificate, you should base64-encode the signing certificate and
store it in `global.postgresql.connection.ssl.caCertificate`. To encode it, the following command should work:
```shell
base64 -w 0 ca.crt
```

### Trusted Root CA Configuration
| Parameter                  | Description                                 | Default |
|----------------------------|---------------------------------------------|---------|
| `global.extraRootCaCerts`  | If `true`, read extra root CAs from secret  | `false` |

When receiving a grammar referenced via URL, the grammar manager will fetch from the specified
URL. To support fetching from servers signed with custom certificate authorities, you may add
a set of extra root CAs to trust.

To use this feature, start with a file containing the set of root CA certificates, `extra_cas.pem`:
```text
-----BEGIN CERTIFICATE-----
...
...
...
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
...
...
...
-----END CERTIFICATE-----
```

This file should be added as a secret `extra-root-ca-secret` with the field `extra-root-ca-certs`:
```shell
kubectl create secret generic extra-root-ca-secret -n lumenvox --from-file=extra-root-ca-certs=./extra_cas.pem
```

Once the secret has been created, set `global.extraRootCaCerts` to true.

### Product Selection
| Parameter                       | Description                                 | Default |
|---------------------------------|---------------------------------------------|---------|
| `global.enabled.lumenvoxSpeech` | If `true`, enable LumenVox Speech           | `false` |
| `global.enabled.lumenvoxVb`     | If `true`, enable LumenVox Voice Biometrics | `false` |

### ASR Language Configuration
| Parameter                  | Description                      | Default   |
|----------------------------|----------------------------------|-----------|
| `global.asrLanguages`      | List of ASR languages to install | `[]`      |
| `global.asrDefaultVersion` | Default ASR model version        | `"4.1.0"` |
| `global.customAsrModels`   | Custom ASR models                | `[]`      |

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

To specify custom ASR models, you must list the models under `global.customAsrModels`. The objects in the list must
specify a name; specifying a version is optional.
```yaml
global:
  customAsrModels:
    - name: "custom1"
```

### ASR Cache Configuration
| Parameter                           | Description                            | Default |
|-------------------------------------|----------------------------------------|---------|
| lumenvox-speech.asr.cacheMaxEntries | Maximum number of entries in the cache | `500`   |
| lumenvox-speech.asr.cacheMaxSizeMb  | Maximum size of the cache in MB        | `1000`  |

The ASR utilizes a cache to speed up processing of frequently used grammars. To configure the
maximum size of the cache, both in number of entries and in size (MB), the above values may
be utilized.

### ITN Language Configuration
| Parameter                  | Description                      | Default |
|----------------------------|----------------------------------|---------|
| `global.itnLanguages`      | List of ITN languages to install | `[]`    |

To specify ITN languages, you must list your desired languages under `global.itnLanguages`. For example:
```yaml
global:
  itnLanguages:
    - name: "en"
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
        - name: "lindsey"
          version: "1.3"
```

The Neural TTS is active by default. To use the legacy TTS, you can disable the Neural TTS per language. For example,
to run the legacy TTS for American English:
```yaml
global:
  ttsLanguages:
    - name: "en_us"
      legacyEnabled: true
      voices:
        - name: "chris"
```

### VB Language Configuration
| Parameter                 | Description                     | Default    |
|---------------------------|---------------------------------|------------|
| `global.vbLanguages`      | List of VB languages to install | `[]`       |
| `global.vbDefaultVersion` | Default VB model version        | `"2.1.13"` |

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

### Grammar Manager Configuration
| Parameter                                       | Description                | Default        |
|-------------------------------------------------|----------------------------|----------------|
| `lumenvox-speech.grammar.maxGrammarTransitions` | Maximum grammar complexity | `0` (disabled) |

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
For ingress into the Speech API or Biometric APIs, the cluster expects a pre-existing secret `speech-tls-secret`. For a
temporary testing example, run the following commands to generate one:
```shell
openssl genrsa -out server.key 2048
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650 -addext "subjectAltName = DNS:speech-api.testmachine.com, DNS:biometric-api.testmachine.com"
kubectl create secret tls speech-tls-secret --key server.key --cert server.crt
```
The second command will prompt you for some information; all fields can be left blank, as the necessary information is
contained in the SAN. You should replace `.testmachine.com` with whatever you have specified in `global.hostnameSuffix`.

Any clients making requests to the Speech or Biometrics APIs should be written to trust the certificate in the secret.

## Linkerd Service Mesh

A service mesh is required to provide load-balancing functionality across services, and the default LumenVox
configuration requires [linkerd](https://linkerd.io/2.12/getting-started/), which must be installed and configured
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
