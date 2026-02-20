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
import yaml

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
parser.add_argument(
    "--comment",
    help="Test split command with this comment body (requires --pr)",
)
parser.add_argument(
    "--pr",
    type=int,
    help="PR number to test split on (requires --comment)",
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
# Config File Loading
# ============================================================


def load_config():
    """
    Load configuration from fbchef_sync_bot.yaml if it exists.
    Returns a dict with config values (with defaults if file doesn't exist).
    """
    config_path = Path("fbchef_sync_bot.yaml")
    default_config = {
        "ignore_cookbooks": ["fb_init", "fb_init_sample"],
        "pr_labels": ["fbchef_sync_bot"],
        "issue_labels": ["fbchef_sync_bot"],
        "split_label": "split",
    }

    if not config_path.exists():
        logger.debug(f"Config file {config_path} not found, using defaults")
        return default_config

    try:
        with open(config_path, "r") as f:
            user_config = yaml.safe_load(f) or {}
        logger.info(f"Loading config from {config_path}")
        # Merge with defaults
        config = {**default_config, **user_config}
        logger.debug(
            f"Config loaded: ignore_cookbooks={config.get('ignore_cookbooks', [])}, "
            f"pr_labels={config.get('pr_labels', [])}, issue_labels={config.get('issue_labels', [])}, "
            f"split_label={config.get('split_label', 'split')}"
        )
        return config
    except Exception as e:
        logger.warning(
            f"Error loading config file {config_path}: {e}, using defaults"
        )
        return default_config


# Load config after logging is set up
CONFIG = load_config()

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
            "number,headRefName,labels",
        ]
    )
    prs = json.loads(output)
    logger.debug(f"Found {len(prs)} open PRs")
    split_label = CONFIG.get("split_label", "split")
    for pr in prs:
        if pr["headRefName"].startswith("sync/"):
            # Skip PRs that have been split
            pr_label_names = [label["name"] for label in pr.get("labels", [])]
            if split_label in pr_label_names:
                logger.debug(
                    f"Skipping split PR #{pr['number']} ({pr['headRefName']})"
                )
                continue
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


def get_branch_commits_with_trailers(branch):
    """
    Get branch commits that have Upstream-Commit trailers, returned as list of
    (branch_commit_hash, upstream_commit_hash) tuples in chronological order.
    """
    logger.debug(f"Getting branch commits with trailers for: {branch}")
    # Get all commits in branch with trailers (not just ones not in BASE_BRANCH)
    # This is important because user might be splitting a partially-merged PR
    log = git(
        "log",
        branch,
        "--grep=Upstream-Commit:",
        "--pretty=format:%H|%B%n---COMMIT-SEPARATOR---",
        "--reverse",
    )

    commits = []
    for entry in log.split("---COMMIT-SEPARATOR---"):
        entry = entry.strip()
        if not entry:
            continue

        lines = entry.split("|", 1)
        if len(lines) < 2:
            continue

        branch_commit = lines[0].strip()
        message = lines[1]

        # Extract upstream commit from trailer
        match = re.search(r"Upstream-Commit:\s*([0-9a-f]{40})", message)
        if match:
            upstream_commit = match.group(1)
            commits.append((branch_commit, upstream_commit))
            logger.debug(
                f"  Found: branch={branch_commit[:8]} -> upstream={upstream_commit[:8]}"
            )

    logger.debug(f"Found {len(commits)} branch commits with trailers")
    return commits

    logger.debug(f"Found {len(commits)} branch commits with trailers")
    return commits


def shortlog(commit):
    return git("log", "-1", "--pretty=%s", commit)


def pr_title_and_description_from_commits(commits):
    commit_entries = []
    for c in commits:
        commit_entries.append(f"* {shortlog(c)}\n  * Upstream-Commit: {c}\n")

    body = "Syncing upstream commits. The PRs are listed below. You can"
    body += " comment in this PR with commands see below. Also, this"
    body += " description is build for squash-merge, make sure you keep"
    body += " all the `Upstream-Commit` trailers in tact.\n\n"
    body += "\n".join(commit_entries)
    body += "\nTo split:\n```\n#bot split <shaA>-<shaB>\n```\n"

    title = f"Sync upstream ({len(commits)} commits)"

    return (title, body)


