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


def pr_title_and_description_from_commits(commits):
    commit_entries = []
    for c in commits:
        commit_entries.append(f"* {shortlog(c)}\n  * Upstream-Commit: {c}\n")

    body = "Syncing upstream commits. The PRs are listed below. You can"
    body += " comment in this PR with commands see below. Also, this"
    body += " description is build for squash-merge, make sure you keep"
    body += " all the Upstream-Commit trailers in tact.\n\n"
    body += "\n".join(commit_entries)
    body += "\nTo split:\n```\n#bot split <shaA>-<shaB>\n```\n"

    title = f"Sync upstream ({len(commits)} commits)"

    return (title, body)


def update_pr_body(pr_number, commits):
    logger.debug(f"Updating PR #{pr_number} with {len(commits)} commits")
    (title, body) = pr_title_and_description_from_commits(commits)
    if not DRY_RUN:
        logger.info(f"Updating PR #{pr_number} title and body")
        run(
            [
                "gh",
                "pr",
                "edit",
                str(pr_number),
                "--title",
                title,
                "--add-label",
                "fbchef_sync_bot",
                "--body",
                body,
            ]
        )
    else:
        logger.debug(f"[dry-run] Would update PR #{pr_number}")
        print(
            f"[dry-run] Would update PR #{pr_number} title and body with {len(commits)} commits"
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
    cookbooks: list,
    commit: str,
    blocking: bool = False,
    dry_run: bool = False,
    conflict_details: str = None,
):
    """
    Create or update GitHub issues noting that local changes exist in cookbooks.
    Creates/updates one issue per cookbook.
    - cookbooks: list of cookbook names
    - commit: upstream commit SHA being applied
    - blocking: True if the local changes prevent the upstream commit from applying
    - dry_run: if True, just print what would happen
    - conflict_details: optional string with conflict details to include in the issue
    """
    logger.debug(
        f"Processing {len(cookbooks)} cookbooks with local changes (blocking={blocking})"
    )
    if conflict_details:
        logger.debug(
            f"Conflict details provided: {len(conflict_details)} chars"
        )
    else:
        logger.debug("No conflict details provided")

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
            if conflict_details:
                body_lines.append(
                    "\n## Conflict Details\n\n```\n"
                    + conflict_details
                    + "\n```"
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
    # Format: * <shortlog>\n  * Upstream-Commit: <full-sha>\n
    (title, body) = pr_title_and_description_from_commits(commits)
    if not DRY_RUN:
        logger.info(f"Creating PR: Sync upstream ({len(commits)} commits)")
        pr_url = run(
            [
                "gh",
                "pr",
                "create",
                "--title",
                title,
                "--body",
                body,
                "--head",
                branch,
                "--base",
                BASE_BRANCH,
                "--label",
                "fbchef_sync_bot",
            ]
        )
    else:
        logger.debug(f"[dry-run] Would create PR {branch}")
        print(f"[dry-run] Would create PR {branch} with {len(commits)} commits")


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


def is_commit_already_applied(commit):
    """
    Check if the changes from a commit are already present in the current branch.
    This checks the actual content, not just the Upstream-Commit trailer.
    Returns True if all fb_* cookbook changes from the commit are already present.
    """
    logger.debug(f">>> is_commit_already_applied() ENTRY for {commit[:8]}")

    try:
        local_cookbooks = set(list_local_cookbooks())
        logger.debug(f"Got {len(local_cookbooks)} local cookbooks")
    except Exception as e:
        logger.error(f"Failed to get local cookbooks: {e}")
        return False

    # Get the diff for this commit, filtered to fb_* cookbooks we have locally
    try:
        # Get list of files changed in the commit that are in our local fb_* cookbooks
        files_in_commit = git(
            "show", "--name-only", "--pretty=format:", commit
        ).splitlines()
        relevant_files = []
        for file_path in files_in_commit:
            if file_path.startswith("cookbooks/fb_"):
                parts = file_path.split("/")
                if len(parts) >= 2:
                    cookbook = parts[1]
                    if cookbook in local_cookbooks:
                        relevant_files.append(file_path)

        if not relevant_files:
            logger.debug(f"No relevant fb_* files in commit {commit[:8]}")
            return True  # No relevant changes, consider it "applied"

        logger.debug(
            f"Checking {len(relevant_files)} relevant files from {commit[:8]}"
        )

        # For each relevant file, check if the content matches
        # by comparing the file at commit with the file at HEAD
        all_match = True
        for file_path in relevant_files:
            # Get the file content at the commit
            success_commit, content_at_commit, _ = try_git(
                "show", f"{commit}:{file_path}"
            )
            # Get the file content at HEAD
            success_head, content_at_head, _ = try_git(
                "show", f"HEAD:{file_path}"
            )

            if success_commit and success_head:
                if content_at_commit != content_at_head:
                    logger.debug(
                        f"File {file_path} differs between HEAD and {commit[:8]}"
                    )
                    all_match = False
                    break
            elif success_commit and not success_head:
                # File exists in commit but not in HEAD - changes not applied
                logger.debug(
                    f"File {file_path} exists in {commit[:8]} but not in HEAD"
                )
                all_match = False
                break
            elif not success_commit and success_head:
                # File deleted in commit but exists in HEAD - changes not applied
                logger.debug(
                    f"File {file_path} should be deleted per {commit[:8]} but exists in HEAD"
                )
                all_match = False
                break
            # If both don't exist, that's fine - continue checking

        if all_match:
            logger.info(f"All changes from {commit[:8]} are already present")
            return True
        else:
            logger.debug(f"Changes from {commit[:8]} are not fully present")
            return False

    except RuntimeError as e:
        logger.warning(f"Error checking if commit already applied: {e}")
        return False


def capture_conflict_details(conflicting_files):
    """
    Capture the conflict details for files that have conflicts.
    Returns a formatted string showing the conflicts.
    """
    logger.debug(
        f"capture_conflict_details() called with {len(conflicting_files)} files: {conflicting_files}"
    )
    details_lines = []

    for file_path in conflicting_files[
        :10
    ]:  # Limit to first 10 files to avoid huge issues
        logger.debug(f"Processing conflict file: {file_path}")
        details_lines.append(f"### {file_path}")
        details_lines.append("")

        # Try to read the conflicting file to show conflict markers
        try:
            with open(file_path, "r") as f:
                content = f.read()
                logger.debug(f"Read {len(content)} chars from {file_path}")
                # Only include up to first 100 lines or 5000 chars to keep issue manageable
                lines = content.splitlines()
                if len(lines) > 100:
                    content = "\n".join(lines[:100]) + "\n... (truncated)"
                elif len(content) > 5000:
                    content = content[:5000] + "\n... (truncated)"
                details_lines.append(content)
        except Exception as e:
            logger.warning(f"Could not read {file_path}: {e}")
            details_lines.append(f"(Could not read file: {e})")

        details_lines.append("")

    if len(conflicting_files) > 10:
        details_lines.append(
            f"... and {len(conflicting_files) - 10} more conflicting files"
        )

    result = "\n".join(details_lines)
    logger.debug(f"capture_conflict_details() returning {len(result)} chars")
    return result


def cherry_pick_with_trailer(commit):
    """
    Cherry-pick a commit with an Upstream-Commit trailer.
    Returns True if the commit was applied, False if it was skipped.
    Raises RuntimeError on conflicts.
    """
    logger.debug(f"=== cherry_pick_with_trailer() ENTRY for commit: {commit}")

    # Check if this commit has already been applied (optimization)
    logger.debug("Checking if commit already applied (pre-cherry-pick)")
    if is_commit_already_applied(commit):
        logger.info(f"Commit {commit[:8]} already applied, skipping")
        print(f"✓ Commit {commit[:8]} already applied, skipping")
        return False

    logger.debug(
        f"Commit {commit[:8]} not already applied, proceeding with cherry-pick"
    )
    print(f"🍒 Applying {commit}")

    # Use --no-commit so we can filter what gets applied
    logger.debug("About to call try_git for cherry-pick --no-commit")
    success, _, stderr = try_git("cherry-pick", "--no-commit", commit)
    logger.debug(f"try_git returned: success={success}")

    if not success:
        logger.warning(f"Conflict during cherry-pick of {commit}")
        logger.debug(f"Cherry-pick stderr: {stderr[:200]}")
        print("⚠️ Conflict detected during cherry-pick")

        # Check if this commit has already been applied
        # (e.g., from a previous run or manual application)
        try:
            if is_commit_already_applied(commit):
                logger.info(f"Commit {commit[:8]} already applied, skipping")
                print(f"✓ Commit {commit[:8]} already applied, skipping")
                git("cherry-pick", "--abort")
                return  # Successfully skip this commit
        except Exception as e:
            logger.warning(f"Error checking if commit already applied: {e}")
            # Continue with normal conflict handling

        # Capture basic conflict info before doing detailed processing
        # This ensures we have something to show even if later steps fail
        try:
            logger.debug("Capturing basic conflict info...")
            status_for_capture = git("status", "--porcelain")
            basic_conflict_files = []
            for line in status_for_capture.splitlines():
                if (
                    line.startswith(("DU ", "UD ", "DD ", "AA ", "UU "))
                    and len(line) > 2
                ):
                    basic_conflict_files.append(line[2:].lstrip())
            logger.debug(f"Basic conflict files found: {basic_conflict_files}")
            basic_conflict_info = (
                capture_conflict_details(basic_conflict_files)
                if basic_conflict_files
                else "No conflict details available"
            )
            logger.debug(
                f"Basic conflict info captured: {len(basic_conflict_info)} chars"
            )
        except Exception as e:
            logger.warning(f"Error capturing basic conflict info: {e}")
            basic_conflict_info = "Could not capture conflict details"

        logger.debug("Starting detailed conflict handling in try block...")
        try:
            # Check if conflicts are only in non-existent cookbooks or non-fb_* files
            # Get list of conflicting files
            status_output = git("status", "--porcelain")
            logger.debug(
                f"Status output has {len(status_output)} chars, {len(status_output.splitlines())} lines"
            )
            conflicting_files = []
            for line in status_output.splitlines():
                if len(line) > 2 and (
                    line.startswith("DU ")
                    or line.startswith("UD ")
                    or line.startswith("DD ")
                    or line.startswith("AA ")
                    or line.startswith("UU ")
                ):
                    # Conflict markers: DU=deleted by us, UD=deleted by them, etc.
                    file_path = line[2:].lstrip()
                    conflicting_files.append(file_path)
                    logger.debug(
                        f"Found conflict marker: {line[:2]} for file: {file_path}"
                    )

            logger.debug(f"Conflicting files: {conflicting_files}")

            # Categorize conflicts:
            # - Real conflicts: files in cookbooks/fb_* that exist locally
            # - Auto-resolve: everything else (non-existent fb_* cookbooks OR non-fb_* files)
            local_cookbooks = set(list_local_cookbooks())
            logger.debug(
                f"Local cookbooks for conflict check: {local_cookbooks}"
            )
            auto_resolve_conflicts = []
            real_conflicts = []

            for file_path in conflicting_files:
                if file_path.startswith("cookbooks/fb_"):
                    # This is an fb_* cookbook file
                    parts = file_path.split("/")
                    if len(parts) >= 2:
                        cookbook = parts[1]
                        if (
                            cookbook.startswith("fb_")
                            and cookbook in local_cookbooks
                        ):
                            # This is a real conflict in a local fb_* cookbook
                            logger.debug(
                                f"Real conflict: {file_path} (cookbook {cookbook} is local)"
                            )
                            real_conflicts.append(file_path)
                        else:
                            # Non-existent fb_* cookbook - auto-resolve
                            logger.debug(
                                f"Auto-resolve: {file_path} (cookbook {cookbook} not local)"
                            )
                            auto_resolve_conflicts.append(file_path)
                    else:
                        # Malformed path - auto-resolve to be safe
                        auto_resolve_conflicts.append(file_path)
                else:
                    # Not an fb_* cookbook file - ignore it
                    auto_resolve_conflicts.append(file_path)

            logger.debug(
                f"Conflict categorization complete: {len(real_conflicts)} real, {len(auto_resolve_conflicts)} auto-resolve"
            )

            if auto_resolve_conflicts and not real_conflicts:
                # All conflicts are in non-fb_* or non-imported cookbooks
                # Since we only care about fb_* cookbooks we have locally, abort and skip this commit
                logger.info(
                    f"All {len(auto_resolve_conflicts)} conflicts are in non-fb_* or non-imported files - skipping commit"
                )
                print(
                    f"📦 Skipping {commit[:8]} - conflicts only in non-fb_* or non-imported cookbooks"
                )

                # Abort the cherry-pick to clean up
                logger.debug("Aborting cherry-pick for non-relevant conflicts")
                try:
                    git("cherry-pick", "--abort")
                    logger.debug("Cherry-pick aborted successfully")
                except RuntimeError as e:
                    logger.warning(
                        f"Cherry-pick abort failed ({e}), doing manual cleanup"
                    )
                    # Manual cleanup: reset to HEAD and clean working directory
                    git("reset", "--hard", "HEAD")
                    git("clean", "-fd")
                    logger.debug("Manual cleanup completed")
                return False
            else:
                # Real conflicts exist in local fb_* cookbooks, abort
                logger.debug(
                    f"Real conflicts found: {len(real_conflicts)}, auto-resolve: {len(auto_resolve_conflicts)}"
                )
                if real_conflicts:
                    logger.warning(
                        f"Real conflicts in local fb_* cookbooks: {real_conflicts}"
                    )

                # Capture conflict details before aborting
                # Include all conflicting files in the details
                all_conflicts = (
                    real_conflicts if real_conflicts else conflicting_files
                )
                logger.debug(
                    f"About to capture conflict details for {len(all_conflicts)} files: {all_conflicts}"
                )

                try:
                    conflict_info = capture_conflict_details(all_conflicts)
                    logger.debug(
                        f"Captured conflict info ({len(conflict_info)} chars)"
                    )
                except Exception as e:
                    logger.warning(f"Failed to capture conflict details: {e}")
                    conflict_info = f"Could not capture conflict details: {e}"

                # Abort the cherry-pick and ensure clean state
                logger.debug("Aborting cherry-pick due to real conflicts")
                try:
                    git("cherry-pick", "--abort")
                    logger.debug("Cherry-pick aborted successfully")
                except RuntimeError as e:
                    logger.warning(
                        f"Cherry-pick abort failed: {e}, forcing cleanup"
                    )
                    # If abort fails, force cleanup
                    git("reset", "--hard", "HEAD")
                    git("clean", "-fd")
                    logger.debug("Forced cleanup completed")

                # Raise error with conflict details attached
                error = RuntimeError(f"Conflict while applying {commit}")
                error.conflict_details = conflict_info
                logger.debug(
                    f"Raising RuntimeError with conflict_details attached ({len(conflict_info)} chars)"
                )
                raise error
        except RuntimeError as error:
            logger.debug(
                f"Caught RuntimeError, checking for conflict_details attribute..."
            )
            # If a RuntimeError was raised but doesn't have conflict_details, add the basic info
            if not hasattr(error, "conflict_details"):
                logger.warning(
                    "RuntimeError raised without conflict_details, attaching basic info"
                )
                error.conflict_details = basic_conflict_info
                logger.debug(
                    f"Attached basic conflict info: {len(basic_conflict_info)} chars"
                )
            else:
                logger.debug(
                    f"RuntimeError already has conflict_details: {len(error.conflict_details)} chars"
                )
            raise
        except Exception as e:
            # For any other exception, wrap it with conflict details
            logger.error(
                f"Unexpected error during conflict handling: {type(e).__name__}: {e}"
            )

            # Clean up git state before raising
            logger.debug("Cleaning up git state after unexpected exception")
            try:
                git("cherry-pick", "--abort")
                logger.debug("Cherry-pick aborted successfully")
            except RuntimeError as abort_err:
                logger.warning(
                    f"Cherry-pick abort failed: {abort_err}, forcing cleanup"
                )
                try:
                    git("reset", "--hard", "HEAD")
                    git("clean", "-fd")
                    logger.debug("Forced cleanup completed")
                except Exception as cleanup_err:
                    logger.error(f"Even forced cleanup failed: {cleanup_err}")

            error = RuntimeError(
                f"Error while handling conflict in {commit}: {e}"
            )
            error.conflict_details = basic_conflict_info
            logger.debug(
                f"Wrapped unexpected exception with basic_conflict_info ({len(basic_conflict_info)} chars)"
            )
            raise error
    else:
        # No conflicts, but we still need to filter to only fb_* changes
        logger.debug(
            "Cherry-pick successful (no conflicts), filtering to fb_* changes only"
        )
        success = filter_and_commit_fb_changes(commit)
        if not success:
            logger.info(f"No fb_* cookbook changes to apply from {commit[:8]}")
            print(f"⏭ No relevant changes in {commit[:8]}")
            return False  # Successfully skipped - repo already cleaned up
        return True  # Successfully applied


def filter_and_commit_fb_changes(commit):
    """
    After a cherry-pick --no-commit, filter to only keep changes in cookbooks/fb_*
    that exist locally, then commit with the original message plus trailer.
    Returns True if changes were committed, False if no relevant changes.
    """
    local_cookbooks = set(list_local_cookbooks())

    # Reset the staging area
    git("reset", "HEAD")

    # Get all modified files from the cherry-pick
    status_output = git("status", "--porcelain")
    fb_files_to_add = []

    for line in status_output.splitlines():
        if line.strip():
            # Parse status line (format: "XY filename")
            # The status is 2 chars, followed immediately by the filename
            if len(line) > 2:
                status_code = line[:2]
                file_path = line[2:].lstrip()  # Remove any leading spaces
            else:
                continue  # Malformed line, skip

            logger.debug(
                f"Status line: '{line}' -> status='{status_code}' path='{file_path}'"
            )

            # Only process files in cookbooks/fb_* that exist locally
            if file_path.startswith("cookbooks/fb_"):
                parts = file_path.split("/")
                if len(parts) >= 2:
                    cookbook = parts[1]
                    if (
                        cookbook.startswith("fb_")
                        and cookbook in local_cookbooks
                    ):
                        fb_files_to_add.append(file_path)
                        logger.debug(f"Including fb_* file: {file_path}")
            else:
                logger.debug(f"Ignoring non-fb_* file: {file_path}")

    if not fb_files_to_add:
        logger.warning("No fb_* cookbook files to commit after filtering")
        # Clean up - abort the cherry-pick to clear git state
        logger.debug("Aborting cherry-pick and cleaning working directory")
        try:
            # Try to abort cherry-pick if one is in progress
            git("cherry-pick", "--abort")
        except RuntimeError:
            # If no cherry-pick in progress, just clean up manually
            logger.debug("No cherry-pick to abort, doing manual cleanup")
            git("reset", "--hard", "HEAD")
            git("clean", "-fd")
        return False

    # Stage only the fb_* cookbook files
    logger.info(f"Staging {len(fb_files_to_add)} fb_* cookbook files")
    for file_path in fb_files_to_add:
        git("add", file_path)

    # Get the original commit message
    message = git("show", "-s", "--format=%B", commit)

    # Add the upstream commit trailer
    if "Upstream-Commit:" not in message:
        message = message.strip() + f"\n\nUpstream-Commit: {commit}\n"

    # Commit the filtered changes
    logger.debug(f"Committing filtered changes with trailer")
    git("commit", "-m", message)

    return True


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
        "--grep=Upstream-Commit:",
        "-n",
        "1",
        "--pretty=format:%B",
    )

    # Find all Upstream-Commit trailers in this commit
    # Strip leading whitespace and bullets to handle nested format like:
    #   * <shortlog>
    #     * Upstream-Commit: <sha>
    trailers = []
    for line in log.splitlines():
        stripped = line.lstrip().lstrip("*").lstrip()
        if stripped.startswith("Upstream-Commit:"):
            commit = stripped.split(":", 1)[1].strip()
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
    """
    List cookbooks that exist in the current HEAD/branch.
    Uses git to check what's actually committed, not filesystem (which may have conflict files).
    """
    logger.debug("Listing local cookbooks from git")

    # Use git ls-tree to see what's actually in the current branch
    # This avoids being confused by temporary conflict files
    try:
        output = git("ls-tree", "--name-only", "HEAD", "cookbooks/")
        cookbooks = [
            name.replace("cookbooks/", "")
            for name in output.splitlines()
            if name.startswith("cookbooks/fb_")
        ]
        logger.debug(
            f"Found {len(cookbooks)} local cookbooks: {', '.join(cookbooks)}"
        )
        return cookbooks
    except RuntimeError:
        # If git command fails (e.g., empty repo), fall back to filesystem check
        logger.debug("Git ls-tree failed, falling back to filesystem check")
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
    conflict_occurred = False

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
            was_applied = cherry_pick_with_trailer(c)
            if was_applied:
                applied.append(c)
                logger.debug(f"Successfully applied {c[:8]}")
            else:
                logger.debug(
                    f"Skipped {c[:8]} (already applied or no relevant changes)"
                )
            # Don't create issues on successful applies - only on conflicts

        except RuntimeError as e:
            # Conflict occurred - check for local changes now
            conflict_occurred = True
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

            # Extract conflict details if available from the exception
            logger.debug(
                f"Exception type: {type(e).__name__}, has conflict_details attribute: {hasattr(e, 'conflict_details')}"
            )
            conflict_details = getattr(e, "conflict_details", None)
            logger.debug(
                f"Extracted conflict_details: {conflict_details[:200] if conflict_details else 'None'}"
            )

            create_or_update_issue_for_local_changes(
                cookbooks_to_report,
                commit=c,
                blocking=True,
                dry_run=DRY_RUN,
                conflict_details=conflict_details,
            )
            create_conflict_pr(branch, c)
            break  # Stop immediately after first conflict

    # ---------------------------
    # Check for remaining local changes after successful sync
    # ---------------------------
    # Only check for local changes if we didn't encounter a conflict
    # (conflicts mean we're not fully synced, so local change detection is unreliable)
    if applied and not conflict_occurred:
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
