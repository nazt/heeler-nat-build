#!/usr/bin/env python3
"""Fetch each oracle's Discord bot avatar into the Heeler plugin's config dir.

For every `pass discord/<name>-token` entry: read the bot token (never printed
or logged), ask Discord `GET /users/@me` for the avatar hash, download the
avatar once from the public CDN, and store it as `icons/<oracle>.png`. Also
writes `icons.json` ({"v":1,"icons":{"<oracle>":"<base64 png>"}}), the one file
the Heeler app reads over SSH. Run on the machine that owns the tokens.

  oracle-icons.py [--only NAME ...] [--dry-run]
"""
import base64, json, os, re, subprocess, sys, time, urllib.error, urllib.request

API = "https://discord.com/api/v10/users/@me"
CDN = "https://cdn.discordapp.com/avatars/{id}/{hash}.png?size=64"
UA = "DiscordBot (https://github.com/ZingerLittleBee/Heeler, 1) icon-fetch"
CONFIG = os.path.expanduser("~/.config/herdr/plugins/config/heeler")


def oracle_name(entry):
    """`foo-oracle-token` -> `foo`; `ccc-academy-token` -> `ccc-academy`."""
    if not entry.endswith("-token"):
        return None
    name = entry[: -len("-token")]
    return name[: -len("-oracle")] if name.endswith("-oracle") else name


def entries():
    out = subprocess.run(["pass", "ls", "discord"], capture_output=True, text=True, check=True).stdout
    for line in out.splitlines():
        line = re.sub(r"\x1b\[[0-9;]*m", "", line)
        entry = line.split()[-1] if line.strip() else ""
        if entry and entry != "discord" and oracle_name(entry):
            yield entry


def get(url, headers):
    req = urllib.request.Request(url, headers={"User-Agent": UA, **headers})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()


def main(argv):
    only = set(argv[argv.index("--only") + 1:]) if "--only" in argv else None
    dry = "--dry-run" in argv
    icons_dir = os.path.join(CONFIG, "icons")
    os.makedirs(icons_dir, mode=0o700, exist_ok=True)
    bundle, stats = {}, {"ok": 0, "no-avatar": 0, "failed": 0}
    for entry in entries():
        name = oracle_name(entry)
        if only and name not in only:
            continue
        if dry:
            print(f"{name}: would fetch")
            continue
        try:
            token = subprocess.run(["pass", "show", f"discord/{entry}"], capture_output=True,
                                   text=True, check=True).stdout.strip()
            me = json.loads(get(API, {"Authorization": f"Bot {token}"}))
            token = None
            if not me.get("avatar"):
                stats["no-avatar"] += 1
                print(f"{name}: no avatar")
                continue
            png = get(CDN.format(id=me["id"], hash=me["avatar"]), {})
            path = os.path.join(icons_dir, f"{name}.png")
            with open(path, "wb") as f:
                f.write(png)
            os.chmod(path, 0o600)
            bundle[name] = base64.b64encode(png).decode()
            stats["ok"] += 1
            print(f"{name}: ok {len(png)} bytes")
        except (subprocess.CalledProcessError, urllib.error.URLError, ValueError, KeyError) as e:
            stats["failed"] += 1
            print(f"{name}: failed ({type(e).__name__})")  # never the message: it may echo a header
        time.sleep(0.3)
    if not dry and bundle:
        target = os.path.join(CONFIG, "icons.json")
        tmp = target + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"v": 1, "icons": bundle}, f, separators=(",", ":"))
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
    print(json.dumps(stats))


if __name__ == "__main__":
    main(sys.argv[1:])
