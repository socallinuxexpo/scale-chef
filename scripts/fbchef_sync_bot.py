#!/usr/bin/env python3

import os
import sys
import subprocess
import re
import json
from typing import List
from pathlib import Path
import argparse

# ============================================================
# Environment / Defaults
# ============================================================

UPSTREAM_REMOTE = os.environ.get("UPSTREAM_REMOTE", "upstream")
UPSTREAM_BRANCH = os.environ.get("UPSTREAM_BRANCH", "main")
BASE_BRANCH = os.environ.get("BASE_BRANCH", "main")
TARGET_BRANCH = os.environ.get("TARGET_BRANCH", "main")
PR_BRANCH_PREFIX = os.environ.get("PR_BRANCH_PREFIX", "sync")
TARGET_REMOTE = os.environ.get("TARGET_REMOTE", "origin")

GITHUB_EVENT_NAME = os.environ.get("GITHUB_EVENT_NAME")
GITHUB_EVENT_PATH = os.environ.get("GITHUB_EVENT_PATH")

# ============================================================
# CLI
# ============================================================

parser = argparse.ArgumentParser(description="Facebook Chef Sync Bot")
parser.add_argument(
    "--dry-run",
    action="store_true",
    help="Do not push branches, PRs, or file issues",
)
parser.add_argument(
    "--force-bootstrapping",
    action="store_true",
    help="Ignore current upstream pointer",
)
args = parser.parse_args()
DRY_RUN = args.dry_run
FORCE_BOOTSTRAP = args.force_bootstrapping

# ============================================================
# Utilities
# ============================================================


def run(cmd, check=True):
    result = subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)}\n{result.stderr}")
    return result.stdout.strip()


def git(*args):
    return run(["git", *args])


