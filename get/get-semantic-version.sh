#!/usr/bin/env bash
# Exit immediately if any command including those in a piped sequence exits with a non-zero status
set -euo pipefail

sanitize_branch_name() {
    echo "$1" | sed -e 's/[^a-zA-Z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

is_main_branch() {
    [[ "$1" =~ ^(master|main)$ ]]
}

is_dev_branch() {
    [[ "$1" =~ ^dev(elop)?(ment)?$ ]]
}

is_hotfix_branch() {
    [[ "$1" =~ ^hotfix(es)?[/-] ]]
}

# Get the current branch name
branch_name=$(git rev-parse --abbrev-ref HEAD)
echo "Branch: $branch_name"

# Get the default branch name
default_branch=""
if [[ -n "${DEFAULT_BRANCH:-}" ]]; then
    default_branch="$DEFAULT_BRANCH"
else
    remote_name=$(git remote)
    if [[ -n "$remote_name" ]]; then
        default_branch=$(git remote show "$remote_name" 2>/dev/null | grep "HEAD branch" | sed 's/.*: //')
    fi
fi
echo "Default branch: $default_branch"

# Get the most recent tag if it exists
latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [[ -z "$latest_tag" ]]; then
    echo "No tags found, starting at 0.0.0"
    latest_tag="v0.0.0"
else
    echo "Latest tag: $latest_tag"
fi

# Extract major, minor, patch from the tag
if [[ "$latest_tag" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)(-([a-zA-Z0-9.-]+))?$ ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    suffix="${BASH_REMATCH[5]:-}"
else
    # Default to 0.0.0 if no valid tag found
    major=0
    minor=0
    patch=0
    suffix=""
fi

echo "Parsed version: $major.$minor.$patch (suffix: $suffix)"

# Check for version bump markers in commit messages since the last tag
git_log_cmd="git log"
if git rev-parse "$latest_tag" >/dev/null 2>&1; then
    git_log_cmd="$git_log_cmd $latest_tag..HEAD"
fi

# Look for version bump indicators in commit messages
if $git_log_cmd --grep="#major" -i | grep -q "#major"; then
    echo "Found #major tag - incrementing major version"
    major=$((major + 1))
    minor=0
    patch=0
elif $git_log_cmd --grep="#minor" -i | grep -q "#minor"; then
    echo "Found #minor tag - incrementing minor version"
    minor=$((minor + 1))
    patch=0
else
    # Default increment patch version
    echo "No major/minor tags found - incrementing patch version"
    patch=$((patch + 1))
fi

# Create base version string
base_version="$major.$minor.$patch"

# Get commits since last version and short SHA
commit_count=$(git rev-list --count HEAD)
if git rev-parse "$latest_tag" >/dev/null 2>&1; then
    commits_since_tag=$(git rev-list --count "$latest_tag"..HEAD)
else
    commits_since_tag=$commit_count
fi
short_sha=$(git rev-parse --short=7 HEAD)

echo "Commits since version: $commits_since_tag"
echo "Short SHA: $short_sha"

# Build the semantic version string
if is_main_branch "$branch_name"; then
    # For main branches, just use the base version
    semantic="$base_version"
else
    # Sanitize branch name for use in version string
    safe_branch=$(sanitize_branch_name "$branch_name")
    # Adding short sha to prerelease section of semantic version instead of build section
    # because npm and Azure Artifacts do not like the + character that semver uses for build
    # See: https://semver.org/#spec-item-9
    semantic="$base_version-$safe_branch.$commits_since_tag.$short_sha"
fi

echo "Semantic version: $semantic"
