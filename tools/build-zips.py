#!/usr/bin/env python3
"""Zip each machine directory into <dir>/<dir>.zip.

    tools/build-zips.py             every machine directory
    tools/build-zips.py hdsk acr    just those

A machine directory is a directory with a README.md. The zip holds every file in it (tracked or
not yet committed, minus the junk listed below) under a top-level <dir>/ folder, so unzipping
gives a folder that runs by itself. It never holds another .zip.

THE OUTPUT IS REPRODUCIBLE: files go in sorted order with a fixed timestamp and fixed
permissions, so the same files always make the same bytes. That is what lets CI rebuild every zip
and commit only the ones whose files changed -- git sees the rest as unchanged.
(Different zlib versions can compress differently. CI is the builder of record; a zip you build
on your own machine may differ from CI's even when the files are the same.)
"""
import os, shutil, subprocess, sys, tempfile, zipfile

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {"tests", "tests-from-altairsim", "tools"}
SKIP_NAMES = {".DS_Store", ".altairsim_history"}
FIXED_TIME = (2000, 1, 1, 0, 0, 0)


def machine_dirs():
    return sorted(d for d in os.listdir(root)
                  if d not in SKIP_DIRS and not d.startswith(".")
                  and os.path.isfile(os.path.join(root, d, "README.md")))


def files_in(d):
    out = subprocess.run(["git", "-C", root, "ls-files", "--cached", "--others",
                          "--exclude-standard", "-z", "--", d],
                         capture_output=True, check=True).stdout.decode()
    names = [p for p in out.split("\0") if p]
    return sorted(p for p in names
                  if os.path.isfile(os.path.join(root, p))
                  and not p.endswith(".zip")
                  and os.path.basename(p) not in SKIP_NAMES)


def build(d):
    dst = os.path.join(root, d, d + ".zip")
    names = files_in(d)          # list the files BEFORE the temp file exists
    fd, tmp = tempfile.mkstemp(suffix=".zip")
    os.close(fd)
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in names:
            info = zipfile.ZipInfo(p, FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            info.create_system = 3
            with open(os.path.join(root, p), "rb") as f:
                z.writestr(info, f.read(), compresslevel=9)
    shutil.move(tmp, dst)
    print("zip: %s/%s.zip" % (d, d))


dirs = [a.rstrip("/") for a in sys.argv[1:]] or machine_dirs()
for d in dirs:
    if not os.path.isfile(os.path.join(root, d, "README.md")):
        sys.exit("zip: %s has no README.md -- it is not a machine directory" % d)
    build(d)
