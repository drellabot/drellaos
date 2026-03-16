FROM quay.io/fedora/fedora-bootc:43

# Install packages
RUN dnf install -y \
      awscli2 \
      git-core \
      gh \
      golang \
      jq \
      opentofu \
    && dnf clean all

# User 'drella': created at boot via sysusers, home dir via tmpfiles, passwordless sudo
COPY usr/lib/sysusers.d/drella.conf /usr/lib/sysusers.d/drella.conf
COPY usr/lib/tmpfiles.d/drella-home.conf /usr/lib/tmpfiles.d/drella-home.conf
COPY usr/etc/sudoers.d/drella /etc/sudoers.d/drella

# Add ~/.local/bin to PATH for all users (e.g. claude code lives here)
COPY usr/etc/profile.d/local-bin.sh /etc/profile.d/local-bin.sh

# Fetch GCloud credentials from AWS Secrets Manager at boot
COPY usr/libexec/drella-fetch-gcloud-creds /usr/libexec/drella-fetch-gcloud-creds
COPY usr/lib/systemd/system/drella-gcloud-creds.service /usr/lib/systemd/system/drella-gcloud-creds.service
RUN systemctl enable drella-gcloud-creds.service

# SSH authorized keys fetched from GitHub at build time, stored in /usr
# sshd is configured to read from this path
RUN set -euo pipefail && \
    users=" \
      ondrejbudai \
      ochosi \
      lucasgarfield \
    " && \
    for user in ${users}; do \
      curl --fail --silent --show-error --location "https://github.com/${user}.keys"; \
    done > /usr/lib/drella-authorized-keys && \
    chmod 0644 /usr/lib/drella-authorized-keys
RUN echo 'AuthorizedKeysFile /usr/lib/%u-authorized-keys .ssh/authorized_keys' > /etc/ssh/sshd_config.d/50-drella-keys.conf
