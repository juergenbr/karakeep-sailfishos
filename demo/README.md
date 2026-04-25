# KaraKeep QA Demo Environment

Step-by-step instructions for spinning up a local Karakeep instance and
running the SailfishOS app against it inside the emulator.

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| Docker Engine ≥ 24 (or Podman ≥ 4) | Runs the Karakeep server |
| Python 3 | Runs the seed script (stdlib only, no pip packages required) |
| SailfishOS SDK ≥ 5.0.0.62 | Provides the emulator |

---

## 1 — Start the Karakeep server

Run from the **repo root** (`karakeep/`):

```bash
docker run -d \
  --name karakeep-demo \
  --restart unless-stopped \
  -p 3000:3000 \
  -v karakeep-demo-data:/data \
  -e DATA_DIR=/data \
  -e NEXTAUTH_SECRET=qa-demo-secret-not-for-production \
  -e NEXTAUTH_URL=http://localhost:3000 \
  -e DISABLE_SIGNUPS=false \
  ghcr.io/karakeep-app/karakeep:latest
```

> A `demo/docker-compose.yml` is also included for environments where the Docker
> Compose plugin is available (`docker compose up -d` from the `demo/` directory).

Karakeep starts on **http://localhost:3000**. Wait a few seconds for it to
initialise before running the seed script.

---

## 2 — Seed demo data

Run from the **repo root** (`karakeep/`):

```bash
python3 demo/seed.py
```

The script:
- Creates a demo user account
- Creates 4 manual lists and 1 smart list
- Creates 15 bookmarks (links and text notes) with tags
- Assigns bookmarks to lists
- Marks 3 bookmarks as favourited and 2 as archived

When done it prints the credentials and the emulator config command:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Demo environment ready
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Web UI:   http://localhost:3000
  Username: demo@karakeep.local
  Password: Demo1234

  Emulator config — run via SSH as root:
  mkdir -p ... && printf '...' > harbour-karakeep.conf
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

> **Run the seed script once per fresh instance.** Running it a second time without
> resetting the volume creates duplicate lists and bookmarks (the API key is handled
> safely — the old one is revoked and a new one issued).
> To start over cleanly, see [Resetting the environment](#resetting-the-environment).

---

## 3 — Verify via the web UI (optional)

Open **http://localhost:3000** in a browser, sign in with:

| | |
|---|---|
| **Username** | `demo@karakeep.local` |
| **Password** | `Demo1234` |

You should see the 15 bookmarks, 5 lists, tags, and the smart list.

---

## 4 — Start the emulator

```bash
VBoxManage startvm "SailfishOS-5.0.0.62" --type gui
```

Wait ~30 seconds for it to fully boot before continuing.

---

## 5 — Install the app

Download `harbour-karakeep-<version>-1.i486.rpm` from the
[latest GitHub Release](https://github.com/juergenbr/karakeep-sailfishos/releases/latest),
then install it:

```bash
KEY=~/SailfishOS/vmshare/ssh/private_keys/sdk
SSH_OPTS="-i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

scp $SSH_OPTS -P 2223 harbour-karakeep-*.i486.rpm root@127.0.0.1:/tmp/
ssh $SSH_OPTS -p 2223 root@127.0.0.1 "rpm -ivh /tmp/harbour-karakeep-*.i486.rpm"
```

---

## 6 — Configure the app

`seed.py` prints a ready-to-run config command at the end of its output:

```
  Emulator config — run via SSH as root:
  mkdir -p /home/defaultuser/.config/harbour-karakeep && printf '[connection]\n...' > ...
```

Copy that command and run it over SSH:

```bash
KEY=~/SailfishOS/vmshare/ssh/private_keys/sdk
SSH_OPTS="-i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

ssh $SSH_OPTS -p 2223 root@127.0.0.1 '<paste the command from seed.py output here>'
```

> **Why `10.0.2.2`?** The emulator uses VirtualBox NAT; `10.0.2.2` is the
> standard NAT gateway address that routes to the host machine.

---

## 7 — Run the app

Launch **KaraKeep** from the emulator's app grid. On first launch, accept the
Internet permission prompt. The app should connect immediately and display the
demo bookmarks — no manual server or API key entry is needed.

### What to look at

| Screen | How to reach it |
|--------|----------------|
| Bookmark list | Main screen — all 15 bookmarks |
| Favourites | Pull down → **Show favourites** (3 items) |
| Archived | Pull down → **Show archived** (2 items) |
| Lists overview | Pull down → **Lists** |
| Smart list | Lists → **Linux & Open Source** (auto-populated by tag) |
| Bookmark detail | Tap any bookmark |
| Add bookmark | Pull down → **Add link** or **Add note** |
| Settings | Pull down → **Settings** |
| Cover page | Swipe left past the home screen |

---

## Demo data summary

### Lists

| Name | Type | Contents |
|------|------|----------|
| Tech Articles | Manual | Haskell, Rust, Qt docs, Karakeep, Arch, Podman |
| Reading List | Manual | O'Reilly, Lobsters, LWN, home server notes |
| SailfishOS | Manual | Developer portal, Harbour store, SailfishOS docs |
| Travel | Manual | Europe trip planning note, Lonely Planet |
| Linux & Open Source | **Smart** | Auto-populated: `#linux OR #selfhosted` |

### Tags used

`programming` · `functional` · `systems` · `qt` · `sailfishos` · `mobile` ·
`selfhosted` · `tools` · `linux` · `sysadmin` · `containers` · `books` ·
`learning` · `tech` · `community` · `news` · `store` · `docs` · `travel` ·
`todo` · `homelab` · `guides`

### Special states

| State | Bookmarks |
|-------|-----------|
| Favourited ★ | Qt 5 Documentation, Karakeep, SailfishOS Documentation |
| Archived | Arch Linux, O'Reilly |

---

## Resetting the environment

To start over with a clean instance:

```bash
docker stop karakeep-demo && docker rm karakeep-demo
docker volume rm karakeep-demo-data
# then re-run the docker run command from step 1, followed by:
python3 demo/seed.py
```

---

## Stopping the environment

```bash
# Stop the Karakeep server (keeps data in the volume)
docker stop karakeep-demo

# Stop the emulator
VBoxManage controlvm "SailfishOS-5.0.0.62" acpipowerbutton
```

To start the server again later:

```bash
docker start karakeep-demo
```
