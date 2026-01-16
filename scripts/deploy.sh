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

# Extract RSA public key from cert-manager secret (device-lobby-client-cert -> tls.crt)
CERT_SECRET_NAME="${CERT_SECRET_NAME:-device-lobby-client-cert}"
JWT_RSA_PUB=$(
  kubectl --context "$CONTEXT" --namespace "$NAMESPACE" get secret "$CERT_SECRET_NAME" \
    -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
  | base64 -d \
  | openssl x509 -pubkey -noout || true
)
if [ -z "$JWT_RSA_PUB" ]; then
  echo "ERROR: Could not read tls.crt from secret '$CERT_SECRET_NAME' in ns '$NAMESPACE'." >&2
  echo "Ensure cert-manager created the secret and it contains tls.crt/tls.key." >&2
  exit 1
fi
INDENTED_JWT_RSA_PUB="$(printf "%s\n" "$JWT_RSA_PUB" | sed 's/^/    /')"


USERNAME="teknoir"
PASSWORD="Teknoir1231!"
cat <<EOF | kubectl --context "$CONTEXT" --namespace "$NAMESPACE" apply -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: device-lobby-mpsweb
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  user: "${USERNAME}"
  password: "${PASSWORD}"
---
apiVersion: v1
kind: Secret
metadata:
  name: device-lobby-postgres
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  user: "${USERNAME}"
  password: "${PASSWORD}"
  connectionStringRPS: "postgresql://${USERNAME}:${PASSWORD}@device-lobby-postgres:5432/rpsdb?sslmode=disable"
  connectionStringMPS: "postgresql://${USERNAME}:${PASSWORD}@device-lobby-postgres:5432/mpsdb?sslmode=disable"
---
apiVersion: v1
kind: Secret
metadata:
  name: device-mgmt-toolkit-admin-jwt
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  key: admin-issuer
  algorithm: RS256
  rsa_public_key: |-
${INDENTED_JWT_RSA_PUB}
EOF

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
#  version: 0.0.1-beta.19
#  targetNamespace: ${NAMESPACE}
#  valuesContent: |-
#    domain: ${DOMAIN}
#
#EOF

helm -n ${NAMESPACE} upgrade --install device-lobby charts/device-lobby \
  --set domain=${DOMAIN} \
  --set images.mps=us-docker.pkg.dev/teknoir/gcr.io/device-lobby-mps:local-20260115-085049 \
  --set images.rps=us-docker.pkg.dev/teknoir/gcr.io/device-lobby-rps:local-20260115-083244 \
  --set images.webui=us-docker.pkg.dev/teknoir/gcr.io/device-lobby-ui:local-20260115-135811

sleep 10

# Get pod name from deployment
POD_NAME=$(kubectl -n ${NAMESPACE} get pods -l app=device-lobby-postgres -o jsonpath="{.items[0].metadata.name}")
# Wait for the pod to be ready
echo "Waiting for pod ${POD_NAME} to be ready..."
kubectl -n ${NAMESPACE} wait --for=condition=Ready pod/${POD_NAME} --timeout=120s
kubectl -n ${NAMESPACE} cp ./data/init.sql ${POD_NAME}:/init.sql
kubectl -n ${NAMESPACE} cp ./data/initMPS.sql ${POD_NAME}:/initMPS.sql
kubectl -n ${NAMESPACE} exec -ti ${POD_NAME} -- \
  bash -c "PGPASSWORD=${PASSWORD} && psql -h localhost -p 5432 -d postgres -U ${USERNAME} -w -f /init.sql -f /initMPS.sql"
