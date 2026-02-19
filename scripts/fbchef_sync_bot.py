#!/usr/bin/env python3

import os
import sys
import subprocess
import re
import json
import logging
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
    "-n",
    action="store_true",
    help="Do not push branches, PRs, or file issues",
)
parser.add_argument(
    "--force-bootstrapping",
    action="store_true",
    help="Ignore current upstream pointer",
)
parser.add_argument(
    "-l",
    "--log-level",
    default="info",
    choices=["debug", "info", "warning", "error", "critical"],
    help="Set the logging level (default: info)",
)
args = parser.parse_args()
DRY_RUN = args.dry_run
FORCE_BOOTSTRAP = args.force_bootstrapping

# ============================================================
# Logging Setup
# ============================================================

logging.basicConfig(
    level=getattr(logging, args.log_level.upper()),
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# ============================================================
# Utilities
# ============================================================


def run(cmd, check=True):
    logger.debug(f"Running command: {' '.join(cmd)}")
    result = subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    logger.debug(f"Command exit code: {result.returncode}")
    if check and result.returncode != 0:
        logger.error(f"Command failed: {' '.join(cmd)}\n{result.stderr}")
        raise RuntimeError(f"{' '.join(cmd)}\n{result.stderr}")
    return result.stdout.strip()


def git(*args):
    logger.debug(f"Git command: git {' '.join(args)}")
    return run(["git", *args])


def try_git(*args):
    logger.debug(f"Try git command: git {' '.join(args)}")
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    logger.debug(f"Try git exit code: {result.returncode}")
    return result.returncode == 0, result.stdout, result.stderr


# ============================================================
# Global Pointer (from commit trailers on main)
# ============================================================


def get_global_pointer():
    logger.debug(f"Getting global pointer from branch: {BASE_BRANCH}")
    log = git(
        "log", BASE_BRANCH, "--grep=Upstream-Commit:", "--pretty=format:%B"
    )
    matches = re.findall(r"Upstream-Commit:\s*([0-9a-f]{40})", log)
    if not matches:
        logger.debug("No global pointer found")
        return None
    logger.debug(f"Found global pointer: {matches[0]}")
    return matches[0]


# ============================================================
# Upstream
# ============================================================


def fetch_upstream():
    logger.info(f"Fetching upstream from remote: {UPSTREAM_REMOTE}")
    git("fetch", UPSTREAM_REMOTE)
    logger.debug("Upstream fetch completed")


def upstream_commits_since(pointer):
    if not pointer:
        logger.debug("No pointer provided, returning empty commit list")
        return []

    logger.debug(f"Getting upstream commits since: {pointer}")
    commits = git(
        "rev-list",
        "--reverse",
        f"{pointer}..{UPSTREAM_REMOTE}/{UPSTREAM_BRANCH}",
    ).splitlines()
    logger.debug(f"Found {len(commits)} upstream commits")
    return commits


def touches_cookbooks(commit):
    logger.debug(f"Checking if commit {commit[:8]} touches cookbooks")
    files = git("show", "--name-only", "--pretty=format:", commit)
    touches = any(f.startswith("cookbooks/fb_") for f in files.splitlines())
    logger.debug(f"Commit {commit[:8]} touches cookbooks: {touches}")
    return touches


# ============================================================
# PR & Issue Helpers
# ============================================================


def existing_sync_pr():
    logger.debug(
        f"Searching for existing sync PR on base branch: {BASE_BRANCH}"
    )
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
    logger.debug(f"Found {len(prs)} open PRs")
    for pr in prs:
        if pr["headRefName"].startswith("sync/"):
            logger.debug(
                f"Found existing sync PR: #{pr['number']} ({pr['headRefName']})"
            )
            return pr
    logger.debug("No existing sync PR found")
    return None


def get_branch_trailers(branch):
    logger.debug(f"Getting branch trailers for: {branch}")
    log = git("log", branch, "--grep=Upstream-Commit:", "--pretty=format:%B")
    trailers = re.findall(r"Upstream-Commit:\s*([0-9a-f]{40})", log)
    logger.debug(f"Found {len(trailers)} trailers")
    return trailers


def shortlog(commit):
    return git("log", "-1", "--pretty=%s", commit)


def update_pr_body(pr_number, commits):
    logger.debug(f"Updating PR #{pr_number} with {len(commits)} commits")
    lines = [f"- {c[:8]} {shortlog(c)}" for c in commits]
    body = "Syncing upstream commits:\n\n"
    body += "\n".join(lines)
    body += "\n\nTo split:\n  #bot split <shaA>-<shaB>\n"
    if not DRY_RUN:
        logger.info(f"Updating PR #{pr_number} body")
        run(["gh", "pr", "edit", str(pr_number), "--body", body])
    else:
        logger.debug(f"[dry-run] Would update PR #{pr_number}")
        print(
            f"[dry-run] Would update PR #{pr_number} body with commits:\n{lines}"
        )


def create_conflict_pr(branch, commit):
    logger.warning(f"Conflict detected while applying commit {commit[:8]}")
    print("🚨 Conflict detected while applying commits")

    if not DRY_RUN:
        logger.info(f"Pushing conflict branch: {branch}")
        git("push", "-f", TARGET_REMOTE, branch)
    else:
        logger.debug(f"[dry-run] Would push conflict branch: {branch}")

    print(
        f"""
Conflict encountered while applying {commit}.

Branch pushed: {branch}

Please resolve manually.
"""
    )


def find_existing_issue_for_cookbook(cookbook):
    """
    Find an existing open issue for a cookbook's local changes.
    Returns the issue number if found, None otherwise.
    """
    logger.debug(f"Searching for existing issue for cookbook: {cookbook}")
    try:
        output = run(
            [
                "gh",
                "issue",
                "list",
                "--state",
                "open",
                "--json",
                "number,title",
                "--search",
                f"Local changes detected in {cookbook} in:title",
            ]
        )
        issues = json.loads(output)
        logger.debug(f"Found {len(issues)} potential matching issues")
        for issue in issues:
            # Check if the issue title contains this specific cookbook
            if cookbook in issue["title"]:
                logger.debug(
                    f"Found existing issue #{issue['number']} for {cookbook}"
                )
                return issue["number"]
    except RuntimeError as e:
        logger.warning(f"Error searching for existing issue: {e}")
        pass
    logger.debug(f"No existing issue found for {cookbook}")
    return None


def create_or_update_issue_for_local_changes(
    cookbooks: list, commit: str, blocking: bool = False, dry_run: bool = False
):
    """
    Create or update GitHub issues noting that local changes exist in cookbooks.
    Creates/updates one issue per cookbook.
    - cookbooks: list of cookbook names
    - commit: upstream commit SHA being applied
    - blocking: True if the local changes prevent the upstream commit from applying
    - dry_run: if True, just print what would happen
    """
    logger.debug(
        f"Processing {len(cookbooks)} cookbooks with local changes (blocking={blocking})"
    )
    for cookbook in cookbooks:
        logger.debug(f"Creating/updating issue for cookbook: {cookbook}")
        title = f"Local changes detected in {cookbook}"
        body_lines = [
            f"The cookbook `{cookbook}` has local changes.",
        ]

        if blocking:
            body_lines.append(
                f"\n**⚠️ These changes caused a conflict** while applying upstream commit {commit[:8]}."
            )
            body_lines.append(
                "\nThe changes are blocking the sync and must be resolved before continuing."
            )
        else:
            body_lines.append(
                f"\n**ℹ️ These changes have not caused conflicts** (last sync: {commit[:8]})."
            )
            body_lines.append(
                "\nHowever, they should be pushed upstream to avoid future conflicts."
            )

        body_lines.append(
            "\n**Action required:** Please push these changes upstream."
        )
        body = "\n".join(body_lines)

        # Check for existing issue
        existing_issue = find_existing_issue_for_cookbook(cookbook)

        if dry_run:
            if existing_issue:
                print(
                    f"[dry-run] Would update issue #{existing_issue}:\n{title}\n{body}\n"
                )
            else:
                print(f"[dry-run] Would create issue:\n{title}\n{body}\n")
            continue

        # Update or create the issue via GitHub CLI
        try:
            if existing_issue:
                logger.info(f"Updating issue #{existing_issue} for {cookbook}")
                run(
                    [
                        "gh",
                        "issue",
                        "edit",
                        str(existing_issue),
                        "--body",
                        body,
                    ]
                )
                print(f"✅ Issue #{existing_issue} updated for {cookbook}")
            else:
                logger.info(f"Creating new issue for {cookbook}")
                run(["gh", "issue", "create", "--title", title, "--body", body])
                print(f"✅ Issue created for local changes in {cookbook}")
        except RuntimeError as e:
            logger.error(f"Failed to create/update issue for {cookbook}: {e}")
            print(f"❌ Failed to create/update issue for {cookbook}:\n{e}")


def create_pr(branch, commits):
    logger.debug(f"Creating PR for branch {branch} with {len(commits)} commits")
    lines = [f"- {c[:8]} {shortlog(c)}" for c in commits]
    body = "Syncing upstream commits:\n\n" + "\n".join(lines)
    body += "\n\nTo split:\n  #bot split <shaA>-<shaB>\n"
    if not DRY_RUN:
        logger.info(f"Creating PR: Sync upstream ({len(commits)} commits)")
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
        logger.debug(f"[dry-run] Would create PR {branch}")
        print(f"[dry-run] Would create PR {branch} with commits:\n{lines}")


def create_onboarding_pr(baseline):
    logger.info(f"Creating onboarding PR with baseline: {baseline}")
    branch = f"{PR_BRANCH_PREFIX}/onboard"
    logger.debug(f"Checking out branch: {branch}")
    git("checkout", "-B", branch, TARGET_BRANCH)

    msg = f"""Initialize upstream sync baseline

This establishes the initial upstream pointer.

Upstream-Commit: {baseline}
"""
    logger.debug("Creating empty commit with baseline")
    git("commit", "--allow-empty", "-m", msg)
    if not DRY_RUN:
        logger.info(f"Pushing onboarding branch to {TARGET_REMOTE}")
        git("push", "-f", TARGET_REMOTE, branch)
        print("✅ Onboarding PR branch created. Open PR manually or via gh.")
    else:
        logger.debug(f"[dry-run] Created onboarding branch {branch}")
        print(
            f"[dry-run] Created onboarding branch {branch} with baseline {baseline}"
        )


# ============================================================
# Cherry-pick with trailer
# ============================================================


def cherry_pick_with_trailer(commit):
    logger.debug(f"Cherry-picking commit: {commit}")
    print(f"🍒 Applying {commit}")
    success, _, stderr = try_git("cherry-pick", commit)
    if not success:
        logger.warning(f"Conflict during cherry-pick of {commit}")
        print("⚠️ Conflict detected during cherry-pick")
        git("cherry-pick", "--abort")
        raise RuntimeError(f"Conflict while applying {commit}")

    logger.debug("Cherry-pick successful, adding trailer if needed")
    message = git("log", "-1", "--pretty=%B")
    if "Upstream-Commit:" not in message:
        logger.debug(f"Adding Upstream-Commit trailer: {commit}")
        new_msg = message.strip() + f"\n\nUpstream-Commit: {commit}\n"
        git("commit", "--amend", "-m", new_msg)
    else:
        logger.debug("Upstream-Commit trailer already present")


# ============================================================
# SYNC MODE
# ============================================================


def get_current_pointer():
    logger.debug(f"Getting current pointer from {TARGET_BRANCH}")
    # Get the most recent commit with Upstream-Commit trailers
    # In case of squash-merge, this one commit will have multiple trailers
    log = git(
        "log",
        TARGET_BRANCH,
        "--grep=^Upstream-Commit:",
        "-n",
        "1",
        "--pretty=format:%B",
    )

    # Find all Upstream-Commit trailers in this commit
    trailers = []
    for line in log.splitlines():
        if line.startswith("Upstream-Commit:"):
            commit = line.split(":", 1)[1].strip()
            trailers.append(commit)

    if not trailers:
        logger.debug("No current pointer found")
        return None

    if len(trailers) == 1:
        logger.debug(f"Current pointer: {trailers[0]}")
        return trailers[0]

    # Multiple trailers found (squash-merge case)
    logger.debug(
        f"Found {len(trailers)} upstream commit trailers in most recent commit: {[t[:8] for t in trailers]}"
    )

    # Find which trailer is furthest along in upstream history
    most_recent = trailers[0]
    for trailer in trailers[1:]:
        # Check if most_recent is an ancestor of trailer (i.e., trailer is newer)
        is_ancestor, _, _ = try_git(
            "merge-base", "--is-ancestor", most_recent, trailer
        )
        if is_ancestor:
            # trailer is newer/further along, use it instead
            most_recent = trailer
            logger.debug(
                f"Updated pointer to {trailer[:8]} (further along than {most_recent[:8]})"
            )
        else:
            # Check if trailer is an ancestor of most_recent
            is_ancestor, _, _ = try_git(
                "merge-base", "--is-ancestor", trailer, most_recent
            )
            if not is_ancestor:
                # They're not related - this might be a problem, but use the first one
                logger.warning(
                    f"Commits {most_recent[:8]} and {trailer[:8]} are not related"
                )

    logger.debug(
        f"Current pointer (most recent in squash-merge): {most_recent}"
    )
    return most_recent


def list_local_cookbooks():
    logger.debug("Listing local cookbooks")
    path = Path("cookbooks")
    if not path.exists():
        logger.debug("cookbooks directory does not exist")
        return []
    cookbooks = [
        p.name
        for p in path.iterdir()
        if p.is_dir() and p.name.startswith("fb_")
    ]
    logger.debug(
        f"Found {len(cookbooks)} local cookbooks: {', '.join(cookbooks)}"
    )
    return cookbooks


def detect_global_baseline():
    logger.info("Detecting global baseline")
    cookbooks = list_local_cookbooks()
    if not cookbooks:
        logger.warning("No local cookbooks found")
        return None

    logger.debug(f"Checking baselines for {len(cookbooks)} cookbooks")
    matches = []
    for cb in cookbooks:
        commit = find_baseline_for_cookbook(cb)
        if commit:
            matches.append(commit)

    if not matches:
        logger.warning("No baseline matches found for any cookbook")
        return None

    logger.debug(f"Found {len(matches)} baseline matches")
    base = matches[0]
    for m in matches[1:]:
        logger.debug(f"Computing merge-base of {base[:8]} and {m[:8]}")
        base = git("merge-base", base, m)

    logger.info(f"Global baseline detected at {base}")
    print(f"📌 Global baseline detected at {base}")
    return base


def find_baseline_for_cookbook(cb):
    logger.debug(f"Finding baseline for cookbook: {cb}")
    print(f"🔍 Detecting baseline for {cb}")
    upstream_commits = git(
        "rev-list", "--reverse", f"{UPSTREAM_REMOTE}/{UPSTREAM_BRANCH}"
    ).splitlines()
    logger.debug(f"Checking {len(upstream_commits)} upstream commits for {cb}")
    for commit in reversed(upstream_commits):
        ok, _, _ = try_git("diff", "--quiet", commit, "--", f"cookbooks/{cb}")
        if ok:
            logger.debug(f"Baseline match for {cb} at {commit}")
            print(f"  ✓ matched at {commit}")
            return commit
    logger.debug(f"No baseline match found for {cb}")
    print(f"  ✗ no match found")
    return None


def detect_local_changes(cookbook):
    logger.debug(f"Detecting local changes in cookbook: {cookbook}")
    success, _, _ = try_git(
        "diff", "--quiet", TARGET_BRANCH, "--", f"cookbooks/{cookbook}"
    )
    has_changes = not success
    logger.debug(f"Cookbook {cookbook} has local changes: {has_changes}")
    return has_changes


def run_sync():
    logger.info("Starting sync operation")
    logger.debug(
        f"Config: UPSTREAM_REMOTE={UPSTREAM_REMOTE}, UPSTREAM_BRANCH={UPSTREAM_BRANCH}"
    )
    logger.debug(
        f"Config: TARGET_BRANCH={TARGET_BRANCH}, BASE_BRANCH={BASE_BRANCH}"
    )
    logger.debug(
        f"Config: DRY_RUN={DRY_RUN}, FORCE_BOOTSTRAP={FORCE_BOOTSTRAP}"
    )

    fetch_upstream()
    logger.debug(f"Checking out target branch: {TARGET_BRANCH}")
    git("checkout", TARGET_BRANCH)

    pointer = None if FORCE_BOOTSTRAP else get_current_pointer()
    logger.debug(f"Current upstream pointer: {pointer}")

    # ---------------------------
    # ONBOARDING MODE
    # ---------------------------
    if pointer is None:
        logger.info("No upstream pointer found, entering onboarding mode")
        print("🆕 No upstream pointer found. Entering onboarding mode.")

        baseline = detect_global_baseline()
        if not baseline:
            logger.error("Unable to detect upstream baseline")
            print("❌ Unable to detect upstream baseline automatically.")
            sys.exit(1)

        create_onboarding_pr(baseline)
        return

    # ---------------------------
    # NORMAL SYNC MODE
    # ---------------------------
    logger.info("Entering normal sync mode")
    commits = upstream_commits_since(pointer)
    if not commits:
        logger.info("No new commits to sync")
        print("✅ Already up to date.")
        return

    logger.info(f"Found {len(commits)} commits to process")
    branch = f"{PR_BRANCH_PREFIX}/update"
    logger.debug(f"Checking out sync branch: {branch}")
    git("checkout", "-B", branch, TARGET_BRANCH)

    applied = []

    for c in commits:
        logger.debug(f"Processing commit: {c[:8]}")
        files = git("show", "--name-only", "--pretty=format:", c).splitlines()
        cookbooks_touched = {
            f.split("/")[1] for f in files if f.startswith("cookbooks/fb_")
        }
        logger.debug(
            f"Cookbooks touched by {c[:8]}: {', '.join(cookbooks_touched) if cookbooks_touched else 'none'}"
        )
        relevant_cookbooks = cookbooks_touched & set(list_local_cookbooks())
        logger.debug(
            f"Relevant cookbooks: {', '.join(relevant_cookbooks) if relevant_cookbooks else 'none'}"
        )

        if not relevant_cookbooks:
            logger.debug(f"Skipping {c[:8]} - no relevant cookbooks")
            print(f"⏭ Skipping {c[:8]} (no relevant cookbooks)")
            continue

        try:
            # Attempt cherry-pick
            logger.info(f"Applying commit {c[:8]}")
            cherry_pick_with_trailer(c)
            applied.append(c)
            logger.debug(f"Successfully applied {c[:8]}")
            # Don't create issues on successful applies - only on conflicts

        except RuntimeError:
            # Conflict occurred - check for local changes now
            logger.error(f"Conflict while applying {c[:8]}")
            print(f"🚨 Conflict detected while applying {c[:8]}")

            local_changes = [
                cb for cb in relevant_cookbooks if detect_local_changes(cb)
            ]

            # Always create an issue for conflicting cookbooks
            # Prefer reporting specific local_changes if detected, otherwise report all relevant cookbooks
            cookbooks_to_report = (
                local_changes if local_changes else list(relevant_cookbooks)
            )

            if local_changes:
                logger.warning(
                    f"Conflict with detected local changes in: {', '.join(local_changes)}"
                )
            else:
                logger.warning(
                    f"Conflict in {', '.join(relevant_cookbooks)} (no specific local changes detected)"
                )

            create_or_update_issue_for_local_changes(
                cookbooks_to_report, commit=c, blocking=True, dry_run=DRY_RUN
            )
            create_conflict_pr(branch, c)
            break  # Stop immediately after first conflict

    # ---------------------------
    # Check for remaining local changes after successful sync
    # ---------------------------
    if applied:
        logger.info(
            "Checking for remaining local changes after successful sync"
        )
        all_local_cookbooks = list_local_cookbooks()
        cookbooks_with_local_changes = [
            cb for cb in all_local_cookbooks if detect_local_changes(cb)
        ]

        if cookbooks_with_local_changes:
            logger.warning(
                f"Found {len(cookbooks_with_local_changes)} cookbooks with local changes: {', '.join(cookbooks_with_local_changes)}"
            )
            print(
                f"⚠️ Found local changes in {len(cookbooks_with_local_changes)} cookbooks: {', '.join(cookbooks_with_local_changes)}"
            )

            # Create issues for each cookbook with local changes
            # Note: these didn't cause conflicts (blocking=False)
            for cookbook in cookbooks_with_local_changes:
                logger.info(f"Creating issue for local changes in {cookbook}")
                # Use the last applied commit as reference
                create_or_update_issue_for_local_changes(
                    [cookbook],
                    commit=applied[-1],
                    blocking=False,
                    dry_run=DRY_RUN,
                )
        else:
            logger.debug("No remaining local changes detected")

    # ---------------------------
    # Push branch and create/update PR
    # ---------------------------
    if applied:
        logger.info(f"Successfully applied {len(applied)} commits")
        if not DRY_RUN:
            logger.info(f"Pushing branch {branch} to {TARGET_REMOTE}")
            git("push", "-f", TARGET_REMOTE, branch)
        else:
            logger.debug(f"[dry-run] Would push branch {branch}")

        pr = existing_sync_pr()
        if pr:
            logger.info(f"Updating existing PR #{pr['number']}")
            print(f"🔄 Updating existing PR #{pr['number']}")
            update_pr_body(pr["number"], applied)
        else:
            logger.info("Creating new PR")
            create_pr(branch, applied)
    else:
        logger.info("No commits were applied")

    logger.info(f"Sync complete: {len(applied)} commits applied")
    print(
        f"\n✅ Sync complete. Branch: {branch}, commits applied: {len(applied)}"
    )


# ============================================================
# SPLIT MODE
# ============================================================


def parse_split_command(body):
    logger.debug("Parsing split command from comment body")
    match = re.search(r"#bot\s+split\s+([0-9a-f]{7,40})-([0-9a-f]{7,40})", body)
    if not match:
        logger.debug("No split command found")
        return None
    split_range = (match.group(1), match.group(2))
    logger.debug(f"Split command found: {split_range[0]}-{split_range[1]}")
    return split_range


def run_split():
    logger.info("Running split operation")
    logger.debug(f"Reading GitHub event from: {GITHUB_EVENT_PATH}")
    with open(GITHUB_EVENT_PATH) as f:
        event = json.load(f)

    if "issue" not in event or "pull_request" not in event["issue"]:
        logger.debug("Not a PR comment event, skipping")
        return

    comment_body = event["comment"]["body"]
    pr_number = event["issue"]["number"]
    logger.debug(f"Processing comment on PR #{pr_number}")

    parsed = parse_split_command(comment_body)
    if not parsed:
        logger.debug("No split command found in comment, skipping")
        return

    start_sha, end_sha = parsed
    logger.info(f"Split command: {start_sha}-{end_sha}")
    pr = existing_sync_pr()
    if not pr:
        logger.warning("No existing sync PR found")
        return

    branch = pr["headRefName"]
    logger.debug(f"Processing split on branch: {branch}")
    git("checkout", branch)
    trailers = get_branch_trailers(branch)
    trailers_map = {t[:8]: t for t in trailers}
    start = trailers_map.get(start_sha[:8])
    end = trailers_map.get(end_sha[:8])

    if not start or not end:
        logger.error(f"Invalid split SHAs: start={start_sha}, end={end_sha}")
        raise Exception("Invalid split SHAs")

    start_idx = trailers.index(start)
    end_idx = trailers.index(end)
    logger.debug(f"Split range indices: {start_idx} to {end_idx}")

    if start_idx > end_idx:
        logger.error(
            f"Non-contiguous range: start_idx={start_idx} > end_idx={end_idx}"
        )
        raise Exception("Non-contiguous range")

    first_range = trailers[start_idx : end_idx + 1]
    second_range = trailers[end_idx + 1 :]
    logger.debug(
        f"First range: {len(first_range)} commits, Second range: {len(second_range)} commits"
    )

    # Rewrite original PR branch
    logger.info(f"Rewriting original PR branch {branch} with first range")
    git("checkout", BASE_BRANCH)
    git("branch", "-D", branch)
    git("checkout", "-b", branch, BASE_BRANCH)
    for c in first_range:
        logger.debug(f"Cherry-picking {c[:8]} to first range")
        cherry_pick_with_trailer(c)

    if not DRY_RUN:
        logger.info(f"Pushing rewritten branch {branch}")
        git("push", "-f", TARGET_REMOTE, branch)
        update_pr_body(pr_number, first_range)
    else:
        logger.debug(f"[dry-run] Would rewrite {branch}")
        print(
            f"[dry-run] Would rewrite original PR branch {branch} with commits {first_range}"
        )

    if second_range:
        new_branch = f"sync/{second_range[0][:8]}"
        logger.info(f"Creating new branch {new_branch} for second range")
        git("checkout", "-b", new_branch, BASE_BRANCH)
        for c in second_range:
            logger.debug(f"Cherry-picking {c[:8]} to second range")
            cherry_pick_with_trailer(c)
        if not DRY_RUN:
            logger.info(f"Pushing new branch {new_branch}")
            git("push", "-f", TARGET_REMOTE, new_branch)
            create_pr(new_branch, second_range)
        else:
            logger.debug(f"[dry-run] Would create new PR {new_branch}")
            print(
                f"[dry-run] Would create new PR {new_branch} with commits {second_range}"
            )
    else:
        logger.debug("No second range to process")


# ============================================================
# ENTRYPOINT
# ============================================================

if __name__ == "__main__":
    logger.info(f"Starting fbchef_sync_bot (log level: {args.log_level})")
    logger.debug(f"GITHUB_EVENT_NAME: {GITHUB_EVENT_NAME}")
    if GITHUB_EVENT_NAME == "issue_comment":
        logger.info("Running in split mode (issue_comment event)")
        run_split()
    else:
        logger.info("Running in sync mode")
        run_sync()
    logger.info("fbchef_sync_bot completed")
