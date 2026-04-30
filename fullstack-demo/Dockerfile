
FROM python:3.11-slim
WORKDIR /app

# Ensure ca-certificates is installed and up to date
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

# Optional extra CA certificate (e.g. corporate MITM proxy CA). The build
# script always stages a file named extra-ca.crt in the build context (empty
# if no cert is provided), so this COPY always succeeds.
COPY extra-ca.crt /tmp/extra-ca.crt
RUN if [ -s /tmp/extra-ca.crt ]; then \
        mkdir -p /usr/local/share/ca-certificates/ && \
        cp /tmp/extra-ca.crt /usr/local/share/ca-certificates/extra-ca.crt && \
        update-ca-certificates; \
    fi && \
    rm -f /tmp/extra-ca.crt

# Set PIP_CERT to ensure pip uses the updated CA bundle
ENV PIP_CERT=/etc/ssl/certs/ca-certificates.crt

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py ./
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
