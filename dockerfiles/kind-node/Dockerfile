FROM kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f

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
