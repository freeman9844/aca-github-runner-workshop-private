FROM ghcr.io/actions/actions-runner:2.336.0@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda

ARG AZURE_CLI_VERSION=2.89.1-1~noble

USER root

# Install the tools required by the runner and Azure deployment workflow.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
      jq \
      lsb-release \
    && mkdir -p /etc/apt/keyrings \
    && curl --fail --silent --show-error --location \
      https://packages.microsoft.com/keys/microsoft.asc \
      --output /tmp/microsoft.asc \
    && gpg --dearmor \
      --output /etc/apt/keyrings/microsoft.gpg \
      /tmp/microsoft.asc \
    && rm /tmp/microsoft.asc \
    && chmod go+r /etc/apt/keyrings/microsoft.gpg \
    && printf '%s\n' \
      'Types: deb' \
      'URIs: https://packages.microsoft.com/repos/azure-cli/' \
      "Suites: $(lsb_release -cs)" \
      'Components: main' \
      "Architectures: $(dpkg --print-architecture)" \
      'Signed-by: /etc/apt/keyrings/microsoft.gpg' \
      > /etc/apt/sources.list.d/azure-cli.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends azure-cli="$AZURE_CLI_VERSION" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy the registration wrapper without granting write access at runtime.
COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
RUN chmod 0555 /home/runner/entrypoint.sh

# Run the container as the non-root runner user.
USER runner

# Install and verify the Container Apps extension while building the image.
RUN az extension add --name containerapp --version 0.3.55 --only-show-errors
RUN az version >/dev/null \
    && az containerapp --help >/dev/null
WORKDIR /home/runner

# Register the ephemeral runner before starting the workflow process.
ENTRYPOINT ["/home/runner/entrypoint.sh"]