def update_pr_body(pr_number, commits):
    logger.debug(f"Updating PR #{pr_number} with {len(commits)} commits")
    (title, body) = pr_title_and_description_from_commits(commits)
    if not DRY_RUN:
        logger.info(f"Updating PR #{pr_number} title and body")
        cmd = [
            "gh",
            "pr",
            "edit",
            str(pr_number),
            "--title",
            title,
        ]
        # Add labels from config
        for label in CONFIG.get("pr_labels", []):
            cmd.extend(["--add-label", label])
        cmd.extend(["--body", body])
        run(cmd)
    else:
        logger.debug(f"[dry-run] Would update PR #{pr_number}")
        logger.info(
            f"[dry-run] Would update PR #{pr_number} title and body with {len(commits)} commits"
        )


def create_conflict_pr(branch, commit):
    logger.warning(f"Conflict detected while applying commit {commit[:8]}")
    logger.info("🚨 Conflict detected while applying commits")

    if not DRY_RUN:
        logger.info(f"Pushing conflict branch: {branch}")
        git("push", "-f", TARGET_REMOTE, branch)
    else:
        logger.debug(f"[dry-run] Would push conflict branch: {branch}")

    logger.info(
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


def create_conflict_issue(
    commit: str,
    cookbooks: list = None,
    conflict_details: str = None,
    dry_run: bool = False,
):
    """
    Create or update a GitHub issue for a sync conflict (single issue regardless of cookbooks involved).
    - commit: upstream commit SHA that caused the conflict
    - cookbooks: list of cookbook names involved (optional, for context)
    - conflict_details: optional string with conflict details to include in the issue
    - dry_run: if True, just log what would happen
    """
    logger.debug(
        f"Creating/updating conflict issue for commit {commit[:8]}, cookbooks: {cookbooks}"
    )
    if conflict_details:
        logger.debug(
            f"Conflict details provided: {len(conflict_details)} chars"
        )

    title = f"Sync conflict applying upstream commit {commit[:8]}"

    body_lines = [
        f"**⚠️ A conflict occurred** while applying upstream commit `{commit}`.",
        "\nThe changes are blocking the sync and must be resolved before continuing.",
    ]

    if cookbooks:
        body_lines.append(f"\n**Cookbooks involved:** {', '.join(cookbooks)}")

    if conflict_details:
        body_lines.append(
            "\n## Conflict Details\n\n```\n" + conflict_details + "\n```"
        )

    body_lines.append(
        "\n**Action required:** Please resolve the conflicts and push the changes."
    )

    body = "\n".join(body_lines)

    # Check for existing conflict issue for this commit
    existing_issue = None
    try:
        logger.debug(
            f"Searching for existing conflict issue for commit {commit[:8]}"
        )
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
                f"Sync conflict applying upstream commit {commit[:8]} in:title",
            ]
        )
        issues = json.loads(output)
        logger.debug(f"Found {len(issues)} potential matching issues")
        for issue in issues:
            # Check if the issue title matches this specific commit
            if commit[:8] in issue["title"]:
                logger.debug(
                    f"Found existing conflict issue #{issue['number']} for commit {commit[:8]}"
                )
                existing_issue = issue["number"]
                break
    except RuntimeError as e:
        logger.warning(f"Error searching for existing conflict issue: {e}")

    # Close any older conflict issues since this commit is now the blocker
    # Do this before the dry_run check so it happens in both modes
    logger.debug(
        f"Checking for older conflict issues to close (current blocker: {commit[:8]})"
    )
    close_resolved_conflict_issues(commit, dry_run=dry_run)

    if dry_run:
        if existing_issue:
            logger.info(
                f"[dry-run] Would update conflict issue #{existing_issue}:\n{title}\n{body}\n"
            )
        else:
            logger.info(
                f"[dry-run] Would create conflict issue:\n{title}\n{body}\n"
            )
        return

    try:
        if existing_issue:
            logger.info(
                f"Updating existing conflict issue #{existing_issue} for commit {commit[:8]}"
            )
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
            logger.info(
                f"✅ Conflict issue #{existing_issue} updated for commit {commit[:8]}"
            )
        else:
            logger.info(f"Creating conflict issue for commit {commit[:8]}")
            cmd = ["gh", "issue", "create", "--title", title, "--body", body]
            # Add labels from config
            for label in CONFIG.get("issue_labels", []):
                cmd.extend(["--label", label])
            run(cmd)
            logger.info(f"✅ Conflict issue created for commit {commit[:8]}")

    except RuntimeError as e:
        logger.error(f"Failed to create/update conflict issue: {e}")
        logger.info(f"❌ Failed to create/update conflict issue:\n{e}")


