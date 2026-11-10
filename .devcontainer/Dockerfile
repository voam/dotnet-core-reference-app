FROM mcr.microsoft.com/devcontainers/dotnet:2-10.0-noble

# Ubuntu package mirror. archive.ubuntu.com was slow here, so use a faster one.
# Override with:  "build": { "args": { "UBUNTU_MIRROR": "http://..." } }  in docker-compose.yml
ARG UBUNTU_MIRROR=http://mirrors.edge.kernel.org/ubuntu

# Make apt fail fast and retry instead of hanging, and point it at the mirror
# (covers both the deb822 ubuntu.sources file and a classic sources.list).
RUN printf '%s\n' \
      'Acquire::ForceIPv4 "true";' \
      'Acquire::Retries "5";' \
      'Acquire::http::Timeout "20";' \
      'Acquire::https::Timeout "20";' \
    > /etc/apt/apt.conf.d/99-network \
    && for f in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list; do \
         [ -f "$f" ] && sed -i -E \
           "s#https?://(archive|security)\.ubuntu\.com/ubuntu/?#${UBUNTU_MIRROR}/#g" "$f"; \
       done; true

# Firewall tooling (same set Anthropic's reference container installs)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
       iptables ipset iproute2 dnsutils aggregate jq curl \
    && rm -rf /var/lib/apt/lists/*

# Install the firewall script, and let the non-root user run ONLY that script as root.
# The base image gives "vscode" passwordless sudo for everything, which would let
# anything in the container (including Claude Code) run `sudo iptables -F` and undo
# the firewall. Removing it is what makes the lockdown real.
# Trade-off: no more `sudo apt-get install` from the terminal; add packages here and rebuild.
#
# devcontainer.json's initializeCommand clears Docker's cached copy of this folder
# before each build, so this COPY always reads the current file.
COPY devcontainer-firewall.sh /usr/local/bin/devcontainer-firewall.sh
# Fail the build loudly if an old copy of the script got in (older versions lack this line).
RUN echo "devcontainer-firewall.sh md5 $(md5sum < /usr/local/bin/devcontainer-firewall.sh | cut -c1-8)" \
    && grep -q 'devcontainer-firewall: starting at' /usr/local/bin/devcontainer-firewall.sh \
    || { echo "ERROR: stale devcontainer-firewall.sh was copied into the image"; exit 1; }
RUN chmod 0755 /usr/local/bin/devcontainer-firewall.sh \
    && rm -f /etc/sudoers.d/vscode \
    && echo "vscode ALL=(root) NOPASSWD: /usr/local/bin/devcontainer-firewall.sh" > /etc/sudoers.d/vscode-firewall \
    && chmod 0440 /etc/sudoers.d/vscode-firewall \
    && visudo -c
