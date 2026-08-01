#!/usr/bin/env python3
"""Bounded deterministic property tests for untrusted CLI and data inputs."""

import copy
import json
import os
import pathlib
import random
import re
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = ROOT / "bin/sc-input"
SEED = 20260801
random.seed(SEED)


def run(*args: str, env: dict[str, str], expected: int = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [str(CLI), *args], env=env, text=True, capture_output=True, check=False, timeout=10
    )
    if result.returncode != expected:
        raise AssertionError(
            f"exit {result.returncode}, expected {expected}: {args!r}\n{result.stderr}"
        )
    return result


with tempfile.TemporaryDirectory(prefix="sc-input-property-") as temporary:
    temp = pathlib.Path(temporary)
    fixture = temp / "fixture"
    subprocess.run(
        [str(ROOT / "tests/fixtures/make-sysfs.sh"), str(fixture), "spacemouse"],
        check=True,
        timeout=10,
    )
    env = os.environ.copy()
    env.update(
        SC_INPUT_TEST_MODE="1",
        SC_INPUT_SYS_ROOT=str(fixture / "sys"),
        SC_INPUT_DEV_ROOT=str(fixture / "dev"),
    )
    base = json.loads(
        (ROOT / "manifests/3dconnexion/spacemouse-wireless-usb.json").read_text()
    )

    alphabet = " \t\n'\"\\;$()[]{}*?../ΩＡ"
    for index in range(64):
        mutation = "".join(random.choice(alphabet) for _ in range(random.randint(0, 48)))
        manifest = copy.deepcopy(base)
        manifest["id"] = f"safe-{index}{mutation}"
        path = temp / f"id-{index}.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        expected = 0 if re.fullmatch(r"[a-z0-9]+([.-][a-z0-9]+)*", manifest["id"]) else 65
        run("manifest", "validate", str(path), env=env, expected=expected)

    sentinels = ["ACCOUNT-998", "TOKEN-SECRET-998", "private-host-998"]
    for index, sentinel in enumerate(sentinels):
        manifest = copy.deepcopy(base)
        manifest["displayName"] = sentinel
        manifest["description"] = sentinel
        manifest["references"] = [
            {"type": "documentation", "url": f"https://example.invalid/{index}?value={sentinel}"}
        ]
        path = temp / f"privacy-{index}.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        report = run("report", "--manifest", str(path), "--privacy", "public", env=env).stdout
        if sentinel in report:
            raise AssertionError(f"public report leaked sentinel {sentinel!r}")

    (fixture / "sys/devices/pci0000:00/usb1/1-1/product").write_text(
        "/home/private-user/controller", encoding="utf-8"
    )
    home_report = run(
        "report", "--known-manifest", "3dconnexion-spacemouse-wireless-usb",
        "--privacy", "public", env=env
    ).stdout
    if "/home/private-user" in home_report:
        raise AssertionError("public report leaked an injected home path")

    for index in range(32):
        manifest = copy.deepcopy(base)
        manifest["devices"][0]["vendorId"] = "".join(
            random.choice("0123456789abcdef\"\n;MODE") for _ in range(random.randint(0, 12))
        )
        path = temp / f"renderer-{index}.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        if manifest["devices"][0]["vendorId"] == "256f":
            continue
        run("udev", "render", "--manifest", str(path), env=env, expected=65)

    valid_rule = run(
        "udev", "render", "--known-manifest", "3dconnexion-spacemouse-wireless-usb", env=env
    ).stdout
    forbidden = ("MODE=", "GROUP=", "OWNER=", "RUN=", "PROGRAM=", "IMPORT=", "SUBSYSTEM=\"input\"")
    if any(value in valid_rule for value in forbidden):
        raise AssertionError("whitelisted renderer emitted a forbidden directive")

    for index, token in enumerate(("", " ", "js1_", "js2_ ", "js1_x", "js2_y")):
        profile = temp / f"profile-{index}.xml"
        profile.write_text(f'<Controller><rebind input="{token}"/></Controller>', encoding="utf-8")
        expected = 0 if token == "js1_x" else 65
        if token == "js2_y":
            expected = 0
        run("star-citizen", "validate-profile", "--profile", str(profile), env=env, expected=expected)

    game_log = temp / "Game.log"
    game_log.write_text(
        "Connected joystick0: TOKEN-SECRET-998 $(command) {22210738-0000-0000-0000-504944564944}\n",
        encoding="utf-8",
    )
    log_report = run(
        "star-citizen", "game-log", "--game-log", str(game_log), "--privacy", "public", env=env
    ).stdout
    if "TOKEN-SECRET-998" in log_report or "22210738" in log_report:
        raise AssertionError("public Game.log output leaked attacker-controlled evidence")

    for index in range(32):
        option = "--unknown-" + "".join(random.choice("abc012-_") for _ in range(16))
        run("discover", option, env=env, expected=64)

print(f"PASS: deterministic parser, renderer, privacy, XML, Game.log, and CLI properties (seed {SEED})")