def close_resolved_conflict_issues(current_pointer: str, dry_run: bool = False):
    """
    Close any open conflict issues for commits that have been successfully synced past.
    - current_pointer: the current upstream commit pointer (commits before this are resolved)
    - dry_run: if True, just log what would happen
    """
    logger.debug(
        f"Checking for old conflict issues to close (current pointer: {current_pointer[:8]})"
    )

    try:
        # Search for all open conflict issues
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
                "Sync conflict applying upstream commit in:title",
            ]
        )
        issues = json.loads(output)
        logger.debug(f"Found {len(issues)} open conflict issues")

        for issue in issues:
            # Extract commit hash from title: "Sync conflict applying upstream commit <hash>"
            title = issue["title"]
            match = re.search(
                r"Sync conflict applying upstream commit ([0-9a-f]{8})", title
            )
            if not match:
                logger.debug(
                    f"Issue #{issue['number']} title doesn't match expected format: {title}"
                )
                continue

            issue_commit = match.group(1)
            logger.debug(
                f"Checking issue #{issue['number']} for commit {issue_commit}"
            )

            # Find the full commit hash from the short hash
            try:
                full_hash = git("rev-parse", "--verify", issue_commit)
                logger.debug(
                    f"Resolved {issue_commit} to full hash {full_hash[:8]}..."
                )
            except RuntimeError:
                logger.warning(
                    f"Could not resolve commit hash {issue_commit} from issue #{issue['number']}"
                )
                continue

            # Check if this commit has been synced (is it an ancestor of current_pointer, but not current_pointer itself)
            is_ancestor, _, _ = try_git(
                "merge-base", "--is-ancestor", full_hash, current_pointer
            )
            is_same = full_hash == current_pointer

            # Only close if it's an ancestor but NOT the current pointer (which is the active blocker)
            if is_ancestor and not is_same:
                logger.info(
                    f"Conflict issue #{issue['number']} for commit {issue_commit} is now resolved"
                )

                if dry_run:
                    logger.info(
                        f"[dry-run] Would close issue #{issue['number']}"
                    )
                else:
                    try:
                        comment = f"This conflict has been resolved. The sync has successfully moved past commit {issue_commit}."
                        run(
                            [
                                "gh",
                                "issue",
                                "comment",
                                str(issue["number"]),
                                "--body",
                                comment,
                            ]
                        )
                        run(["gh", "issue", "close", str(issue["number"])])
                        logger.info(
                            f"✅ Closed resolved conflict issue #{issue['number']}"
                        )
                    except RuntimeError as e:
                        logger.error(
                            f"Failed to close issue #{issue['number']}: {e}"
                        )
            else:
                logger.debug(
                    f"Conflict issue #{issue['number']} for commit {issue_commit} is still blocking"
                )

    except RuntimeError as e:
        logger.warning(f"Error searching for conflict issues to close: {e}")


