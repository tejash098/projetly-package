import subprocess
import json
import os
import sys

DEBUG = True

# ─── Helpers ──────────────────────────────────────────────────────────────────

def log(msg):
    if DEBUG:
        print(f"[DEBUG] {msg}")

def run(cmd, capture=True, check=False):
    """Run a shell command and return the CompletedProcess result."""
    log(f"Running: {' '.join(cmd)}")
    # On Windows, executables like sf/npm are .cmd wrappers that only resolve
    # when the shell is involved (shell=True). Safe on Linux/Mac without it.
    result = subprocess.run(
        cmd,
        capture_output=capture,
        text=True,
        check=check,
        shell=is_windows(),
    )
    if capture and result.stdout:
        log(f"stdout: {result.stdout.strip()}")
    if capture and result.stderr:
        log(f"stderr: {result.stderr.strip()}")
    return result

def is_windows():
    return sys.platform.startswith("win")

# ─── Step 1: Node.js ──────────────────────────────────────────────────────────

def check_nodejs():
    print("\n[1/5] Checking Node.js...")
    result = run(["node", "-v"])
    if result.returncode != 0:
        print("ERROR: Node.js is not installed. Please install Node.js before proceeding.")
        sys.exit(1)
    version = result.stdout.strip()
    print(f"      Node.js found: {version}")
    return version

# ─── Step 2: Salesforce CLI ───────────────────────────────────────────────────

def _sf_version():
    result = run(["sf", "--version"])
    return result if result.returncode == 0 else None

def install_sf_cli():
    print("      Salesforce CLI not found. Installing via npm...")
    result = run(["npm", "install", "-g", "@salesforce/cli"], capture=False)
    if result.returncode != 0:
        print("ERROR: npm install failed. Check your npm installation and try again.")
        sys.exit(1)

def check_sf_cli():
    print("\n[2/5] Checking Salesforce CLI...")
    result = _sf_version()
    if result is None:
        install_sf_cli()
        result = _sf_version()
        if result is None:
            print("ERROR: Salesforce CLI installation failed. Install manually: npm install -g @salesforce/cli")
            sys.exit(1)
    version = result.stdout.strip().split("\n")[0]
    print(f"      Salesforce CLI found: {version}")
    return version

# ─── Step 3: Dev Hub ──────────────────────────────────────────────────────────

def _parse_dev_hub(output):
    try:
        data = json.loads(output)
        orgs = data.get("result", {})
        # sf org list --json returns {nonScratchOrgs: [...], scratchOrgs: [...]}
        all_orgs = []
        if isinstance(orgs, dict):
            all_orgs = orgs.get("nonScratchOrgs", []) + orgs.get("scratchOrgs", [])
        elif isinstance(orgs, list):
            all_orgs = orgs
        return any(org.get("isDevHub") for org in all_orgs)
    except (json.JSONDecodeError, AttributeError):
        return False

def check_dev_hub():
    print("\n[3/5] Checking Dev Hub authorization...")
    result = run(["sf", "org", "list", "--json"])
    if _parse_dev_hub(result.stdout):
        print("      Dev Hub: already authorized.")
        return True

    print("      No Dev Hub found. Launching web login...")
    login = run(
        ["sf", "org", "login", "web", "--set-default-dev-hub"],
        capture=False,
    )
    if login.returncode != 0:
        print("ERROR: Dev Hub authorization failed. Run manually: sf org login web --set-default-dev-hub")
        sys.exit(1)

    # Re-check after login
    result = run(["sf", "org", "list", "--json"])
    if not _parse_dev_hub(result.stdout):
        print("ERROR: Dev Hub still not found after login. Exiting.")
        sys.exit(1)

    print("      Dev Hub: authorized successfully.")
    return True

# ─── Step 4: Read package name ────────────────────────────────────────────────

