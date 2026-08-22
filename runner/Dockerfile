FROM ghcr.io/actions/actions-runner:2.336.0@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda

ARG AZURE_CLI_VERSION=2.89.1-1~noble

USER root

# GitHub API 호출·JSON 처리와 Azure 배포에 필요한 도구 및 고정 버전 Azure CLI를 설치합니다.
RUN printf 'APT::Sandbox::User "root";\n' >/etc/apt/apt.conf.d/99rootless-build \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
      jq \
      lsb-release \
      openssl \
      util-linux \
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
    && gpasswd --delete runner sudo \
    && gpasswd --delete runner docker \
    && gpasswd --delete runner users \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /etc/apt/apt.conf.d/99rootless-build

# workflow가 managed identity login 상태를 저장할 runner 전용 Azure CLI 설정 디렉터리를 준비합니다.
RUN install -d -o runner -g runner -m 0700 /home/runner/.azure \
    && az version >/dev/null

# workflow가 등록·정리 로직을 바꾸지 못하도록 entrypoint를 root 소유의 읽기·실행 전용 파일로 배치합니다.
COPY --chown=root:root entrypoint.sh /home/runner/entrypoint.sh
RUN chmod 0555 /home/runner/entrypoint.sh

WORKDIR /home/runner

# container 시작 시 root wrapper가 secret을 보호하고 runner workflow만 non-root로 위임합니다.
USER root

# container 시작 시 entrypoint가 일회성 runner 등록을 마친 후 workflow 수신을 시작합니다.
ENTRYPOINT ["/home/runner/entrypoint.sh"]
