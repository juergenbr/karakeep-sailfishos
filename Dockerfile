# SailfishOS CI build environment for harbour-karakeep
#
# NOTE: This Dockerfile cannot be built with `docker build` because sdk-manage
# requires PAM/sudo which isn't available during image builds. The CI image is
# instead created by running a container, installing targets interactively, and
# committing the result. The commands below reproduce the image from scratch.
#
# ── ONE-TIME LOCAL SETUP ──────────────────────────────────────────────────────
#
#   Prerequisites: Docker CE logged in to GHCR with write:packages scope.
#
#   Step 1 — push the SDK build engine image:
#
#       /usr/bin/docker tag sailfish-sdk-build-engine:crimson \
#           ghcr.io/juergenbr/sailfish-sdk-build-engine:latest
#       /usr/bin/docker push ghcr.io/juergenbr/sailfish-sdk-build-engine:latest
#
#   Step 2 — build and push the CI image (tooling + targets pre-installed):
#
#       /usr/bin/docker run -d --name sfos-build-setup \
#           --user mersdk \
#           ghcr.io/juergenbr/sailfish-sdk-build-engine:latest sleep infinity
#
#       /usr/bin/docker exec -u root sfos-build-setup \
#           bash -c "mkdir -p /host_targets && chmod 777 /host_targets"
#
#       /usr/bin/docker exec --user mersdk sfos-build-setup \
#           sdk-manage tooling install SailfishOS-5.0.0.62 \
#           "https://releases.sailfishos.org/sdk/targets/Sailfish_OS-5.0.0.62-Sailfish_SDK_Tooling-i486.tar.7z"
#
#       /usr/bin/docker exec --user mersdk sfos-build-setup \
#           sdk-manage target install SailfishOS-5.0.0.62-i486 \
#           "https://releases.sailfishos.org/sdk/targets/Sailfish_OS-5.0.0.62-Sailfish_SDK_Target-i486.tar.7z" \
#           --tooling SailfishOS-5.0.0.62
#
#       /usr/bin/docker exec --user mersdk sfos-build-setup \
#           sdk-manage target install SailfishOS-5.0.0.62-aarch64 \
#           "https://releases.sailfishos.org/sdk/targets/Sailfish_OS-5.0.0.62-Sailfish_SDK_Target-aarch64.tar.7z" \
#           --tooling SailfishOS-5.0.0.62
#
#       /usr/bin/docker exec --user mersdk sfos-build-setup \
#           sdk-manage target install SailfishOS-5.0.0.62-armv7hl \
#           "https://releases.sailfishos.org/sdk/targets/Sailfish_OS-5.0.0.62-Sailfish_SDK_Target-armv7hl.tar.7z" \
#           --tooling SailfishOS-5.0.0.62
#
#       /usr/bin/docker commit sfos-build-setup \
#           ghcr.io/juergenbr/karakeep-build-env:5.0.0.62
#       /usr/bin/docker tag  ghcr.io/juergenbr/karakeep-build-env:5.0.0.62 \
#                            ghcr.io/juergenbr/karakeep-build-env:latest
#       /usr/bin/docker push ghcr.io/juergenbr/karakeep-build-env:5.0.0.62
#       /usr/bin/docker push ghcr.io/juergenbr/karakeep-build-env:latest
#
#       /usr/bin/docker rm -f sfos-build-setup
#
#   Redo Step 2 when upgrading SFOS_VERSION. Step 1 only needs to be repeated
#   if the SDK build engine itself is upgraded.
#
# ─────────────────────────────────────────────────────────────────────────────

# This FROM is here so the file serves as documentation of the base image.
# It is not used by `docker build` in CI — GitHub Actions pulls the pre-built
# ghcr.io/juergenbr/karakeep-build-env:latest image directly.
FROM ghcr.io/juergenbr/sailfish-sdk-build-engine:latest