def read_package_name():
    print("\n[4/5] Reading package name from sfdx-project.json...")
    project_file = os.path.join(os.getcwd(), "sfdx-project.json")
    if not os.path.exists(project_file):
        print("ERROR: sfdx-project.json not found in the current directory.")
        sys.exit(1)
    try:
        with open(project_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        packages = data.get("packageDirectories", [])
        for pkg in packages:
            name = pkg.get("package")
            if name:
                print(f"      Package name: {name}")
                return name
        print("ERROR: No 'package' key found in any packageDirectories entry.")
        sys.exit(1)
    except json.JSONDecodeError as exc:
        print(f"ERROR: Failed to parse sfdx-project.json: {exc}")
        sys.exit(1)

# ─── Step 5: Create package version ──────────────────────────────────────────

def create_package_version(package_name):
    print(f"\n[5/6] Creating package version for '{package_name}'...")
    print("      This may take several minutes (--wait 10)...")
    cmd = [
        "sf", "package", "version", "create",
        "--package", package_name,
        "--installation-key-bypass",
        "--wait", "10",
        "--code-coverage",
        "--json",
    ]
    result = run(cmd)
    if result.returncode != 0:
        print("ERROR: Package version creation failed.")
        print(result.stderr or result.stdout)
        sys.exit(1)

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        print(f"ERROR: Could not parse CLI response as JSON: {exc}")
        print(result.stdout)
        sys.exit(1)

    if data.get("status") != 0:
        msg = data.get("message") or data.get("name") or "Unknown error"
        print(f"ERROR: {msg}")
        sys.exit(1)

    result_data = data.get("result", {})
    subscriber_id = result_data.get("SubscriberPackageVersionId", "")
    install_url = result_data.get("InstallUrl") or (
        f"https://login.salesforce.com/packaging/installPackage.apexp?p0={subscriber_id}"
        if subscriber_id else ""
    )
    print("      Package version created successfully.")
    return subscriber_id, install_url

# ─── Step 6: Promote package version ─────────────────────────────────────────

def promote_package_version(subscriber_id):
    print(f"\n[6/6] Promoting package version '{subscriber_id}'...")
    # Promotion requires the 04t (SubscriberPackageVersionId) prefix
    if not subscriber_id or not subscriber_id.startswith("04t"):
        print("ERROR: Invalid Subscriber Package Version Id — cannot promote.")
        sys.exit(1)

    cmd = [
        "sf", "package", "version", "promote",
        "--package", subscriber_id,
        "--no-prompt",
        "--json",
    ]
    result = run(cmd)

    # sf may return exit code 0 even on some warnings; parse JSON to be sure
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        data = {}

    if result.returncode != 0 or data.get("status") != 0:
        msg = data.get("message") or result.stderr or result.stdout or "Unknown error"
        print(f"ERROR: Package promotion failed — {msg}")
        sys.exit(1)

    print("      Package version promoted to released successfully.")

# ─── Summary ──────────────────────────────────────────────────────────────────

def print_summary(node_ver, sf_ver, subscriber_id, install_url, promoted):
    print("\n" + "=" * 40)
    print("=== Deployment Summary ===")
    print("=" * 40)
    print(f"Node.js:                  OK ({node_ver})")
    print(f"Salesforce CLI:           OK ({sf_ver.split(' ')[0] if sf_ver else 'installed'})")
    print("Dev Hub:                  Authorized")
    print("Package Version Created:  SUCCESS")
    print(f"Package Version Promoted: {'SUCCESS' if promoted else 'SKIPPED'}")
    print()
    print(f"Subscriber Package Version Id: {subscriber_id}")
    print(f"Installation URL:              {install_url}")
    print("=" * 40)

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    print("Starting Salesforce 2GP deployment script...")
    node_ver     = check_nodejs()
    sf_ver       = check_sf_cli()
    check_dev_hub()
    package_name = read_package_name()
    subscriber_id, install_url = create_package_version(package_name)
    promote_package_version(subscriber_id)
    print_summary(node_ver, sf_ver, subscriber_id, install_url, promoted=True)

if __name__ == "__main__":
    main()