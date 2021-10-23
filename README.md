# LumenVox Kubernetes Helm Charts

The code is provided as-is with no warranties

## Usage

[Helm](https://helm.sh/) must be installed to use charts. Please refer
to Helms's [documentation](https://helm.sh/docs/) to get started

Once Helm is set up correctly, add the repo as shown here:

```shell
helm repo add lumenvox https://lumenvox.github.io/helm-charts
```
You can then run `helm search repo lumenvox` to see the charts

## Contributing

We'd love to have you contribute! Please contact us for details

## Installing Voice-Biometrics

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

You will also need the credentials to allow your LumenVox
applications access to these resources

Once you have those details, copy or modify the values.yaml
file and create the application stack using:

```shell
helm install lumenvox-vb lumenvox/voice-biometrics -f my-lumenvox-values.yaml -n lumenvox
```


> **Note** this will install the applications into the `lumenvox`
> namespace, which is the default location.
 
Visit [lumenvox.com](https://lumenvox.com) for details of all our products
