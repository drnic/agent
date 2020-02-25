#!/bin/bash
set -e

artifacts_build=$(buildkite-agent meta-data get "agent-artifacts-build" )

if [[ "$CODENAME" == "" ]]; then
  echo "Error: Missing \$CODENAME (stable or unstable)"
  exit 1
fi

echo '--- Configuring gnupg'

# TODO remove this once deploytools 2020.03 is released with gnupg pre-installed
echo "install gnupg"
apk add gnupg

echo "fetching signing key..."
export GPG_SIGNING_KEY=$(aws ssm get-parameter --name /pipelines/agent/GPG_SIGNING_KEY --with-decryption --output text --query Parameter.Value --region us-east-1)

echo "fetching passphrase..."
export GPG_PASSPHRASE=$(aws ssm get-parameter --name /pipelines/agent/GPG_SIGNING_KEY --with-decryption --output text --query Parameter.Value --region us-east-1)

echo "fetching secret key..."
aws ssm get-parameter --name /pipelines/agent/GPG_SIGNING_KEY --with-decryption --output text --query Parameter.Value --region us-east-1 > /tmp/gpg-secret.gpg
gpg --import /tmp/gpg-secret.gpg
rm /tmp/gpg-secret.gpg

echo "fetching public key..."
aws ssm get-parameter --name /pipelines/agent/GPG_SIGNING_KEY --with-decryption --output text --query Parameter.Value --region us-east-1 > /tmp/gpg-public.gpg
gpg --import /tmp/gpg-public.gpg
rm /tmp/gpg-public.gpg

echo '--- Downloading built debian packages'
rm -rf deb
mkdir -p deb
buildkite-agent artifact download --build "$artifacts_build" "deb/*.deb" deb/

echo '--- Installing dependencies'
bundle

# Loop over all the .deb files and publish them
for file in deb/*.deb; do
  echo "+++ Publishing $file"
  ./scripts/publish-debian-package.sh "$file" "$CODENAME"
done
