FROM powerdns/pdns-recursor-53:latest

# Copy configuration files with proper ownership and permissions
COPY --chown=root:root --chmod=644 config/powerdns/recursor.conf /etc/powerdns/recursor.conf
COPY --chown=root:root --chmod=644 config/powerdns/recursor-adblock.lua /etc/powerdns/recursor-adblock.lua
COPY --chown=root:root --chmod=644 config/powerdns/blocked_domains.txt /etc/powerdns/blocked_domains.txt
COPY --chown=root:root --chmod=644 config/powerdns/hosts_overrides.txt /etc/powerdns/hosts_overrides.txt