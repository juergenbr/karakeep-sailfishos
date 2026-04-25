# KaraKeep QA Demo Environment

Step-by-step instructions for spinning up a local Karakeep instance and
running the SailfishOS app against it inside the emulator.

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| Docker Engine ≥ 24 | Runs the Karakeep server |
| Docker Compose plugin (`docker compose`) or standalone `docker-compose` | Manages the container |
| Python 3 | Runs the seed script (stdlib only, no pip packages required) |
| SailfishOS SDK ≥ 5.0.0.62 | Provides the emulator |

---

## 1 — Start the Karakeep server

```bash
cd demo/
docker compose up -d
```

Karakeep starts on **http://localhost:3000**. Wait a few seconds for it to
initialise before running the seed script.

---

## 2 — Seed demo data

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

> Run the seed script once only. Running it again creates duplicate data.
> To reset, see [Resetting the environment](#resetting-the-environment).

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

Copy the config command printed by `seed.py` and run it over SSH:

```bash
KEY=~/SailfishOS/vmshare/ssh/private_keys/sdk
SSH_OPTS="-i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

ssh $SSH_OPTS -p 2223 root@127.0.0.1 \
  "mkdir -p /home/defaultuser/.config/harbour-karakeep && \
   printf '[connection]\nserverUrl=http://10.0.2.2:3000\napiKey=<KEY FROM SEED OUTPUT>\n' \
   > /home/defaultuser/.config/harbour-karakeep/harbour-karakeep.conf"
```

Replace `<KEY FROM SEED OUTPUT>` with the API key printed by `seed.py`.

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
docker compose down -v   # stops the container and deletes the volume
docker compose up -d     # start fresh
python3 demo/seed.py     # re-seed
```

---

## Stopping the environment

```bash
# Stop the Karakeep server (keeps data)
docker compose stop

# Stop the emulator
VBoxManage controlvm "SailfishOS-5.0.0.62" acpipowerbutton
```
