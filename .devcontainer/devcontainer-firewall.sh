#!/bin/bash
# Default-deny outbound firewall for the dev container.
# Adapted from Anthropic's reference: github.com/anthropics/claude-code/.devcontainer/init-firewall.sh
# Changes from the reference:
#   - Allows the whole Docker Compose network (so app -> mail:1025 and VS Code's
#     forward of mail:8025 keep working), not just a guessed /24.
#   - Adds NuGet, .NET and VS Code extension CDN hosts.
#   - Hosts are split into REQUIRED (fail if unresolvable) and OPTIONAL (warn only).
set -euo pipefail  # Exit on error, undefined vars, and pipeline failures
IFS=$'\n\t'       # Stricter word splitting
echo "devcontainer-firewall: starting at $(date -u +%H:%M:%SZ) (script md5 $(md5sum < "$0" | cut -c1-8))"

# Fail CLOSED: if anything below exits non-zero, leave the container with
# default-deny policies (loopback stays open so VS Code can still attach)
# instead of the wide-open state the script passes through while it works.
fail_closed() {
    local rc=$?
    trap - EXIT
    if [ "$rc" -ne 0 ]; then
        echo "devcontainer-firewall: FAILED (exit $rc) - failing closed; fix the cause and re-run: sudo $0" >&2
        iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -i lo -j ACCEPT || true
        iptables -C OUTPUT -o lo -j ACCEPT 2>/dev/null || iptables -I OUTPUT 1 -o lo -j ACCEPT || true
        iptables -P INPUT DROP || true
        iptables -P FORWARD DROP || true
        iptables -P OUTPUT DROP || true
    fi
    exit "$rc"
}
trap fail_closed EXIT

# --- Allowlists -------------------------------------------------------------
REQUIRED_DOMAINS=(
    "api.anthropic.com"          # Claude Code
    "registry.npmjs.org"         # Claude Code updates
    "api.nuget.org"              # dotnet restore
)
OPTIONAL_DOMAINS=(
    # Claude Code telemetry / error reporting (from Anthropic's reference list)
    "sentry.io"
    "statsig.com"
    "statsig.anthropic.com"
    # NuGet / .NET
    "globalcdn.nuget.org"
    "builds.dotnet.microsoft.com"
    "ci.dot.net"
    "download.visualstudio.microsoft.com"
    # VS Code + extensions
    "marketplace.visualstudio.com"
    "vscode.blob.core.windows.net"
    "update.code.visualstudio.com"
    "ms-dotnettools.gallerycdn.vsassets.io"
    "anthropic.gallerycdn.vsassets.io"
    # Add your own here, e.g. "pypi.org"
)

# Sanity check: DNS must work before we change anything.
if ! getent hosts api.github.com >/dev/null; then
    echo "ERROR: DNS is not working in the container BEFORE the firewall ran."
    echo "       /etc/resolv.conf:"; sed 's/^/         /' /etc/resolv.conf || true
    exit 1
fi

# Reset only the FILTER table. The reference script also flushes the nat/mangle
# tables and then restores Docker's embedded-DNS (127.0.0.11) NAT rules, but that
# restore is unreliable on Docker Desktop + WSL (it broke DNS, curl exit 6).
# The firewall only needs the filter table, so leave nat/mangle untouched.
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -X
ipset destroy allowed-domains 2>/dev/null || true

# Allow DNS, SSH (for git over ssh) and localhost before any restrictions
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# GitHub publishes its IP ranges; add web/api/git
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s --connect-timeout 5 --max-time 20 https://api.github.com/meta || true)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi
if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi
echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    ipset add allowed-domains "$cidr" -exist
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Resolve a domain and add its IPv4 addresses. $2 = "required" | "optional"
add_domain() {
    local domain="$1" mode="$2" ips
    echo "Resolving $domain..."
    ips=$(dig +time=2 +tries=2 +noall +answer A "$domain" | awk '$4 == "A" {print $5}' || true)
    if [ -z "$ips" ]; then
        if [ "$mode" = "required" ]; then
            echo "ERROR: Failed to resolve required domain $domain"
            exit 1
        fi
        echo "WARNING: Could not resolve $domain, skipping"
        return 0
    fi
    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" -exist
    done < <(echo "$ips")
}
for d in "${REQUIRED_DOMAINS[@]}"; do add_domain "$d" required; done
for d in "${OPTIONAL_DOMAINS[@]}"; do add_domain "$d" optional; done

# Allow the Compose network (mail, db, Docker host gateway).
# Prefer the real on-link subnet; fall back to the reference's gateway /24 guess.
COMPOSE_NETWORK=$(ip -4 route show scope link | awk '$1 ~ /\// {print $1; exit}')
if [ -z "$COMPOSE_NETWORK" ]; then
    HOST_IP=$(ip route | grep default | cut -d" " -f3)
    if [ -z "$HOST_IP" ]; then
        echo "ERROR: Failed to detect host IP"
        exit 1
    fi
    COMPOSE_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
fi
echo "Compose network detected as: $COMPOSE_NETWORK"
iptables -A INPUT -s "$COMPOSE_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$COMPOSE_NETWORK" -j ACCEPT

# Default policies: DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow established connections for already approved traffic
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow only specific outbound traffic to allowed destinations
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Explicitly REJECT all other outbound traffic for immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# IPv6: Compose networks are IPv4-only by default; block v6 egress in case it's enabled.
if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -F || true
    ip6tables -A INPUT -i lo -j ACCEPT || true
    ip6tables -A OUTPUT -o lo -j ACCEPT || true
    ip6tables -P INPUT DROP || true
    ip6tables -P FORWARD DROP || true
    ip6tables -P OUTPUT DROP || true
fi

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi
if ! curl --connect-timeout 5 -s -o /dev/null https://api.nuget.org/v3/index.json; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.nuget.org"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.nuget.org as expected"
fi
