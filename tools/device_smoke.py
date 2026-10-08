#!/usr/bin/env python3
"""Build Bsky Dreams for a TEST device, install, launch, screenshot — under one device lease.

    /usr/bin/python3 tools/device_smoke.py [iphone|ipad] [outdir] [view,view,…] [--no-build]

Views are AppTab raw values (home, search, notifications, dms, gallery, reader, …).
Signs in with the test account from tools/test-account.env (gitignored — never
commit it) via the DEBUG-only launch doors in AppStore.swift (DebugLaunchDoors).
Credentials go through DEVICECTL_CHILD_* env, never argv (visible in `ps`).

Test devices only (Ben's personal phone is off-limits): the iPhone 12 and the
iPad Pro 12.9" (the app is iPhone-only; on iPad it runs in compatibility mode).
Other Claude sessions share these devices, so everything happens inside ONE lease
(Archive-Watch/tools/devlease.py protocol — never steal a live lease). No simulators.
"""
import os, subprocess, sys, time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "Archive-Watch", "tools"))
os.environ.setdefault("DEVICE_LEASE_OWNER", "bsky-dreams")
import devlease  # noqa: E402

DEVICES = {
    "iphone": "B4E756E2-CBFA-5F63-8CEE-21D226637AF7",   # iPhone 12
    "ipad":   "AC5377E9-6053-51DE-8E65-D88A4E9345FA",   # iPad Pro 12.9" (5th gen)
}
BUNDLE = "app.bskydreams.ios"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DD = "/private/tmp/bsky-dreams-device-dd"
ENV = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer")


def run(cmd):
    r = subprocess.run(cmd, env=ENV, capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip().splitlines()
    print(f"$ {' '.join(cmd[:4])} … → exit {r.returncode}")
    if r.returncode:
        print("\n".join(out[-15:]))
    return r.returncode, "\n".join(out)


def test_account_env():
    """DEVICECTL_CHILD_-prefixed env from tools/test-account.env (absent = signed-out run)."""
    path = os.path.join(REPO, "tools", "test-account.env")
    child = {}
    if os.path.exists(path):
        for line in open(path):
            if "=" in line and not line.startswith("#"):
                k, v = line.strip().split("=", 1)
                child[f"DEVICECTL_CHILD_{k}"] = v
    return child


def launch_and_shoot(udid, outdir, key, view, extra_env):
    env = dict(ENV, **extra_env)
    if view:
        env["DEVICECTL_CHILD_BSKY_START_VIEW"] = view
    r = subprocess.run(["xcrun", "devicectl", "device", "process", "launch", "--device", udid,
                        "--terminate-existing", BUNDLE], env=env, capture_output=True, text=True)
    print(f"launch {view or 'default'} → exit {r.returncode}")
    time.sleep(10)   # sign-in + first feed load on a real network
    shot = os.path.join(outdir, f"{key}-{view or 'launch'}.png")
    run(["xcrun", "devicectl", "device", "capture", "screenshot", "--device", udid, "--destination", shot])
    print("screenshot:", shot)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    key = args[0] if len(args) > 0 else "iphone"
    outdir = args[1] if len(args) > 1 else "/private/tmp/bsky-dreams-device"
    views = [v for v in (args[2].split(",") if len(args) > 2 else [""])]
    build = "--no-build" not in sys.argv
    udid = DEVICES[key]
    os.makedirs(outdir, exist_ok=True)

    _, listing = run(["xcrun", "devicectl", "list", "devices"])
    line = next((l for l in listing.splitlines() if udid in l), "")
    if "available" not in line or "unavailable" in line:
        sys.exit(f"{key} is not available (wake/unlock it, or check Wi-Fi/cable): {line.strip()}")

    ok, holder = devlease.try_lease(key, task="bsky-dreams device smoke", ttl=1500)
    if not ok:
        sys.exit(f"{key} lease held by {holder} — not touching it")
    try:
        app = f"{DD}/Build/Products/Debug-iphoneos/Bsky Dreams.app"
        if build:
            code, _ = run(["xcodebuild", "-workspace", f"{REPO}/BskyDreams.xcworkspace", "-scheme", "Bsky Dreams",
                           "-configuration", "Debug", "-destination", f"id={udid}", "-derivedDataPath", DD,
                           "-allowProvisioningUpdates", "-allowProvisioningDeviceRegistration", "-quiet", "build"])
            if code:
                sys.exit("build failed")
            if run(["xcrun", "devicectl", "device", "install", "app", "--device", udid, app])[0]:
                sys.exit("install failed")
        creds = test_account_env()
        for view in views:
            launch_and_shoot(udid, outdir, key, view, creds)
    finally:
        devlease.release(key)


if __name__ == "__main__":
    main()
