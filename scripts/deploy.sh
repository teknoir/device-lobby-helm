#!/usr/bin/env bash
set -e
#set -x

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -t|--target)
    TARGET="$2"
    shift
    shift
    ;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
esac
done

if [ -z "$TARGET" ]; then
    # Default target if none provided
    TARGET="victra-poc"
fi

export NAMESPACE=${TARGET}
if [[ $NAMESPACE == "demonstrations" ]] ; then
  CONTEXT="gke_teknoir-poc_us-central1-c_teknoir-dev-cluster"
  DOMAIN="teknoir.dev"
else
  CONTEXT="gke_teknoir_us-central1-c_teknoir-cluster"
  DOMAIN="teknoir.cloud"
fi

#cat <<EOF | kubectl --context "$CONTEXT" --namespace "$NAMESPACE" apply -f -
#---
#apiVersion: helm.cattle.io/v1
#kind: HelmChart
#metadata:
#  name: device-lobby
#  namespace: ${NAMESPACE}
#spec:
#  repo: https://teknoir.github.io/device-lobby-helm
#  chart: device-lobby
#  targetNamespace: ${NAMESPACE}
#  valuesContent: |-
#    domain: ${DOMAIN}
#
#EOF

#helm --kube-context "${CONTEXT}" -n "${NAMESPACE}" template device-lobby ./charts/device-lobby --values scripts/values.yaml

helm --kube-context "${CONTEXT}" -n "${NAMESPACE}" upgrade --install device-lobby ./charts/device-lobby \
  --values scripts/values.yaml \
  --set domain="${DOMAIN}"