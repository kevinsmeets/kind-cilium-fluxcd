FROM ghcr.io/fluxcd/kustomize-controller:v1.6.1

USER root
# Optional extra CA certificate (empty placeholder when none is provided).
COPY extra-ca.crt /tmp/extra-ca.crt
RUN if [ -s /tmp/extra-ca.crt ]; then \
        mkdir -p /usr/local/share/ca-certificates/ && \
        cp /tmp/extra-ca.crt /usr/local/share/ca-certificates/extra-ca.crt && \
        update-ca-certificates; \
    fi && \
    rm -f /tmp/extra-ca.crt

USER 9000:9000