def create_or_update_issue_for_local_changes(
    cookbooks: list,
    commit: str,
    dry_run: bool = False,
):
    """
    Create or update GitHub issues noting that local changes exist in cookbooks.
    Creates/updates one issue per cookbook (for non-blocking local changes after successful sync).
    - cookbooks: list of cookbook names
    - commit: upstream commit SHA of last successful sync
    - dry_run: if True, just log what would happen
    """
    logger.debug(f"Processing {len(cookbooks)} cookbooks with local changes")

    for cookbook in cookbooks:
        logger.debug(f"Creating/updating issue for cookbook: {cookbook}")
        title = f"Local changes detected in {cookbook}"
        body_lines = [
            f"The cookbook `{cookbook}` has local changes.",
            f"\n**ℹ️ These changes have not caused conflicts** (last sync: {commit[:8]}).",
            "\nHowever, they should be pushed upstream to avoid future conflicts.",
            "\n**Action required:** Please push these changes upstream.",
        ]

        body = "\n".join(body_lines)

        # Check for existing issue
        existing_issue = find_existing_issue_for_cookbook(cookbook)

        if dry_run:
            if existing_issue:
                logger.info(
                    f"[dry-run] Would update issue #{existing_issue}:\n{title}\n{body}\n"
                )
            else:
                logger.info(f"[dry-run] Would create issue:\n{title}\n{body}\n")
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
                logger.info(
                    f"✅ Issue #{existing_issue} updated for {cookbook}"
                )
            else:
                logger.info(f"Creating new issue for {cookbook}")
                cmd = [
                    "gh",
                    "issue",
                    "create",
                    "--title",
                    title,
                    "--body",
                    body,
                ]
                # Add labels from config
                for label in CONFIG.get("issue_labels", []):
                    cmd.extend(["--label", label])
                run(cmd)
                logger.info(f"✅ Issue created for local changes in {cookbook}")
        except RuntimeError as e:
            logger.error(f"Failed to create/update issue for {cookbook}: {e}")
            logger.info(
                f"❌ Failed to create/update issue for {cookbook}:\n{e}"
            )


