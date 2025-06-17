#!/usr/bin/env bats

setup() {
    # Create a temporary directory for each test
    export TEMP_DIR="$(mktemp -d)"

    # Path to the script being tested
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../get/get-semantic-version.sh"

    init_test_repo() {
        cd "$TEMP_DIR"
        git init --initial-branch=main > /dev/null 2>&1
        git config --local user.email "test@example.com"
        git config --local user.name "Test User"

        echo "# Test repo" > README.md
        git add README.md
        git commit -m "Initial commit" > /dev/null 2>&1
    }

    run_script() {
        cd "$TEMP_DIR"
        DEFAULT_BRANCH=main source "$SCRIPT_PATH"

        # Write variables to a file for access in test
        echo "branch_name=$branch_name" > "$TEMP_DIR/vars"
        echo "semantic=$semantic" >> "$TEMP_DIR/vars"
        echo "major=$major" >> "$TEMP_DIR/vars"
        echo "minor=$minor" >> "$TEMP_DIR/vars"
        echo "patch=$patch" >> "$TEMP_DIR/vars"
        echo "increment=$increment" >> "$TEMP_DIR/vars"
    }
}

teardown() {
    rm -rf "$TEMP_DIR"
}

@test "get reads default version on main" {
    # Arrange
    init_test_repo

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"

    [ "$status" -eq 0 ]
    [ "$branch_name" = "main" ]
    [ "$major" = "0" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "0.0.1" ]
}

@test "get preserves tag version and increments patch on main" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"

    [ "$status" -eq 0 ]
    [ "$branch_name" = "main" ]
    [ "$major" = "1" ]
    [ "$minor" = "2" ]
    [ "$patch" = "4" ]
    [ "$semantic" = "1.2.4" ]
}

@test "get handles minor version bump with #minor tag" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"
    echo "# Minor change" >> README.md
    git add README.md
    git commit -m "Add minor change #minor" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "main" ]
    [ "$major" = "1" ]
    [ "$minor" = "3" ]
    [ "$patch" = "0" ]
    [ "$semantic" = "1.3.0" ]
}

@test "get handles minor version bump with # minor tag" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"
    echo "# Minor change" >> README.md
    git add README.md
    git commit -m "Add minor change # minor" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "main" ]
    [ "$major" = "1" ]
    [ "$minor" = "3" ]
    [ "$patch" = "0" ]
    [ "$semantic" = "1.3.0" ]
}

@test "get handles major version bump with #major tag" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"
    echo "# Major change" >> README.md
    git add README.md
    git commit -m "Add major change #major" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "main" ]
    [ "$major" = "2" ]
    [ "$minor" = "0" ]
    [ "$patch" = "0" ]
    [ "$semantic" = "2.0.0" ]
}

@test "get handles major version bump with # major tag" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"
    echo "# Major change" >> README.md
    git add README.md
    git commit -m "Add major change # major" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "main" ]
    [ "$major" = "2" ]
    [ "$minor" = "0" ]
    [ "$patch" = "0" ]
    [ "$semantic" = "2.0.0" ]
}

@test "get formats feature branch version correctly" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git checkout -b "feature/new-thing" > /dev/null 2>&1
    echo "# Feature change" >> README.md
    git add README.md
    git commit -m "Add feature" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "feature/new-thing" ]
    [ "$major" = "0" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [[ "$semantic" =~ ^0\.0\.1-feature-new-thing\.[0-9]+\.[0-9a-f]{7}$ ]] # version with any valid increment and sha7
}

@test "get formats develop branch version correctly" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git checkout -b "develop" > /dev/null 2>&1
    echo "# Develop change" >> README.md
    git add README.md
    git commit -m "Add develop change" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "develop" ]
    [ "$major" = "0" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [[ "$semantic" =~ ^0\.0\.1-develop\.[0-9]+\.[0-9a-f]{7}$ ]] # version with any valid increment and sha7
}

@test "get correctly calculates increment counter for branches" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.0.0"
    git checkout -b "feature/test-increment" > /dev/null 2>&1
    # Make 3 commits
    for i in {1..3}; do
        echo "# Change $i" >> README.md
        git add README.md
        git commit -m "Commit $i" > /dev/null 2>&1
    done

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$increment" = "3" ]
    [[ "$semantic" =~ ^1\.0\.1-feature-test-increment\.3\.[0-9a-f]{7}$ ]] # version with any valid increment and sha7
}

@test "get sanitizes branch names with special characters" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git checkout -b "feature/special_chars@123!" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "feature/special_chars@123!" ]
    [[ "$semantic" =~ ^0\.0\.1-feature-special-chars-123\.[0-9]+\.[0-9a-f]{7}$ ]]
}

@test "get handles non-standard version tag formats" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"

    # Tag without v prefix
    git tag "1.5.2"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "1" ]
    [ "$minor" = "5" ]
    [ "$patch" = "3" ]
    [ "$semantic" = "1.5.3" ]
}

