# Device Lobby Helm Chart

This chart deploys the Device Lobby to a Kubernetes cluster.

> The implementation of the Helm chart is right now the bare minimum to get it to work.

## Usage in Teknoir platform
Use the HelmChart to deploy the Device Lobby to a Namespace.

```yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: device-lobby
  namespace: default
spec:
  repo: https://teknoir.github.io/device-lobby-helm
  chart: device-lobby
  targetNamespace: default
  valuesContent: |-
    # Models to be installed via a shared path
    models: []
```

## Example values.yaml

```yaml
models:
- name: rtdetr
  image:  us-docker.pkg.dev/teknoir/gcr.io/rtdetr-device-lobby:latest
- name: up_down_classifier
  image:  us-docker.pkg.dev/teknoir/gcr.io/up-down-classifier-device-lobby:latest
```

## Adding the repository

```bash
helm repo add teknoir-device-lobby https://teknoir.github.io/device-lobby-helm/
```

## Installing the chart

```bash
helm install device-lobby teknoir-device-lobby/device-lobby -f values.yaml
```