#!/usr/bin/env bash
# =============================================================================
# setup-runner.sh
# Registers this Mac as a GitHub Actions self-hosted runner for the repo.
#
# Prerequisites (install before running):
#   brew install minikube kubectl
#   minikube start
#
# Usage:
#   export GITHUB_OWNER="your-org-or-username"
#   export GITHUB_REPO="equal-experts-node"
#   export RUNNER_TOKEN="<token from GitHub Settings → Actions → Runners → New>"
#   bash scripts/setup-runner.sh
# =============================================================================
set -euo pipefail

OWNER="${GITHUB_OWNER:?Set GITHUB_OWNER}"
REPO="${GITHUB_REPO:?Set GITHUB_REPO}"
TOKEN="${RUNNER_TOKEN:?Set RUNNER_TOKEN}"

RUNNER_VERSION="2.329.0"   # update to latest stable if needed
RUNNER_DIR="${HOME}/actions-runner"
RUNNER_ARCHIVE="actions-runner-osx-arm64-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ARCHIVE}"

# --------------------------------------------------------------------------- #
echo "==> Creating runner directory: ${RUNNER_DIR}"
mkdir -p "${RUNNER_DIR}"
cd "${RUNNER_DIR}"

# --------------------------------------------------------------------------- #
echo "==> Downloading GitHub Actions runner v${RUNNER_VERSION}"
# Choose the right architecture
ARCH=$(uname -m)
if [[ "${ARCH}" == "arm64" ]]; then
  RUNNER_ARCHIVE="actions-runner-osx-arm64-${RUNNER_VERSION}.tar.gz"
else
  RUNNER_ARCHIVE="actions-runner-osx-x64-${RUNNER_VERSION}.tar.gz"
fi
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ARCHIVE}"

curl -fsSL -o "${RUNNER_ARCHIVE}" "${RUNNER_URL}"
tar xzf "${RUNNER_ARCHIVE}"
rm  -f  "${RUNNER_ARCHIVE}"

# --------------------------------------------------------------------------- #
echo "==> Configuring runner for ${OWNER}/${REPO}"
./config.sh \
  --url "https://github.com/${OWNER}/${REPO}" \
  --token "${TOKEN}" \
  --name "$(hostname)-local" \
  --labels "self-hosted,macOS,minikube" \
  --work "_work" \
  --unattended \
  --replace

# --------------------------------------------------------------------------- #
echo "==> Installing runner as a launchd service (auto-starts on login)"
./svc.sh install
./svc.sh start

echo ""
echo "✅  Runner registered and started."
echo "    View it at: https://github.com/${OWNER}/${REPO}/settings/actions/runners"
echo ""
echo "    Useful commands:"
echo "      cd ${RUNNER_DIR} && ./svc.sh status   # check status"
echo "      cd ${RUNNER_DIR} && ./svc.sh stop      # stop"
echo "      cd ${RUNNER_DIR} && ./svc.sh uninstall # remove service"