def create_pr(branch, commits):
    logger.debug(f"Creating PR for branch {branch} with {len(commits)} commits")
    # Format: * <shortlog>\n  * Upstream-Commit: <full-sha>\n
    (title, body) = pr_title_and_description_from_commits(commits)
    if not DRY_RUN:
        logger.info(f"Creating PR: Sync upstream ({len(commits)} commits)")
        cmd = [
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
        ]
        # Add labels from config
        for label in CONFIG.get("pr_labels", []):
            cmd.extend(["--label", label])
        pr_url = run(cmd)
        # Extract PR number from URL (format: https://github.com/owner/repo/pull/123)
        pr_number = int(pr_url.strip().split("/")[-1])
        logger.debug(f"Created PR #{pr_number}: {pr_url}")
        return pr_number
    else:
        logger.debug(f"[dry-run] Would create PR {branch}")
        logger.info(
            f"[dry-run] Would create PR {branch} with {len(commits)} commits"
        )
        return None


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
        logger.info(
            "✅ Onboarding PR branch created. Open PR manually or via gh."
        )
    else:
        logger.debug(f"[dry-run] Created onboarding branch {branch}")
        logger.info(
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
        logger.info(f"✓ Commit {commit[:8]} already applied, skipping")
        return False

    logger.debug(
        f"Commit {commit[:8]} not already applied, proceeding with cherry-pick"
    )
    logger.info(f"🍒 Applying {commit}")

    # Use --no-commit so we can filter what gets applied
    # Disable rename detection to avoid false conflicts between local-only and upstream-only cookbooks
    logger.debug(
        "About to call try_git for cherry-pick --no-commit -X no-renames"
    )
    success, _, stderr = try_git(
        "cherry-pick", "--no-commit", "-X", "no-renames", commit
    )
    logger.debug(f"try_git returned: success={success}")

    if not success:
        logger.warning(f"Conflict during cherry-pick of {commit}")
        logger.debug(f"Cherry-pick stderr: {stderr[:200]}")
        logger.info("⚠️ Conflict detected during cherry-pick")

        # Check if this commit has already been applied
        # (e.g., from a previous run or manual application)
        try:
            if is_commit_already_applied(commit):
                logger.info(f"Commit {commit[:8]} already applied, skipping")
                logger.info(f"✓ Commit {commit[:8]} already applied, skipping")
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
                logger.info(
                    f"📦 Skipping {commit[:8]} - conflicts only in non-fb_* or non-imported cookbooks"
                )

                # Abort the cherry-pick to clean up
                logger.debug("Aborting cherry-pick for non-relevant conflicts")
                try:
                    git("cherry-pick", "--abort")
                    logger.debug("Cherry-pick aborted successfully")
                except RuntimeError as e:
                    logger.warning(
                        f"Cherry-pick abort failed ({str(e).rstrip()}), doing manual cleanup"
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
                        f"Cherry-pick abort failed: {str(e).rstrip()}, forcing cleanup"
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
                    f"Cherry-pick abort failed: {str(abort_err).rstrip()}, forcing cleanup"
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
            logger.info(f"⏭ No relevant changes in {commit[:8]}")
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
    Filters out cookbooks in the ignore_cookbooks config.
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

        # Filter out ignored cookbooks
        ignore_list = CONFIG.get("ignore_cookbooks", [])
        if ignore_list:
            original_count = len(cookbooks)
            cookbooks = [cb for cb in cookbooks if cb not in ignore_list]
            filtered_count = original_count - len(cookbooks)
            if filtered_count > 0:
                logger.debug(
                    f"Filtered out {filtered_count} ignored cookbooks: {[cb for cb in ignore_list if cb in output]}"
                )

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
    logger.info(f"📌 Global baseline detected at {base}")
    return base


def find_baseline_for_cookbook(cb):
    logger.debug(f"Finding baseline for cookbook: {cb}")
    logger.info(f"🔍 Detecting baseline for {cb}")
    upstream_commits = git(
        "rev-list", "--reverse", f"{UPSTREAM_REMOTE}/{UPSTREAM_BRANCH}"
    ).splitlines()
    logger.debug(f"Checking {len(upstream_commits)} upstream commits for {cb}")
    for commit in reversed(upstream_commits):
        ok, _, _ = try_git("diff", "--quiet", commit, "--", f"cookbooks/{cb}")
        if ok:
            logger.debug(f"Baseline match for {cb} at {commit}")
            logger.info(f"  ✓ matched at {commit}")
            return commit
    logger.debug(f"No baseline match found for {cb}")
    logger.info(f"  ✗ no match found")
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
        logger.info("🆕 No upstream pointer found. Entering onboarding mode.")

        baseline = detect_global_baseline()
        if not baseline:
            logger.error("Unable to detect upstream baseline")
            logger.info("❌ Unable to detect upstream baseline automatically.")
            sys.exit(1)

        create_onboarding_pr(baseline)
        return

    # ---------------------------
    # NORMAL SYNC MODE
    # ---------------------------
    logger.info("Entering normal sync mode")

    # Close any conflict issues for commits we've successfully synced past
    if pointer:
        logger.debug("Checking for resolved conflict issues to close")
        close_resolved_conflict_issues(pointer, dry_run=DRY_RUN)

    commits = upstream_commits_since(pointer)
    if not commits:
        logger.info("No new commits to sync")
        logger.info("✅ Already up to date.")
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
            logger.info(f"⏭ Skipping {c[:8]} (no relevant cookbooks)")
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
            logger.info(f"🚨 Conflict detected while applying {c[:8]}")

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

            # Create a single issue for the conflict
            create_conflict_issue(
                commit=c,
                cookbooks=cookbooks_to_report,
                conflict_details=conflict_details,
                dry_run=DRY_RUN,
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
            logger.info(
                f"⚠️ Found local changes in {len(cookbooks_with_local_changes)} cookbooks: {', '.join(cookbooks_with_local_changes)}"
            )

            # Create issues for each cookbook with local changes
            # Note: these didn't cause conflicts
            for cookbook in cookbooks_with_local_changes:
                logger.info(f"Creating issue for local changes in {cookbook}")
                # Use the last applied commit as reference
                create_or_update_issue_for_local_changes(
                    [cookbook],
                    commit=applied[-1],
                    dry_run=DRY_RUN,
                )
        else:
            logger.debug("No remaining local changes detected")

    # ---------------------------
    # Push branch and create/update PR
    # ---------------------------
    if applied:
        logger.info(f"Successfully applied {len(applied)} commits")

        # Close any conflict issues for commits we just successfully applied
        if applied and not conflict_occurred:
            logger.debug(
                "Closing conflict issues for successfully applied commits"
            )
            # The latest applied commit is our new effective pointer
            latest_applied = applied[-1]
            close_resolved_conflict_issues(latest_applied, dry_run=DRY_RUN)

        if not DRY_RUN:
            logger.info(f"Pushing branch {branch} to {TARGET_REMOTE}")
            git("push", "-f", TARGET_REMOTE, branch)
        else:
            logger.debug(f"[dry-run] Would push branch {branch}")

        pr = existing_sync_pr()
        if pr:
            logger.info(f"Updating existing PR #{pr['number']}")
            logger.info(f"🔄 Updating existing PR #{pr['number']}")
            update_pr_body(pr["number"], applied)
        else:
            logger.info("Creating new PR")
            create_pr(branch, applied)
    else:
        logger.info("No commits were applied")

    logger.info(f"Sync complete: {len(applied)} commits applied")
    logger.info(
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


def run_split(comment_body=None, pr_number=None):
    logger.info("Running split operation")

    # If called from command line with explicit params, use those
    if comment_body is None or pr_number is None:
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

    # If PR number was provided (command line mode), fetch that specific PR
    if pr_number:
        logger.debug(f"Fetching PR #{pr_number} details")
        pr_info = run(
            [
                "gh",
                "pr",
                "view",
                str(pr_number),
                "--json",
                "number,headRefName,body",
            ]
        )
        pr = json.loads(pr_info)
    else:
        pr = existing_sync_pr()
        if not pr:
            logger.warning("No existing sync PR found")
            return
        pr_number = pr["number"]
        # Fetch full PR details including body
        pr_info = run(
            [
                "gh",
                "pr",
                "view",
                str(pr_number),
                "--json",
                "number,headRefName,body",
            ]
        )
        pr = json.loads(pr_info)

    branch = pr["headRefName"]
    logger.debug(f"Processing split on branch: {branch}")
    git("checkout", branch)

    # Get branch commits mapped to their upstream commits (commits that were successfully applied)
    branch_commits = get_branch_commits_with_trailers(branch)
    upstream_to_branch = {
        upstream: branch for branch, upstream in branch_commits
    }

    # Get the intended upstream commits from the PR body
    pr_body = pr.get("body", "")
    intended_upstream = re.findall(
        r"Upstream-Commit:\s*([0-9a-f]{40})", pr_body
    )
    logger.debug(
        f"Found {len(intended_upstream)} intended upstream commits in PR body"
    )

    # Build map for lookup using intended commits (what SHOULD be synced)
    trailers_map = {t[:8]: t for t in intended_upstream}

    logger.debug(
        f"Intended upstream commits (first 8 chars): {list(trailers_map.keys())}"
    )
    logger.debug(f"Looking for start={start_sha[:8]}, end={end_sha[:8]}")

    start = trailers_map.get(start_sha[:8])
    end = trailers_map.get(end_sha[:8])

    if not start or not end:
        logger.error(f"Invalid split SHAs: start={start_sha}, end={end_sha}")
        logger.error(
            f"Intended upstream commits in PR: {list(trailers_map.keys())}"
        )
        raise Exception("Invalid split SHAs")

    start_idx = intended_upstream.index(start)
    end_idx = intended_upstream.index(end)

    # Ensure start_idx is before end_idx (handle user providing them in any order)
    if start_idx > end_idx:
        logger.debug(f"Swapping range order: {start_idx} > {end_idx}")
        start_idx, end_idx = end_idx, start_idx

    logger.debug(f"Split range indices: {start_idx} to {end_idx}")

    # Validate that the split is contiguous (from one end, not the middle)
    if start_idx != 0 and end_idx != len(intended_upstream) - 1:
        logger.error(
            f"Split must be from one end: either start at 0 or end at {len(intended_upstream) - 1}"
        )
        logger.error(f"Got: start_idx={start_idx}, end_idx={end_idx}")
        raise Exception(
            "Split must be contiguous from one end, not from the middle"
        )

    # Get the upstream commits for each range from the PR body
    first_range_upstream = intended_upstream[start_idx : end_idx + 1]
    second_range_upstream = (
        intended_upstream[end_idx + 1 :]
        if end_idx < len(intended_upstream) - 1
        else []
    )

    # Get the branch commits that were actually applied (some might have failed)
    first_range_branch = [
        upstream_to_branch.get(u) for u in first_range_upstream
    ]
    second_range_branch = [
        upstream_to_branch.get(u) for u in second_range_upstream
    ]

    logger.debug(
        f"First range: {len(first_range_upstream)} upstream commits, "
        f"Second range: {len(second_range_upstream)} upstream commits"
    )

    # Rewrite original PR branch
    logger.info(f"Rewriting original PR branch {branch} with first range")
    git("checkout", BASE_BRANCH)
    git("branch", "-D", branch)
    git("checkout", "-b", branch, BASE_BRANCH)

    for i, upstream_commit in enumerate(first_range_upstream):
        branch_commit = first_range_branch[i]
        if branch_commit:
            # Commit was already applied to branch, cherry-pick the resolved version
            logger.debug(
                f"Cherry-picking resolved branch commit {branch_commit[:8]} (upstream {upstream_commit[:8]})"
            )
            git("cherry-pick", branch_commit)
        else:
            # Commit not yet applied, use cherry_pick_with_trailer
            logger.debug(
                f"Applying upstream commit {upstream_commit[:8]} with trailer"
            )
            cherry_pick_with_trailer(upstream_commit)

    if not DRY_RUN:
        logger.info(f"Pushing rewritten branch {branch}")
        git("push", "-f", TARGET_REMOTE, branch)
        update_pr_body(pr_number, first_range_upstream)

        # Add split label to the first PR
        split_label = CONFIG.get("split_label", "split")
        logger.info(f"Adding {split_label} label to PR #{pr_number}")
        run(["gh", "pr", "edit", str(pr_number), "--add-label", split_label])
    else:
        logger.debug(f"[dry-run] Would rewrite {branch}")
        logger.info(
            f"[dry-run] Would rewrite original PR branch {branch} with {len(first_range_upstream)} commits"
        )

    if second_range_upstream:
        new_branch = f"sync/{second_range_upstream[0][:8]}"
        logger.info(f"Creating new branch {new_branch} for second range")
        git("checkout", "-b", new_branch, BASE_BRANCH)

        for i, upstream_commit in enumerate(second_range_upstream):
            branch_commit = second_range_branch[i]
            if branch_commit:
                # Commit was already applied to branch, cherry-pick the resolved version
                logger.debug(
                    f"Cherry-picking resolved branch commit {branch_commit[:8]} (upstream {upstream_commit[:8]})"
                )
                git("cherry-pick", branch_commit)
            else:
                # Commit not yet applied, use cherry_pick_with_trailer
                logger.debug(
                    f"Applying upstream commit {upstream_commit[:8]} with trailer"
                )
                cherry_pick_with_trailer(upstream_commit)

        if not DRY_RUN:
            logger.info(f"Pushing new branch {new_branch}")
            git("push", "-f", TARGET_REMOTE, new_branch)
            new_pr_number = create_pr(new_branch, second_range_upstream)

            if new_pr_number:
                # Add split label to the second PR
                split_label = CONFIG.get("split_label", "split")
                logger.info(
                    f"Adding {split_label} label to PR #{new_pr_number}"
                )
                run(
                    [
                        "gh",
                        "pr",
                        "edit",
                        str(new_pr_number),
                        "--add-label",
                        split_label,
                    ]
                )
        else:
            logger.debug(f"[dry-run] Would create new PR {new_branch}")
            logger.info(
                f"[dry-run] Would create new PR {new_branch} with {len(second_range_upstream)} commits"
            )
    else:
        logger.debug("No second range to process")


# ============================================================
# ENTRYPOINT
# ============================================================

if __name__ == "__main__":
    logger.info(f"Starting fbchef_sync_bot (log level: {args.log_level})")

    # Check for command-line split testing
    if args.comment and args.pr:
        logger.info(f"Running in command-line split test mode (PR #{args.pr})")
        run_split(comment_body=args.comment, pr_number=args.pr)
    elif args.comment or args.pr:
        logger.error("Both --comment and --pr must be provided together")
        sys.exit(1)
    elif GITHUB_EVENT_NAME == "issue_comment":
        logger.info("Running in split mode (issue_comment event)")
        run_split()
    else:
        logger.debug(f"GITHUB_EVENT_NAME: {GITHUB_EVENT_NAME}")
        logger.info("Running in sync mode")
        run_sync()
    logger.info("fbchef_sync_bot completed")
