#!/usr/bin/env python3
"""
Projetly 2GP Deployment Automation
------------------------------------
Handles: prerequisites check, org auth, source deploy, Apex tests,
package version create/promote/install, and full release pipeline.

Install dependencies first:
    pip install -r requirements.txt

Usage:
    python deployment.py <command> [options]
    python deployment.py --help
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

try:
    from colorama import Fore, Style, init as colorama_init
    colorama_init(autoreset=True)
    _C = True
except ImportError:
    _C = False

# ── Constants ─────────────────────────────────────────────────────────────────

PROJECT_ROOT   = Path(__file__).parent
SFDX_PROJECT   = PROJECT_ROOT / "sfdx-project.json"
PACKAGE_NAME   = "ProjetlyCore"
SOURCE_DIR     = "force-app"
API_VERSION    = "66.0"
DEFAULT_WAIT   = 30
DEFAULT_DEVHUB = "jaitej123"
DEFAULT_ORG    = "jaitej123"

# ── Output helpers ────────────────────────────────────────────────────────────

def _ok(msg):   print((Fore.GREEN  + "✓ " + Style.RESET_ALL if _C else "[OK]  ") + msg)
def _info(msg): print((Fore.CYAN   + "» " + Style.RESET_ALL if _C else "[..]  ") + msg)
def _warn(msg): print((Fore.YELLOW + "! " + Style.RESET_ALL if _C else "[!!]  ") + msg)
def _fail(msg): print((Fore.RED    + "✗ " + Style.RESET_ALL if _C else "[ERR] ") + msg, file=sys.stderr)

def _header(msg):
    bar = "─" * 62
    if _C:
        print(Fore.MAGENTA + Style.BRIGHT + f"\n{bar}\n  {msg}\n{bar}" + Style.RESET_ALL)
    else:
        print(f"\n{bar}\n  {msg}\n{bar}")

# ── Shell helper ──────────────────────────────────────────────────────────────

def _run(cmd: list, capture: bool = False) -> subprocess.CompletedProcess:
    """Run a CLI command. Streams output by default. Exits on non-zero return code."""
    _info("$ " + " ".join(str(c) for c in cmd))
    result = subprocess.run(
        cmd,
        capture_output=capture,
        text=True,
        cwd=PROJECT_ROOT,
    )
    if result.returncode != 0:
        _fail(f"Command failed (exit {result.returncode})")
        if capture and result.stderr:
            print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)
    return result

# ── sfdx-project.json helpers ─────────────────────────────────────────────────

def _load_project() -> dict:
    with open(SFDX_PROJECT, encoding="utf-8") as f:
        return json.load(f)

def _save_project(data: dict):
    with open(SFDX_PROJECT, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

def _current_version() -> str:
    for pkg in _load_project().get("packageDirectories", []):
        if pkg.get("package") == PACKAGE_NAME:
            return pkg.get("versionNumber", "unknown")
    return "unknown"

def _register_alias(alias: str, version_id: str):
    data = _load_project()
    data.setdefault("packageAliases", {})[alias] = version_id
    _save_project(data)
    _ok(f"Alias '{alias}' → {version_id} saved to sfdx-project.json")

def _extract_version_id(text: str) -> str | None:
    """Pull the first 04t… token out of command output."""
    for line in text.splitlines():
        for token in line.split():
            t = token.strip(",'\"")
            if t.startswith("04t") and len(t) >= 15:
                return t
    return None

# ── Individual steps ──────────────────────────────────────────────────────────

def _install_sf_cli():
    """Install Salesforce CLI via npm, or print manual instructions if npm is absent."""
    _warn("Salesforce CLI (sf) not found — attempting to install via npm...")
    npm = subprocess.run(["npm", "--version"], capture_output=True, text=True)
    if npm.returncode != 0:
        _fail("npm not found. Install Node.js first: https://nodejs.org/en/download")
        _fail("Then run:  npm install --global @salesforce/cli")
        sys.exit(1)
    result = subprocess.run(
        ["npm", "install", "--global", "@salesforce/cli"],
        text=True,
        cwd=PROJECT_ROOT,
    )
    if result.returncode != 0:
        _fail("Automatic install failed.")
        _fail("Install manually: https://developer.salesforce.com/tools/salesforcecli")
        sys.exit(1)
    _ok("Salesforce CLI installed successfully")


def check_prerequisites():
    _header("PREREQUISITES")

    if sys.version_info < (3, 9):
        _fail(f"Python 3.9+ required (found {sys.version_info.major}.{sys.version_info.minor})")
        sys.exit(1)
    _ok(f"Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")

    r = subprocess.run(["sf", "version"], capture_output=True, text=True)
    if r.returncode != 0:
        _install_sf_cli()
        r = subprocess.run(["sf", "version"], capture_output=True, text=True)
        if r.returncode != 0:
            _fail("Salesforce CLI still not available after install — restart your terminal and retry")
            sys.exit(1)
    _ok("Salesforce CLI: " + r.stdout.strip().splitlines()[0])

    if not SFDX_PROJECT.exists():
        _fail("sfdx-project.json not found — run this script from the project root")
        sys.exit(1)
    _ok("sfdx-project.json found")
    _ok(f"Current package version: {_current_version()}")


def check_devhub(devhub_alias: str = DEFAULT_DEVHUB):
    """Verify a Dev Hub org is authenticated; if none found, open browser login."""
    _header("DEV HUB CHECK")

    result = subprocess.run(
        ["sf", "org", "list", "--json"],
        capture_output=True, text=True, cwd=PROJECT_ROOT,
    )

    if result.returncode == 0:
        try:
            orgs = json.loads(result.stdout).get("result", {})
            dev_hubs = orgs.get("devHubs", [])
            if dev_hubs:
                aliases = [o.get("alias") or o.get("username", "") for o in dev_hubs]
                _ok(f"Dev Hub(s) already authenticated: {', '.join(a for a in aliases if a)}")
                return
        except (json.JSONDecodeError, AttributeError):
            pass

    _warn("No Dev Hub org found. Opening browser to authenticate one...")
    _run([
        "sf", "org", "login", "web",
        "--alias", devhub_alias,
        "--set-default-dev-hub",
    ])
    _ok(f"Dev Hub authenticated as '{devhub_alias}'")


def authenticate(alias: str, set_as_devhub: bool = False):
    _header(f"AUTHENTICATE{' (Dev Hub)' if set_as_devhub else ''}")
    cmd = ["sf", "org", "login", "web", "--alias", alias]
    if set_as_devhub:
        cmd.append("--set-default-dev-hub")
    _run(cmd)
    _ok(f"Authenticated as '{alias}'")


def deploy_source(target_org: str):
    _header("DEPLOY SOURCE")
    _run([
        "sf", "project", "deploy", "start",
        "--source-dir", SOURCE_DIR,
        "--target-org", target_org,
        "--api-version", API_VERSION,
    ])
    _ok("Source deployed successfully")


def run_tests(target_org: str, wait: int = DEFAULT_WAIT):
    _header("APEX TESTS")
    _run([
        "sf", "apex", "run", "test",
        "--test-level", "RunLocalTests",
        "--result-format", "human",
        "--target-org", target_org,
        "--wait", str(wait),
    ])
    _ok("All tests passed")


def create_scratch_org(alias: str, devhub: str, duration: int = 7):
    _header("CREATE SCRATCH ORG")
    _run([
        "sf", "org", "create", "scratch",
        "--definition-file", "config/project-scratch-def.json",
        "--alias", alias,
        "--target-dev-hub", devhub,
        "--duration-days", str(duration),
        "--set-default",
    ])
    _ok(f"Scratch org '{alias}' created (expires in {duration} days)")


def delete_scratch_org(alias: str):
    _header("DELETE SCRATCH ORG")
    _run(["sf", "org", "delete", "scratch", "--target-org", alias, "--no-prompt"])
    _ok(f"Scratch org '{alias}' deleted")


def create_package_version(devhub: str, installation_key: str = "", wait: int = DEFAULT_WAIT) -> str | None:
    _header("CREATE PACKAGE VERSION")
    cmd = [
        "sf", "package", "version", "create",
        "--package", PACKAGE_NAME,
        "--target-dev-hub", devhub,
        "--wait", str(wait),
        "--code-coverage",
        "--json",
    ]
    if installation_key:
        cmd += ["--installation-key", installation_key]
    else:
        cmd.append("--installation-key-bypass")

    result = _run(cmd, capture=True)

    version_id = None
    try:
        data = json.loads(result.stdout)
        version_id = (
            data.get("result", {}).get("SubscriberPackageVersionId")
            or _extract_version_id(result.stdout)
        )
    except (json.JSONDecodeError, AttributeError):
        version_id = _extract_version_id(result.stdout)

    if version_id:
        _ok(f"Package version created: {version_id}")
        base = _current_version().replace(".NEXT", "")
        _register_alias(f"{PACKAGE_NAME}@{base}", version_id)
    else:
        _warn("Could not extract version ID — update sfdx-project.json packageAliases manually")
        print(result.stdout)

    return version_id


def promote_package_version(version_id: str, devhub: str):
    _header("PROMOTE PACKAGE VERSION")
    _run([
        "sf", "package", "version", "promote",
        "--package", version_id,
        "--target-dev-hub", devhub,
        "--no-prompt",
    ])
    _ok(f"Version {version_id} promoted to Released")


def install_package(version_id: str, target_org: str, installation_key: str = "", wait: int = DEFAULT_WAIT):
    _header("INSTALL PACKAGE")
    cmd = [
        "sf", "package", "install",
        "--package", version_id,
        "--target-org", target_org,
        "--wait", str(wait),
        "--no-prompt",
    ]
    if installation_key:
        cmd += ["--installation-key", installation_key]
    _run(cmd)
    _ok(f"Package {version_id} installed into '{target_org}'")


def list_package_versions(devhub: str):
    _header("PACKAGE VERSIONS")
    _run([
        "sf", "package", "version", "list",
        "--package", PACKAGE_NAME,
        "--target-dev-hub", devhub,
        "--order-by", "CreatedDate",
        "--verbose",
    ])


# ── Workflow orchestration ────────────────────────────────────────────────────

def _workflow_check(args):
    check_prerequisites()


def _workflow_auth(args):
    authenticate(args.alias, args.devhub)


def _workflow_deploy(args):
    check_prerequisites()
    deploy_source(args.target_org)
    if not args.skip_tests:
        run_tests(args.target_org, args.wait)


def _workflow_test(args):
    check_prerequisites()
    run_tests(args.target_org, args.wait)


def _workflow_version(args):
    check_prerequisites()
    check_devhub(args.devhub)
    version_id = create_package_version(args.devhub, args.installation_key, args.wait)
    if args.promote and version_id:
        promote_package_version(version_id, args.devhub)


def _workflow_install(args):
    check_prerequisites()
    install_package(args.package, args.target_org, args.installation_key, args.wait)


def _workflow_versions(args):
    check_prerequisites()
    check_devhub(args.devhub)
    list_package_versions(args.devhub)


def _workflow_release(args):
    """
    Full release pipeline:
      1. Prerequisites check
      2. (Optional) Create scratch org
      3. Deploy source to scratch org
      4. Run all Apex tests
      5. Create package version
      6. (Optional) Promote to Released
      7. (Optional) Install into target org
      8. (Optional) Delete scratch org
    """
    check_prerequisites()
    check_devhub(args.devhub)

    if args.create_scratch:
        create_scratch_org(args.scratch_alias, args.devhub, args.duration)

    deploy_source(args.scratch_alias)
    run_tests(args.scratch_alias, args.wait)

    version_id = create_package_version(args.devhub, args.installation_key, args.wait)

    if args.promote and version_id:
        promote_package_version(version_id, args.devhub)

    if args.install and version_id:
        install_package(version_id, args.target_org, args.installation_key, args.wait)

    if args.delete_scratch and args.create_scratch:
        delete_scratch_org(args.scratch_alias)

    _header("RELEASE COMPLETE")
    if version_id:
        _ok(f"Version ID: {version_id}")
    else:
        _warn("Version ID unknown — check sfdx-project.json")


# ── CLI definition ────────────────────────────────────────────────────────────

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="deployment.py",
        description="Projetly 2GP deployment automation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
QUICK REFERENCE
───────────────────────────────────────────────────────────────
Install dependencies
  pip install -r requirements.txt

Verify setup
  python deployment.py check

Authenticate orgs
  python deployment.py auth --alias mydevhub --devhub
  python deployment.py auth --alias myorg

Deploy source to an org + run tests
  python deployment.py deploy --target-org myorg
  python deployment.py deploy --target-org myorg --skip-tests

Run tests only
  python deployment.py test --target-org myorg

Create a new package version
  python deployment.py version --devhub mydevhub
  python deployment.py version --devhub mydevhub --promote

Install a package version
  python deployment.py install --package 04tXXXXXXXXXXXXX --target-org myorg

List all package versions
  python deployment.py versions --devhub mydevhub

Full release pipeline (scratch org → deploy → test → build → promote)
  python deployment.py release \\
      --devhub mydevhub \\
      --scratch-alias projetly-scratch \\
      --create-scratch \\
      --promote \\
      --delete-scratch
───────────────────────────────────────────────────────────────
        """,
    )
    sub = p.add_subparsers(dest="command", required=True)

    def _devhub(s): s.add_argument("--devhub", default=DEFAULT_DEVHUB, metavar="ALIAS",
                                    help=f"Dev Hub org alias (default: {DEFAULT_DEVHUB})")
    def _org(s):    s.add_argument("--target-org", default=DEFAULT_ORG, metavar="ALIAS",
                                    help=f"Target org alias (default: {DEFAULT_ORG})")
    def _wait(s):   s.add_argument("--wait", type=int, default=DEFAULT_WAIT, metavar="MIN",
                                    help=f"Minutes to wait for async operations (default: {DEFAULT_WAIT})")
    def _key(s):    s.add_argument("--installation-key", default="", metavar="KEY",
                                    help="Package installation key (omit to bypass key requirement)")

    # ── check
    sub.add_parser("check", help="Verify prerequisites (SF CLI, Python, project file)")

    # ── auth
    auth_p = sub.add_parser("auth", help="Authenticate an org via browser (sf org login web)")
    auth_p.add_argument("--alias", required=True, metavar="ALIAS", help="Alias to assign to the authenticated org")
    auth_p.add_argument("--devhub", action="store_true", help="Set this org as the default Dev Hub")

    # ── deploy
    deploy_p = sub.add_parser("deploy", help="Deploy source metadata and run Apex tests")
    _org(deploy_p); _wait(deploy_p)
    deploy_p.add_argument("--skip-tests", action="store_true", help="Skip Apex test run after deploy")

    # ── test
    test_p = sub.add_parser("test", help="Run all local Apex tests")
    _org(test_p); _wait(test_p)

    # ── version
    ver_p = sub.add_parser("version", help="Create a new 2GP package version")
    _devhub(ver_p); _key(ver_p); _wait(ver_p)
    ver_p.add_argument("--promote", action="store_true",
                        help="Promote the version to Released immediately after creation")

    # ── install
    inst_p = sub.add_parser("install", help="Install a package version into an org")
    inst_p.add_argument("--package", required=True, metavar="ID_OR_ALIAS",
                         help="Subscriber package version ID (04tXXX) or sfdx-project.json alias")
    _org(inst_p); _key(inst_p); _wait(inst_p)

    # ── versions
    vlist_p = sub.add_parser("versions", help="List all versions of the package")
    _devhub(vlist_p)

    # ── release
    rel_p = sub.add_parser("release", help="Full release pipeline: scratch org → deploy → test → build → promote")
    _devhub(rel_p); _key(rel_p); _wait(rel_p)
    rel_p.add_argument("--scratch-alias", default="projetly-scratch", metavar="ALIAS",
                        help="Alias for the scratch org used during the build (default: projetly-scratch)")
    rel_p.add_argument("--create-scratch", action="store_true",
                        help="Create a fresh scratch org before deploying")
    rel_p.add_argument("--duration", type=int, default=7, metavar="DAYS",
                        help="Scratch org duration in days when --create-scratch is used (default: 7)")
    rel_p.add_argument("--delete-scratch", action="store_true",
                        help="Delete the scratch org after the build completes")
    rel_p.add_argument("--promote", action="store_true",
                        help="Promote the package version to Released after creation")
    rel_p.add_argument("--install", action="store_true",
                        help="Install the new version into --target-org after creation")
    _org(rel_p)

    return p


_DISPATCH = {
    "check":    _workflow_check,
    "auth":     _workflow_auth,
    "deploy":   _workflow_deploy,
    "test":     _workflow_test,
    "version":  _workflow_version,
    "install":  _workflow_install,
    "versions": _workflow_versions,
    "release":  _workflow_release,
}


def main():
    parser = _build_parser()
    args = parser.parse_args()
    _DISPATCH[args.command](args)


if __name__ == "__main__":
    main()
