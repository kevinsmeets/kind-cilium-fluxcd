FROM rpardini/docker-registry-proxy:0.6.2

# Optional extra CA certificate (empty placeholder when none is provided).
# Trust it both via update-ca-certificates and by appending to the bundle
# that the proxy uses directly.
COPY extra-ca.crt /tmp/extra-ca.crt
# hadolint ignore=DL3018
RUN if [ -s /tmp/extra-ca.crt ]; then \
        mkdir -p /usr/local/share/ca-certificates/ && \
        cp /tmp/extra-ca.crt /usr/local/share/ca-certificates/extra-ca.crt && \
        cat /tmp/extra-ca.crt >> /etc/ssl/certs/ca-certificates.crt; \
    fi && \
    rm -f /tmp/extra-ca.crt && \
    apk --no-cache add curl
