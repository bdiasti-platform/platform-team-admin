#!/usr/bin/env bash
# Writes the runner config from environment variables and starts the runner.
set -euo pipefail

: "${CIRCLECI_RUNNER_API_AUTH_TOKEN:?Set CIRCLECI_RUNNER_API_AUTH_TOKEN in runner/runner.env}"
: "${CIRCLECI_RUNNER_NAME:=platform-runner-local}"

mkdir -p /etc/circleci-runner /var/lib/circleci/workdir
cat > /etc/circleci-runner/circleci-runner-config.yaml <<EOF
runner:
  name: "${CIRCLECI_RUNNER_NAME}"
  working_directory: /var/lib/circleci/workdir
  cleanup_working_directory: true
api:
  auth_token: "${CIRCLECI_RUNNER_API_AUTH_TOKEN}"
EOF
chmod 600 /etc/circleci-runner/circleci-runner-config.yaml

exec circleci-runner machine --config /etc/circleci-runner/circleci-runner-config.yaml
