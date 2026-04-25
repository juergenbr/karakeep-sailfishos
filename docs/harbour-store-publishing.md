# Publishing to the Jolla Harbour Store

This guide covers packaging and submitting a SailfishOS app to the [Jolla Harbour](https://harbour.jolla.com/) store so it is available on all supported devices, including the **Jolla 2026** phone.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Jolla account | Register at [account.jolla.com](https://account.jolla.com) |
| Harbour publisher account | Request access from Harbour after logging in |
| `harbour-` prefix in app name | Mandatory for all store apps |
| Allowlisted Qt/QML modules | Only modules on the [Harbour allowed list](https://harbour.jolla.com/api) may be used |
| RPM built for `aarch64` | The Jolla 2026 uses an ARM64 SoC — submit an `aarch64` RPM |

---

## 1. Build a release RPM

Build the `aarch64` RPM using the SailfishOS build engine (see the main [CLAUDE.md](../CLAUDE.md) for the full build procedure):

```bash
chmod -R a+rw .
/usr/bin/docker run --rm \
  -v "$(pwd):/home/mersdk/build" \
  -w /home/mersdk/build \
  --user mersdk \
  ghcr.io/juergenbr/karakeep-build-env:latest \
  mb2 -t SailfishOS-5.0.0.62-aarch64 -s rpm/harbour-karakeep.spec build
```

The output RPM lands in `RPMS/harbour-karakeep-<version>-1.aarch64.rpm`.

> **CI shortcut:** Merging a release-please PR automatically builds and attaches both `i486` and `aarch64` RPMs to the GitHub Release. Download the `aarch64` asset from the release page instead of building locally.

---

## 2. Verify Harbour compliance before submitting

The Harbour validator rejects RPMs that violate packaging rules. Run a pre-flight check locally:

```bash
/usr/bin/docker run --rm \
  -v "$(pwd):/home/mersdk/build" \
  -w /home/mersdk/build \
  --user mersdk \
  ghcr.io/juergenbr/karakeep-build-env:latest \
  harbour-sign --check RPMS/harbour-karakeep-<version>-1.aarch64.rpm
```

Common rejection reasons:

| Issue | Fix |
|-------|-----|
| Non-allowlisted library linked | Check `ldd` output; remove or vendor the dependency |
| Non-allowlisted QML import | Replace with an allowed module or inline the functionality |
| App name does not start with `harbour-` | Rename throughout `.pro`, `.spec`, and QML |
| `%{_datadir}/applications/*.desktop` missing | Ensure `.desktop` file is installed by the spec |
| Icons not at required sizes | Provide 86×86, 108×108, 128×128, 172×172 px PNG icons |

---

## 3. Prepare store metadata

Before uploading the RPM, prepare the following in the Harbour web portal:

- **App name** — display name shown in the store (not the RPM name)
- **Short description** — one line, max ~100 characters
- **Full description** — Markdown supported; explain features, setup steps, and any required server (Karakeep in this case)
- **Screenshots** — at minimum one portrait screenshot at 540×960 px; add one taken on the Jolla 2026 display resolution (1080×2340 px) for best presentation
- **Icon** — 172×172 px PNG (the highest-resolution icon from `icons/172x172/`)
- **Category** — e.g., *Utilities* or *Internet*
- **License** — must match the SPDX identifier in `rpm/harbour-karakeep.spec`

---

## 4. Submit the RPM

1. Log in to [harbour.jolla.com](https://harbour.jolla.com).
2. Navigate to **My Apps → New Application** (first submission) or **My Apps → \<app\> → New Version** (update).
3. Upload `RPMS/harbour-karakeep-<version>-1.aarch64.rpm`.
4. Fill in or confirm the metadata from step 3.
5. Click **Submit for QA**.

Jolla's automated QA runs the same compliance checks as `harbour-sign`. Manual QA follows if automated checks pass; typical turnaround is 1–3 business days.

---

## 5. Jolla 2026 specific notes

The Jolla 2026 ships with **SailfishOS 5.x** and an **aarch64** CPU. There is no `i486` emulator target on the device itself.

- Always submit an `aarch64` RPM. An `i486` RPM will be rejected or will fail to install.
- SailfishOS 5.x includes **Qt 5.6** (same as SailfishOS 4.x). No Qt API surface changes are expected; the existing Qt 5.6 compatibility workarounds in `karakeeptypes.h` remain necessary.
- The Harbour allowlist for Qt modules has not changed between SailfishOS 4 and 5; verify at [harbour.jolla.com/api](https://harbour.jolla.com/api) after the 5.x allowlist is published.
- High-DPI display: test screenshots and UI layouts at 1080×2340 px. The existing SailfishOS scaling mechanisms handle pixel density automatically, but verify that all icon sizes are present.

---

## 6. Post-approval checklist

- [ ] Verify the app appears on the device store under the expected category.
- [ ] Install from the store (not via `rpm -i`) and confirm the app launches correctly.
- [ ] Check that the Settings page correctly shows the version string managed by release-please (`qml/pages/SettingsPage.qml`).
- [ ] Update the GitHub Release description to include the Harbour store link.

---

## References

- [Harbour FAQ](https://harbour.jolla.com/faq)
- [Harbour allowed APIs list](https://harbour.jolla.com/api)
- [SailfishOS packaging guidelines](https://docs.sailfishos.org/develop/packaging/)
- [Conventional Commits](https://www.conventionalcommits.org/) — required for all commits in this repo
