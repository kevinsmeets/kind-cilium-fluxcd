FROM kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5

# Optional extra CA certificate. The build script always stages a file named
# extra-ca.crt in the build context (empty if no cert is provided), so this
# COPY always succeeds. The certificate is only trusted when the file is
# non-empty.
COPY extra-ca.crt /tmp/extra-ca.crt
RUN if [ -s /tmp/extra-ca.crt ]; then \
        mkdir -p /usr/local/share/ca-certificates/ && \
        cp /tmp/extra-ca.crt /usr/local/share/ca-certificates/extra-ca.crt && \
        update-ca-certificates; \
    fi && \
    rm -f /tmp/extra-ca.crt