@test "get uses default version when tag format is invalid" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"

    # Invalid tag format
    git tag "version-x.y.z"

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "0" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "0.0.1" ]
}

@test "get handles branch name same as tag name" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"
    git checkout -b "v1.2.3" > /dev/null 2>&1
    echo "# Change on version branch" >> README.md
    git add README.md
    git commit -m "Add change on version branch" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "v1.2.3" ]
    [ "$major" = "1" ]
    [ "$minor" = "2" ]
    [ "$patch" = "4" ]
    [[ "$semantic" =~ ^1\.2\.4-v1-2-3\.[0-9]+\.[0-9a-f]{7}$ ]]
}

@test "get handles tags with prerelease information" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3-beta.1"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "1" ]
    [ "$minor" = "2" ]
    [ "$patch" = "4" ]
    [ "$semantic" = "1.2.4" ]
}

@test "get handles tags with prerelease information on feature branch" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git checkout -b "feature/new-thing" > /dev/null 2>&1
    git tag "v1.2.3-beta.1"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "1" ]
    [ "$minor" = "2" ]
    [ "$patch" = "4" ]
    [[ "$semantic" =~ ^1\.2\.4-feature-new-thing\.[0-9]+\.[0-9a-f]{7}$ ]]
}

@test "get handles multiple version tags on same commit" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    # Add multiple tags to the same commit
    git tag "v1.0.0"
    git tag "v2.0.0"
    git tag "v1.5.0"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "2" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "2.0.1" ]
}

@test "get handles detached HEAD state" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Get the commit hash and checkout to create detached HEAD
    commit_hash=$(git rev-parse HEAD)
    git checkout "$commit_hash" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [[ "$branch_name" == "HEAD" || "$branch_name" == "$commit_hash" ]]
    [ "$major" = "1" ]
    [ "$minor" = "2" ]
    [ "$patch" = "4" ]

    # Should format version with HEAD as the branch name
    [[ "$semantic" =~ ^1\.2\.4-HEAD\.[0-9]+\.[0-9a-f]{7}$ ]] || [[ "$semantic" =~ ^1\.2\.4-[0-9a-f]+\.[0-9]+\.[0-9a-f]{7}$ ]]
}

@test "get handles multiple bump tags with precedence" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"

    # Add multiple commits with different bump tags
    echo "# Minor change" >> README.md
    git add README.md
    git commit -m "Add minor change #minor" > /dev/null 2>&1
    echo "# Major change" >> README.md
    git add README.md
    git commit -m "Add major change #major" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]

    # Major should take precedence over minor
    [ "$major" = "2" ]
    [ "$minor" = "0" ]
    [ "$patch" = "0" ]
    [ "$semantic" = "2.0.0" ]
}

@test "get handles minor after major bump with correct precedence" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"

    # Add commits in reverse order (major then minor)
    echo "# Major change" >> README.md
    git add README.md
    git commit -m "Add major change #major" > /dev/null 2>&1
    echo "# Minor change" >> README.md
    git add README.md
    git commit -m "Add minor change #minor" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]

    # Major should still take precedence even if it came first
    [ "$major" = "2" ]
    [ "$minor" = "0" ]
    [ "$patch" = "0" ]
    [ "$semantic" = "2.0.0" ]
}

@test "get handles feature branch version bump tags correctly" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.2.3"

    # Create feature branch with version bump commits
    git checkout -b "feature/new-thing" > /dev/null 2>&1
    echo "# Major change" >> README.md
    git add README.md
    git commit -m "Add major change #major" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "feature/new-thing" ]

    # Should still apply the major version bump
    [ "$major" = "2" ]
    [ "$minor" = "0" ]
    [ "$patch" = "0" ]

    # Should include branch info in version string
    [[ "$semantic" =~ ^2\.0\.0-feature-new-thing\.[0-9]+\.[0-9a-f]{7}$ ]]
}

@test "get ignores tag on different branch" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"

    # Create a feature branch with a tag
    git checkout -b "feature/tagged" > /dev/null 2>&1
    echo "# Feature change" >> README.md
    git add README.md
    git commit -m "Add feature change" > /dev/null 2>&1
    git tag "v1.5.0"

    # Switch back to main and add a commit
    git checkout main > /dev/null 2>&1
    echo "# Main change" >> README.md
    git add README.md
    git commit -m "Add main change" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "main" ]

    # Should still use the tag from the other branch
    [ "$major" = "0" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "0.0.1" ]
}

