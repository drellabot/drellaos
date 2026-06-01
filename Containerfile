FROM quay.io/fedora/fedora-bootc:44

ARG BUILD_SHA=unknown
ARG BUILD_TIMESTAMP=unknown

LABEL org.opencontainers.image.title="DrellaOS"
LABEL org.opencontainers.image.source="https://github.com/drellabot/drellaos"
LABEL org.opencontainers.image.revision="${BUILD_SHA}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"

# Install packages
RUN dnf install -y \
      awscli2 \
      caddy \
      git-core \
      gh \
      golang \
      jq \
      opentofu \
      rsync \
      tmux \
      vim \
    && dnf clean all

# Allow rootless services to bind to port 80+
COPY usr/lib/sysctl.d/80-unprivileged-ports.conf /usr/lib/sysctl.d/80-unprivileged-ports.conf

# User 'drella': created at boot via sysusers, home dir via tmpfiles, passwordless sudo
COPY usr/lib/sysusers.d/drella.conf /usr/lib/sysusers.d/drella.conf
COPY usr/lib/tmpfiles.d/drella-home.conf /usr/lib/tmpfiles.d/drella-home.conf
COPY usr/etc/sudoers.d/drella /etc/sudoers.d/drella

# Add ~/go/bin and ~/.local/bin to PATH for all users
COPY usr/etc/profile.d/local-bin.sh /etc/profile.d/local-bin.sh
COPY usr/lib/environment.d/50-go-path.conf /usr/lib/environment.d/50-go-path.conf

# Fetch credentials from AWS Secrets Manager at boot
COPY usr/libexec/drella-fetch-secrets /usr/libexec/drella-fetch-secrets
COPY usr/lib/systemd/system/drella-fetch-secrets.service /usr/lib/systemd/system/drella-fetch-secrets.service
RUN systemctl enable drella-fetch-secrets.service

# User services: orchestrator, dashboard, and auto-update timer
# The update timer is enabled for the drella user via tmpfiles, not globally.
COPY usr/libexec/drella-update-orchestrator /usr/libexec/drella-update-orchestrator
COPY usr/lib/systemd/user/drella-update-orchestrator.service /usr/lib/systemd/user/drella-update-orchestrator.service
COPY usr/lib/systemd/user/drella-update-orchestrator.timer /usr/lib/systemd/user/drella-update-orchestrator.timer
COPY usr/lib/systemd/user/dashboard.service /usr/lib/systemd/user/dashboard.service
# The orchestrator uses TimeoutStopSec=3600 to drain long-running tasks.
# Extend user@.service timeout so the user manager isn't killed first.
COPY usr/lib/systemd/system/user@.service.d/50-timeout.conf /usr/lib/systemd/system/user@.service.d/50-timeout.conf

# SSH authorized keys fetched from GitHub at build time, stored in /usr
# sshd is configured to read from this path
RUN set -euo pipefail && \
    users=" \
      ondrejbudai \
      ochosi \
      lucasgarfield \
      nkinder \
      beav \
      schuellerf \
      jlsherrill \
    " && \
    for user in ${users}; do \
      curl --fail --silent --show-error --location "https://github.com/${user}.keys"; \
    done > /usr/lib/drella-authorized-keys && \
    chmod 0644 /usr/lib/drella-authorized-keys
RUN echo 'AuthorizedKeysFile /usr/lib/%u-authorized-keys .ssh/authorized_keys' > /etc/ssh/sshd_config.d/50-drella-keys.conf

# Stamp os-release with DrellaOS build metadata (following bluefin's pattern)
RUN sed -i '/^VARIANT_ID=/d; /^BUILD_ID=/d' /usr/lib/os-release && \
    printf 'VARIANT_ID=drellaos\nIMAGE_ID=drellaos\nBUILD_ID=%s\nIMAGE_VERSION=%s\n' \
      "${BUILD_SHA}" "${BUILD_TIMESTAMP}" >> /usr/lib/os-release
