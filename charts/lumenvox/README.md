## Configuration

| Parameter                                          | Description                                                            | Default                          |
|----------------------------------------------------|------------------------------------------------------------------------|----------------------------------|
| `global.hostnameSuffix`                            | Desired ingress suffix                                                 | `testmachine.com`                |
| `global.lumenvox.ingress.className`                | Ingress class name                                                     | `nginx`                          |
| `global.lumenvox.deploymentReconnectionTimeoutSec` | Deployment database connection timeout                                 | `30`                             |
| `global.lumenvox.enableAudit`                      | Whether to enable audit logging                                        | `false`                          |
| `global.lumenvox.enforceLimits`                    | Whether to enforce resource limits                                     | `false`                          |
| `global.image.pullPolicy`                          | Pull policy when installing cluster                                    | `IfNotPresent`                   |
| `global.image.tag`                                 | Default image tag                                                      | `:3.0.0`                         |
| `lumenvox-common.rabbitmq.enabled`                 | Create a local RabbitMQ instance                                       | `true`                           |
| `global.rabbitmq.connection.url`                   | URL for RabbitMQ connection                                            | `lumenvox-rabbitmq.lumenvox`     |
| `global.rabbitmq.connection.port`                  | Port for RabbitMQ connection                                           | `5672`                           |
| `global.rabbitmq.connection.user`                  | User for RabbitMQ connection                                           | `lvuser`                         |
| `lumenvox-common.redis.enabled`                    | Create a local Redis instance                                          | `true`                           |
| `global.redis.connection.url`                      | URL for Redis connection                                               | `lumenvox-redis-master.lumenvox` |
| `global.redis.connection.port`                     | Port for Redis connection                                              | `6379`                           |
| `lumenvox-common.mongodb.enabled`                  | Create a local MongoDB instance                                        | `true`                           |
| `global.mongodb.connection.url`                    | URL for MongoDB connection                                             | `lumenvox-mongodb.lumenvox`      |
| `global.mongodb.connection.port`                   | Port for MongoDB connection                                            | `27017`                          |
| `lumenvox-common.postgresql.enabled`               | Create a local Postgres instance                                       | `true`                           |
| `global.postgresql.connection.url`                 | URL for Postgres connection                                            | `lumenvox-postgresql.lumenvox`   |
| `global.postgresql.connection.port`                | Port for Postgres connection                                           | `5432`                           |
| `global.postgresql.connection.user`                | User for RabbitMQ connection                                           | `lvuser`                         |
| `global.enabled.lumenvoxSpeech`                    | Enable LumenVox Speech                                                 | `false`                          |
| `global.enabled.lumenvoxVb`                        | Enable LumenVox Voice Biometrics                                       | `false`                          |
| `global.enabled.lumenvoxCommon`                    | Enable LumenVox Common Components                                      | `true`                           |
| `global.asrLanguages`                              | List of ASR languages to install                                       | `[]`                             |
| `global.ttsLanguages`                              | List of TTS voices to install                                          | `[]`                             |
| `lumenvox-common.licensing.clusterGuid`            | License GUID obtained from LumenVox account                            | `GET-CLUSTER-GUID-FROM-LUMENVOX` |
| `platform`                                         | Cluster platform: cloud or minikube. Used for persistent volume setup. | `minikube`                       |
| `volumeRoot`                                       | Root of persistent data location.                                      | `data`                           |
| `volumeServer`                                     | IP address of persistent data filesystem. Ignored for minikube.        | `""`                             |
| `timezone`                                         | Timezone for logs. Examples: UTC, America/New_York, Europe/Rome        | `UTC`                            |

### MongoDB Configuration
By default, the chart will create a MongoDB instance. To switch to using an external instance, you must set
`lumenvox-common.mongodb.enabled` to `false` and then update the relevant values under `global.mongodb.connection`.

The installation expects an existing secret, `mongodb-existing-secret`. This secret should contain 1 field,
`mongodb-root-password`, which contains the MongoDB root password.

### Postgres Configuration
By default, the chart will create a Postgres instance. To switch to using an external instance, you must set
`lumenvox-common.postgresql.enabled` to `false` and then update the relevant values under
`global.postgresql.connection`.

The installation expects an existing secret, `postgres-existing-secret`. This secret should contain 2 fields:
`postgresql-password` (the password for the database user) and `postgresql-postgres-password` (the password for the root
user).

### RabbitMQ Configuration
By default, the chart will create a RabbitMQ instance. To switch to using an external instance, you must set
`lumenvox-common.rabbitmq.enabled` to `false` and then update the relevant values under `global.rabbitmq.connection`.

The installation expects an existing secret, `rabbitmq-existing-secret`. This secret should contain 1 field,
`rabbitmq-password`, the password for the instance.

### Redis Configuration
By default, the chart will create a Redis instance. To switch to using an external instance, you must set
`lumenvox-common.redis.enabled` to `false` and then update the relevant values under `global.redis.connection`.

The installation expects an existing secret, `redis-existing-secret`. This secret should contain 1 field,
`redis-password`, the password for the instance.

### ASR Language Configuration
To specify ASR languages, you must list your desired languages under `global.asrLanguages`. The list items must include
a name; specifying a version is optional. For example, the following configuration would enable English 1.0.0 and
Spanish (defaulting to latest):
```yaml
global:
  asrLanguages:
    - name: "en"
      version: "1.0.0"
    - name: "es"
```

### TTS Language Configuration
To specify TTS voices, you must list your desired voices under `global.ttsLanguages`. The list items are composed of a
name and a list of voices for that name. For example:
```yaml
global:
  ttsLanguages:
    - name: "en_us"
      voices:
        - name: "chris"
          sampleRate: "8"
```

### Persistent Volume Configuration
Depending on the location of your cluster, the configuration for persistent volumes will differ. For local clusters on
minikube, the defaults should suffice; they will map persistent volumes to directories under `/data`. To change the root
location, set the `volumeRoot` value.

For installations in the cloud, you will likely be using an NFS server. In this case, you must set `volumeServer`
to the IP address of the server, set `platform` to `"cloud"`, and set `volumeRoot` to the appropriate root
location.

### Encryption
To set the master encryption key, create a secret `encryption-secret` with 1 field, `master-encryption-key`.

### TLS
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