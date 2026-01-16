#!/bin/bash

export BASE_DIR="/tmp/obs-pipeline"

context_exists() {
    kubectl config get-contexts -o name | grep -q "^$1$"
}
export -f context_exists

is_current_context() {
  local current
  current=$(kubectl config current-context 2>/dev/null)
  if [[ -n "$current" && "$current" == "$CONTEXT" ]]; then
    return 0
  else
    return 1
  fi
}
export -f is_current_context

check_port() {
    local port=$1
    if nc -z localhost $port 2>/dev/null; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}
export -f check_port

# Function to check if a specific service is already running
check_service_running() {
    local dir=$1
    local service=$2
    local port=$3
    local pidfile="$dir/$service.pid"

    mkdir -p $dir

    # Check if pidfile exists and process is still running
    if [ -f "$pidfile" ]; then
        local pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            echo "[$service] Already running (PID: $pid)"
            return 0
        else
            echo "[$service] Stale pidfile found, removing..."
            rm "$pidfile"
            return 1
        fi
    fi

    # Check if port is in use (might be running from another terminal)
    if check_port $port; then
        echo "[$service] Port $port is already in use (running from another terminal?)"
        return 0
    fi

    return 1
}
export -f check_service_running

port_forward() {
  local dir=$1
  local context=$2
  local service=$3
  local port_from=$4
  local port_to=$5
  local ns=$6

  echo "kubectl --context=$context port-forward -n $ns svc/$service"
  kubectl --context=$context port-forward -n "$ns" svc/$service $port_from:$port_to 2>&1 &
  child_pid=$!
  echo "$child_pid" > "$dir/$service.pid"
}
export -f port_forward

forward_and_catch() {
  local dir=$1
  local context=$2
  local service=$3
  local port_from=$4
  local port_to=$5
  local ns=$6

  mkdir -p $dir

  echo "[$service] Starting port forwarding"
  has_error=true
  while [[ "${has_error}" == "true" ]]; do
    exec 3< <(port_forward $dir $context ${service} ${port_from} ${port_to} ${ns})
    has_error=false
    while IFS= read <&3 line && [[ "${has_error}" == "false" ]]
      do
        child_pid=$(cat "$dir/$service.pid")
        if [[ $line == *"broken pipe"* || $line == *"Timeout"* ]]; then
          echo "[$service] ERROR: $line"
          kill -9 "$child_pid"
          echo "[$service] Restarting port forwarding"
          has_error=true
          break
        else
          echo "[$service][$child_pid] $line"
        fi
      done
  done
  echo "[$service] Port forwarding has stopped"
}
export -f forward_and_catch

start_local_service() {
  local dir=$1
  local service=$2
  local cmd=$3

  mkdir -p $dir

  logfile="$dir/$service.log"
  echo "[$service] Starting service (logging to $logfile)"
  eval "$cmd" > "$logfile" 2>&1 &
  child_pid=$!
  echo "$child_pid" > "$dir/$service.pid"
  tail -f "$logfile" &
}
export -f start_local_service


ensure_forward() {
  local dir=$1
  local context=$2
  local service=$3
  local port_from=$4
  local port_to=$5
  local ns=$6

  if ! check_service_running $dir $service $port_from; then
      forward_and_catch $dir $context $service $port_from $port_to $ns &
  fi

  echo "Waiting for service: $service port: $port_from"
  for i in {1..30}; do
      if nc -z localhost $port_from 2>/dev/null; then
          echo "Service $service ready!"
          break
      fi
      if [ $i -eq 30 ]; then
          echo "Timeout waiting for service: $service"
          exit 1
      fi
      sleep 1
  done
}
export -f ensure_forward

cleanup() {
    echo "Cleaning up port forwarding processes..."
    if [ -d "$BASE_DIR" ]; then
        for pidfile in $BASE_DIR/**/*.pid; do
            if [ -f "$pidfile" ]; then
                pid=$(cat "$pidfile")
                kill -9 "$pid" 2>/dev/null || true
                rm "$pidfile"
            fi
        done
    fi
}
export -f cleanup