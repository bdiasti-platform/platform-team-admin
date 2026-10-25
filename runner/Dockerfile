# CircleCI machine runner (Linux) for the platform-team-admin pipeline.
# Jobs run inside this container as root, with bash, uv and Pulumi preinstalled.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git gnupg openssh-client sudo \
 && rm -rf /var/lib/apt/lists/*

# CircleCI machine runner 3 (official apt repository)
RUN curl -fsSL "https://packagecloud.io/install/repositories/circleci/runner/script.deb.sh?any=true" | bash \
 && apt-get install -y --no-install-recommends circleci-runner \
 && rm -rf /var/lib/apt/lists/*

# Preinstalled so the pipeline's "command -v" checks skip the download
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
 && curl -fsSL https://get.pulumi.com | sh
ENV PATH="/root/.local/bin:/root/.pulumi/bin:${PATH}"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