def try_git(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    return result.returncode == 0, result.stdout, result.stderr


# ============================================================
# Global Pointer (from commit trailers on main)
# ============================================================


def get_global_pointer():
    log = git(
        "log", BASE_BRANCH, "--grep=Upstream-Commit:", "--pretty=format:%B"
    )
    matches = re.findall(r"Upstream-Commit:\s*([0-9a-f]{40})", log)
    if not matches:
        return None
    return matches[0]


# ============================================================
# Upstream
# ============================================================


def fetch_upstream():
    git("fetch", UPSTREAM_REMOTE)


def upstream_commits_since(pointer):
    if not pointer:
        return []

    return git(
        "rev-list",
        "--reverse",
        f"{pointer}..{UPSTREAM_REMOTE}/{UPSTREAM_BRANCH}",
    ).splitlines()


def touches_cookbooks(commit):
    files = git("show", "--name-only", "--pretty=format:", commit)
    return any(f.startswith("cookbooks/fb_") for f in files.splitlines())


# ============================================================
# PR & Issue Helpers
# ============================================================


def existing_sync_pr():
    output = run(
        [
            "gh",
            "pr",
            "list",
            "--base",
            BASE_BRANCH,
            "--state",
            "open",
            "--json",
            "number,headRefName",
        ]
    )
    prs = json.loads(output)
    for pr in prs:
        if pr["headRefName"].startswith("sync/"):
            return pr
    return None


def get_branch_trailers(branch):
    log = git("log", branch, "--grep=Upstream-Commit:", "--pretty=format:%B")
    return re.findall(r"Upstream-Commit:\s*([0-9a-f]{40})", log)


def shortlog(commit):
    return git("log", "-1", "--pretty=%s", commit)


def update_pr_body(pr_number, commits):
    lines = [f"- {c[:8]} {shortlog(c)}" for c in commits]
    body = "Syncing upstream commits:\n\n"
    body += "\n".join(lines)
    body += "\n\nTo split:\n  #bot split <shaA>-<shaB>\n"
    if not DRY_RUN:
        run(["gh", "pr", "edit", str(pr_number), "--body", body])
    else:
        print(
            f"[dry-run] Would update PR #{pr_number} body with commits:\n{lines}"
        )


def create_conflict_pr(branch, commit):
    print("🚨 Conflict detected while applying commits")

    if not DRY_RUN:
        git("push", "-f", TARGET_REMOTE, branch)

    print(
        f"""
Conflict encountered while applying {commit}.

Branch pushed: {branch}

Please resolve manually.
"""
    )


def create_issue_for_local_changes(
    cookbooks: list, commit: str, blocking: bool = False, dry_run: bool = False
):
    """
    Create a GitHub issue noting that local changes exist in one or more cookbooks.
    - cookbooks: list of cookbook names
    - commit: upstream commit SHA being applied
    - blocking: True if the local changes prevent the upstream commit from applying
    - dry_run: if True, just print what would happen
    """
    title = f"Local changes detected in {', '.join(cookbooks)}"
    body_lines = [
        f"The cookbook(s) `{', '.join(cookbooks)}` have local changes.",
    ]

    if blocking:
        body_lines.append(
            f"These changes are preventing upstream commit {commit[:8]} from applying cleanly."
        )
    else:
        body_lines.append(
            f"These changes exist while applying upstream commit {commit[:8]}, "
            "but did not block the cherry-pick."
        )

    body_lines.append("\nPlease push these changes upstream before syncing.")

    body = "\n".join(body_lines)

    if dry_run:
        print(f"[dry-run] Would create issue:\n{title}\n{body}\n")
        return

    # Create the issue via GitHub CLI
    try:
        run(["gh", "issue", "create", "--title", title, "--body", body])
        print(f"✅ Issue created for local changes in {', '.join(cookbooks)}")
    except RuntimeError as e:
        print(f"❌ Failed to create issue for {', '.join(cookbooks)}:\n{e}")


def create_pr(branch, commits):
    lines = [f"- {c[:8]} {shortlog(c)}" for c in commits]
    body = "Syncing upstream commits:\n\n" + "\n".join(lines)
    body += "\n\nTo split:\n  #bot split <shaA>-<shaB>\n"
    if not DRY_RUN:
        run(
            [
                "gh",
                "pr",
                "create",
                "--title",
                f"Sync upstream ({len(commits)} commits)",
                "--body",
                body,
                "--head",
                branch,
                "--base",
                BASE_BRANCH,
            ]
        )
    else:
        print(f"[dry-run] Would create PR {branch} with commits:\n{lines}")


def create_onboarding_pr(baseline):
    branch = f"{PR_BRANCH_PREFIX}/onboard"
    git("checkout", "-B", branch, TARGET_BRANCH)

    msg = f"""Initialize upstream sync baseline

This establishes the initial upstream pointer.

Upstream-Commit: {baseline}
"""
    git("commit", "--allow-empty", "-m", msg)
    if not DRY_RUN:
        git("push", "-f", TARGET_REMOTE, branch)
        print("✅ Onboarding PR branch created. Open PR manually or via gh.")
    else:
        print(
            f"[dry-run] Created onboarding branch {branch} with baseline {baseline}"
        )


# ============================================================
# Cherry-pick with trailer
# ============================================================


def cherry_pick_with_trailer(commit):
    print(f"🍒 Applying {commit}")
    success, _, stderr = try_git("cherry-pick", commit)
    if not success:
        print("⚠️ Conflict detected during cherry-pick")
        git("cherry-pick", "--abort")
        raise RuntimeError(f"Conflict while applying {commit}")

    message = git("log", "-1", "--pretty=%B")
    if "Upstream-Commit:" not in message:
        new_msg = message.strip() + f"\n\nUpstream-Commit: {commit}\n"
        git("commit", "--amend", "-m", new_msg)


# ============================================================
# SYNC MODE
# ============================================================


def get_current_pointer():
    log = git(
        "log",
        TARGET_BRANCH,
        "--grep=^Upstream-Commit:",
        "-n",
        "1",
        "--pretty=format:%B",
    )
    for line in log.splitlines():
        if line.startswith("Upstream-Commit:"):
            return line.split(":", 1)[1].strip()
    return None


def list_local_cookbooks():
    path = Path("cookbooks")
    if not path.exists():
        return []
    return [
        p.name
        for p in path.iterdir()
        if p.is_dir() and p.name.startswith("fb_")
    ]


def detect_global_baseline():
    cookbooks = list_local_cookbooks()
    if not cookbooks:
        return None

    matches = []
    for cb in cookbooks:
        commit = find_baseline_for_cookbook(cb)
        if commit:
            matches.append(commit)

    if not matches:
        return None

    base = matches[0]
    for m in matches[1:]:
        base = git("merge-base", base, m)

    print(f"📌 Global baseline detected at {base}")
    return base


def find_baseline_for_cookbook(cb):
    print(f"🔍 Detecting baseline for {cb}")
    upstream_commits = git(
        "rev-list", "--reverse", f"{UPSTREAM_REMOTE}/{UPSTREAM_BRANCH}"
    ).splitlines()
    for commit in reversed(upstream_commits):
        ok, _, _ = try_git("diff", "--quiet", commit, "--", f"cookbooks/{cb}")
        if ok:
            print(f"  ✓ matched at {commit}")
            return commit
    print(f"  ✗ no match found")
    return None


def detect_local_changes(cookbook):
    success, _, _ = try_git(
        "diff", "--quiet", TARGET_BRANCH, "--", f"cookbooks/{cookbook}"
    )
    return not success


def run_sync():
    fetch_upstream()
    git("checkout", TARGET_BRANCH)

    pointer = None if FORCE_BOOTSTRAP else get_current_pointer()

    # ---------------------------
    # ONBOARDING MODE
    # ---------------------------
    if pointer is None:
        print("🆕 No upstream pointer found. Entering onboarding mode.")

        baseline = detect_global_baseline()
        if not baseline:
            print("❌ Unable to detect upstream baseline automatically.")
            sys.exit(1)

        create_onboarding_pr(baseline)
        return

    # ---------------------------
    # NORMAL SYNC MODE
    # ---------------------------
    commits = upstream_commits_since(pointer)
    if not commits:
        print("✅ Already up to date.")
        return

    branch = f"{PR_BRANCH_PREFIX}/update"
    git("checkout", "-B", branch, TARGET_BRANCH)

    applied = []

    for c in commits:
        files = git("show", "--name-only", "--pretty=format:", c).splitlines()
        cookbooks_touched = {
            f.split("/")[1] for f in files if f.startswith("cookbooks/fb_")
        }
        relevant_cookbooks = cookbooks_touched & set(list_local_cookbooks())

        if not relevant_cookbooks:
            print(f"⏭ Skipping {c[:8]} (no relevant cookbooks)")
            continue

        local_changes = [
            cb for cb in relevant_cookbooks if detect_local_changes(cb)
        ]

        try:
            # Attempt cherry-pick
            cherry_pick_with_trailer(c)
            applied.append(c)

            if local_changes:
                print(f"⚠️ Local changes detected in {', '.join(local_changes)}")
                create_issue_for_local_changes(
                    local_changes, commit=c, blocking=False, dry_run=DRY_RUN
                )

        except RuntimeError:
            print(f"🚨 Conflict detected while applying {c[:8]}")
            if local_changes:
                create_issue_for_local_changes(
                    local_changes, commit=c, blocking=True, dry_run=DRY_RUN
                )
            create_conflict_pr(branch, c)
            break  # Stop immediately after first conflict

    # ---------------------------
    # Push branch and create/update PR
    # ---------------------------
    if applied:
        if not DRY_RUN:
            git("push", "-f", TARGET_REMOTE, branch)

        pr = existing_sync_pr()
        if pr:
            print(f"🔄 Updating existing PR #{pr['number']}")
            update_pr_body(pr["number"], applied)
        else:
            create_pr(branch, applied)

    print(
        f"\n✅ Sync complete. Branch: {branch}, commits applied: {len(applied)}"
    )


# ============================================================
# SPLIT MODE
# ============================================================


def parse_split_command(body):
    match = re.search(r"#bot\s+split\s+([0-9a-f]{7,40})-([0-9a-f]{7,40})", body)
    if not match:
        return None
    return match.group(1), match.group(2)


def run_split():
    with open(GITHUB_EVENT_PATH) as f:
        event = json.load(f)

    if "issue" not in event or "pull_request" not in event["issue"]:
        return

    comment_body = event["comment"]["body"]
    pr_number = event["issue"]["number"]

    parsed = parse_split_command(comment_body)
    if not parsed:
        return

    start_sha, end_sha = parsed
    pr = existing_sync_pr()
    if not pr:
        return

    branch = pr["headRefName"]
    git("checkout", branch)
    trailers = get_branch_trailers(branch)
    trailers_map = {t[:8]: t for t in trailers}
    start = trailers_map.get(start_sha[:8])
    end = trailers_map.get(end_sha[:8])

    if not start or not end:
        raise Exception("Invalid split SHAs")

    start_idx = trailers.index(start)
    end_idx = trailers.index(end)

    if start_idx > end_idx:
        raise Exception("Non-contiguous range")

    first_range = trailers[start_idx : end_idx + 1]
    second_range = trailers[end_idx + 1 :]

    # Rewrite original PR branch
    git("checkout", BASE_BRANCH)
    git("branch", "-D", branch)
    git("checkout", "-b", branch, BASE_BRANCH)
    for c in first_range:
        cherry_pick_with_trailer(c)

    if not DRY_RUN:
        git("push", "-f", TARGET_REMOTE, branch)
        update_pr_body(pr_number, first_range)
    else:
        print(
            f"[dry-run] Would rewrite original PR branch {branch} with commits {first_range}"
        )

    if second_range:
        new_branch = f"sync/{second_range[0][:8]}"
        git("checkout", "-b", new_branch, BASE_BRANCH)
        for c in second_range:
            cherry_pick_with_trailer(c)
        if not DRY_RUN:
            git("push", "-f", TARGET_REMOTE, new_branch)
            create_pr(new_branch, second_range)
        else:
            print(
                f"[dry-run] Would create new PR {new_branch} with commits {second_range}"
            )


# ============================================================
# ENTRYPOINT
# ============================================================

if __name__ == "__main__":
    if GITHUB_EVENT_NAME == "issue_comment":
        run_split()
    else:
        run_sync()