@test "get truncates extremely long branch names to 32 characters" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"

    # Create a branch with a very long name (100+ characters)
    long_name="feature/extremely-long-branch-name-that-exceeds-normal-length-limits-and-might-cause-issues-with-formatting-or-display-in-some-contexts"
    git checkout -b "$long_name" > /dev/null 2>&1
    echo "# Change on long branch" >> README.md
    git add README.md
    git commit -m "Add change on long branch" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "$long_name" ]

    # Extract just the branch part from the semantic version
    if [[ "$semantic" =~ ^[0-9]+\.[0-9]+\.[0-9]+-([a-zA-Z0-9-]+)\.[0-9]+\.[0-9a-f]+$ ]]; then
        branch_part="${BASH_REMATCH[1]}"
    else
        echo "Failed to extract branch part from $semantic"
        return 1
    fi

    # Should be 32 characters
    [ ${#branch_part} -le 32 ]
    [ "$branch_part" = "feature-extremely-long-branch-na" ]
}

@test "get handles branch names with hyphen at truncation point" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"

    # Create a branch name with hyphens near the 32-character boundary
    # This will test handling of hyphens at the truncation point
    edge_case_name="feature/test-name-with-hyphen-a-t-exactly-the-truncation-boundary"
    git checkout -b "$edge_case_name" > /dev/null 2>&1
    echo "# Change on edge case branch" >> README.md
    git add README.md
    git commit -m "Add change on edge case branch" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "$edge_case_name" ]

    # Extract just the branch part from the semantic version
    if [[ "$semantic" =~ ^[0-9]+\.[0-9]+\.[0-9]+-([a-zA-Z0-9-]+)\.[0-9]+\.[0-9a-f]+$ ]]; then
        branch_part="${BASH_REMATCH[1]}"
    else
        echo "Failed to extract branch part from $semantic"
        return 1
    fi

    # Should be 31 characters
    [ ${#branch_part} -le 31 ]
    [ "$branch_part" = "feature-test-name-with-hyphen-a" ]

    # Should not end with a hyphen
    [[ "$branch_part" != *- ]]
}

@test "get sanitizes branch names with special characters at boundaries" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"

    # Create a branch with special characters at start, end, and 32-char boundary
    special_chars_name="feature/special_chars-with.dots_and-dashes"
    git checkout -b "$special_chars_name" > /dev/null 2>&1
    echo "# Change on special chars branch" >> README.md
    git add README.md
    git commit -m "Add change on special chars branch" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "$special_chars_name" ]

    # Extract just the branch part from the semantic version
    if [[ "$semantic" =~ ^[0-9]+\.[0-9]+\.[0-9]+-([a-zA-Z0-9-]+)\.[0-9]+\.[0-9a-f]+$ ]]; then
        branch_part="${BASH_REMATCH[1]}"
    else
        echo "Failed to extract branch part from $semantic"
        return 1
    fi

    echo $semantic
    echo $branch_part

     # Should be 32 characters
    [ ${#branch_part} -le 32 ]

    # Should not start or end with a hyphen
    [[ "$branch_part" != -* ]]
    [[ "$branch_part" != *- ]]

    # Should not have consecutive hyphens
    [[ ! "$branch_part" =~ -- ]]
}

@test "get handles tag with major version only" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v2"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "2" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "2.0.1" ]
}

@test "get handles tag with major version only without v prefix" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "3"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "3" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "3.0.1" ]
}

@test "get handles tag with major.minor version only" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.5"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "1" ]
    [ "$minor" = "5" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "1.5.1" ]
}

@test "get handles tag with major.minor version only without v prefix" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "2.3"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "2" ]
    [ "$minor" = "3" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "2.3.1" ]
}

@test "get selects highest version among mixed tag formats" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    # Add tags with different formats
    git tag "v1.0.0"
    git tag "v2"
    git tag "v1.5"
    git tag "v1.2.3"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "2" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "2.0.1" ]
}

@test "get correctly compares major.minor tags" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    # Add multiple major.minor tags
    git tag "v1.5"
    git tag "v1.10"  # Should be higher than v1.5
    git tag "v1.2"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "1" ]
    [ "$minor" = "10" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "1.10.1" ]
}

@test "get handles major-only tag on feature branch" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git checkout -b "feature/test" > /dev/null 2>&1
    git tag "v2"
    echo "# Feature change" >> README.md
    git add README.md
    git commit -m "Add feature" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$branch_name" = "feature/test" ]
    [ "$major" = "2" ]
    [ "$minor" = "0" ]
    [ "$patch" = "1" ]
    [[ "$semantic" =~ ^2\.0\.1-feature-test\.[0-9]+\.[0-9a-f]{7}$ ]]
}

@test "get handles major.minor tag with prerelease suffix" {
    # Arrange
    init_test_repo
    cd "$TEMP_DIR"
    git tag "v1.5-beta"
    echo "# Another change" >> README.md
    git add README.md
    git commit -m "Another commit" > /dev/null 2>&1

    # Act
    run run_script

    # Assert
    source "$TEMP_DIR/vars"
    [ "$status" -eq 0 ]
    [ "$major" = "1" ]
    [ "$minor" = "5" ]
    [ "$patch" = "1" ]
    [ "$semantic" = "1.5.1" ]
}
