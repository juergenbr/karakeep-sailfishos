# SailfishOS CI build environment for harbour-karakeep
#
# This Dockerfile extends the SailfishOS SDK build engine image with the
# tooling and targets pre-installed, so GitHub Actions can run builds without
# needing Docker-in-Docker.
#
# ── ONE-TIME LOCAL SETUP ──────────────────────────────────────────────────────
#
#   1. Push the local build engine image to GHCR (requires 'docker login ghcr.io'):
#
#       docker tag sailfish-sdk-build-engine:crimson \
#           ghcr.io/juergenbr/sailfish-sdk-build-engine:latest
#       docker push ghcr.io/juergenbr/sailfish-sdk-build-engine:latest
#
#   2. Build and push THIS image (CI build environment with targets):
#
#       docker build -t ghcr.io/juergenbr/karakeep-build-env:5.0.0.62 .
#       docker push ghcr.io/juergenbr/karakeep-build-env:5.0.0.62
#       docker tag  ghcr.io/juergenbr/karakeep-build-env:5.0.0.62 \
#                   ghcr.io/juergenbr/karakeep-build-env:latest
#       docker push ghcr.io/juergenbr/karakeep-build-env:latest
#
#   Rebuild and re-push whenever you update the SDK version or add new targets.
#   After the first push, GitHub Actions pulls from GHCR — no local SDK needed.
#
# ─────────────────────────────────────────────────────────────────────────────

ARG SFOS_VERSION=5.0.0.62

FROM ghcr.io/juergenbr/sailfish-sdk-build-engine:latest AS build-env

ARG SFOS_VERSION
ENV SFOS_VERSION=${SFOS_VERSION}

# Switch to the mersdk user (matches the build engine convention; targets are
# installed per-user inside the container).
USER mersdk
WORKDIR /home/mersdk

# ── Install SDK Tooling ───────────────────────────────────────────────────────
# The tooling provides the cross-compilers, qmake, moc, rcc, and mb2.
# It is architecture-independent: one tooling serves all targets.
RUN set -eux; \
    curl -fsSL \
        "https://releases.sailfishos.org/sdk/targets/Sailfish_OS-${SFOS_VERSION}-Sailfish_SDK_Tooling-i486.tar.7z" \
        -o /tmp/tooling.tar.7z; \
    cd /tmp && 7za x tooling.tar.7z; \
    TARFILE=$(ls /tmp/Sailfish_OS-*Tooling*.tar 2>/dev/null | head -1); \
    if [ -z "$TARFILE" ]; then \
        echo "ERROR: tooling tar not found after 7z extraction" >&2; exit 1; \
    fi; \
    yes | sfdk tools tooling install-custom \
        "SailfishOS-${SFOS_VERSION}" \
        "file://${TARFILE}"; \
    rm -f /tmp/tooling.tar.7z /tmp/*.tar

# ── Install i486 target (emulator) ───────────────────────────────────────────
RUN set -eux; \
    curl -fsSL \
        "https://releases.sailfishos.org/sdk/targets/Sailfish_OS-${SFOS_VERSION}-Sailfish_SDK_Target-i486.tar.7z" \
        -o /tmp/target-i486.tar.7z; \
    cd /tmp && 7za x target-i486.tar.7z; \
    TARFILE=$(ls /tmp/Sailfish_OS-*Target-i486*.tar 2>/dev/null | head -1); \
    yes | sfdk tools target install-custom \
        "SailfishOS-${SFOS_VERSION}-i486" \
        "file://${TARFILE}" \
        --tooling "SailfishOS-${SFOS_VERSION}"; \
    rm -f /tmp/target-i486.tar.7z /tmp/*.tar

# ── Install aarch64 target (Jolla Phone 2026 / Xperia / Jolla C2) ────────────
RUN set -eux; \
    curl -fsSL \
        "https://releases.sailfishos.org/sdk/targets/Sailfish_OS-${SFOS_VERSION}-Sailfish_SDK_Target-aarch64.tar.7z" \
        -o /tmp/target-aarch64.tar.7z; \
    cd /tmp && 7za x target-aarch64.tar.7z; \
    TARFILE=$(ls /tmp/Sailfish_OS-*Target-aarch64*.tar 2>/dev/null | head -1); \
    yes | sfdk tools target install-custom \
        "SailfishOS-${SFOS_VERSION}-aarch64" \
        "file://${TARFILE}" \
        --tooling "SailfishOS-${SFOS_VERSION}"; \
    rm -f /tmp/target-aarch64.tar.7z /tmp/*.tar

WORKDIR /build
