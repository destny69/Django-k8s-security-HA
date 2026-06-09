FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends fail2ban iptables \
    && rm -rf /var/lib/apt/lists/*

COPY fail2ban/jail.d /etc/fail2ban/jail.d
COPY fail2ban/filter.d /etc/fail2ban/filter.d

CMD ["fail2ban-server", "-f", "start"]
