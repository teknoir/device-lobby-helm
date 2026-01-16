#!/usr/bin/env bash
set -eo pipefail
#set -x

source scripts/run_local_utils.sh

export DIR="$BASE_DIR/CLOUD_MQTT"

if [ -z "$NAMESPACE" ]; then
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
    echo "Error: No target specified. Please specify a target with -t or --target"
    echo "Usage: $0 -t <target>"
    echo "Available targets: demonstrations, victra-poc, teknoir-ai"
    exit 1
fi

export NAMESPACE=${TARGET}
fi

export CONTEXT=$(if [ "$NAMESPACE" == "demonstrations" ]; then echo "gke_teknoir-poc_us-central1-c_teknoir-dev-cluster"; else echo "gke_teknoir_us-central1-c_teknoir-cluster"; fi)

cleanup
trap cleanup EXIT
trap 'cleanup; exit 130' INT

#ensure_forward $DIR $CONTEXT "device-lobby-vault" 8200 8200 "$NAMESPACE"
#export VAULT_URL="localhost:8200"

ensure_forward $DIR $CONTEXT "device-lobby-postgres" 5432 5432 "$NAMESPACE"

#ensure_forward $DIR $CONTEXT "mongodb" 25017 27017 "$NAMESPACE"
#MONGODB_PASSWORD=$(kubectl --context=$CONTEXT --namespace=$NAMESPACE get secret mongodb-credentials -o yaml | yq .data.password | base64 -d)
#MONGODB_USER=$(kubectl --context=$CONTEXT --namespace=$NAMESPACE get secret mongodb-credentials -o yaml | yq .data.username | base64 -d)
#export MONGODB_URI="mongodb://${MONGODB_USER}:${MONGODB_PASSWORD}@localhost:25017"
#
#ensure_forward $DIR $CONTEXT "re-id-mongo" 26017 27017 "$NAMESPACE"
#export REID_MONGODB_PASSWORD=$(kubectl --context=$CONTEXT --namespace=$NAMESPACE get secret re-id-mongo -o yaml | yq .data.password | base64 -d)
#export REID_MONGODB_USER=$(kubectl --context=$CONTEXT --namespace=$NAMESPACE get secret re-id-mongo -o yaml | yq .data.username | base64 -d)
#export REID_MONGODB_URI="mongodb://${REID_MONGODB_USER}:${REID_MONGODB_PASSWORD}@localhost:26017"
#
#ensure_forward $DIR $CONTEXT "matching-service" 8280 80 "$NAMESPACE"
#export REID_MATCHING_SERVICE_URL="http://localhost:8280"

printf "***** Debug mode enabled! *****\n***** App not started! You start the app manually in debug mode! *****\n"
# Block until Ctrl-C
echo "Press Ctrl-C to stop and cleanup..."
while true; do
  sleep 1
done

echo "All background tasks have completed."
