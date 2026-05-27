#!/usr/bin/env bats

setup() {
    # Create a temporary directory for each test
    export TEMP_DIR="$(mktemp -d)"

    # Path to the script being tested
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../apply/apply-semantic-version.sh"

    init_test_repo() {
        cd "$TEMP_DIR"
        git init --initial-branch=main > /dev/null 2>&1
        git config --local user.email "test@example.com"
        git config --local user.name "Test User"

        echo "# Test repo" > README.md
        git add README.md
        git commit -m "Initial commit" > /dev/null 2>&1

        # Mock git push/ls-remote to avoid actual remote operations
        create_git_mock
    }

    create_git_mock() {
        mkdir -p "$TEMP_DIR/git_mock"

        # Create a mock git script that intercepts push and ls-remote
        cat > "$TEMP_DIR/git_mock/git" <<'EOF'
#!/usr/bin/bash
MOCK_DIR="$(dirname "$0")"

# Read current push and fail counts
push_count=0
if [ -f "$MOCK_DIR/push_call_count" ]; then
    push_count=$(cat "$MOCK_DIR/push_call_count")
fi

fail_count=0
if [ -f "$MOCK_DIR/push_fail_count" ]; then
    fail_count=$(cat "$MOCK_DIR/push_fail_count")
fi

if [[ "$1" == "push" ]]; then
    # Increment push call count
    push_count=$((push_count + 1))
    echo "$push_count" > "$MOCK_DIR/push_call_count"

    # Record the push arguments for verification
    echo "$@" > "$MOCK_DIR/push_args"

    # Fail if push_call_count <= push_fail_count

    if [ "$push_count" -le "$fail_count" ]; then
        echo "Error: failed to push ref to remote" >&2
        exit 1
    fi
    exit 0

elif [[ "$1" == "ls-remote" ]]; then
    # $4 is the refspec: refs/tags/vX.Y.Z
    tag="${4##refs/tags/}"

    # Return a match if tag is in remote_tags (always present), or in
    # remote_tags_after_push (only after at least one push attempt)
    if grep -qxF "$tag" "$MOCK_DIR/remote_tags" 2>/dev/null; then
        echo "abc123def456789012345678901234567890abcd	refs/tags/${tag}"
    elif [ "$push_count" -gt 0 ] && grep -qxF "$tag" "$MOCK_DIR/remote_tags_after_push" 2>/dev/null; then
        echo "abc123def456789012345678901234567890abcd	refs/tags/${tag}"
    fi
    exit 0

else
    # Pass through to the real git for all other commands
    /usr/bin/git "$@"
fi
EOF
        chmod +x "$TEMP_DIR/git_mock/git"

        # Mock sleep to avoid delays during tests
        cat > "$TEMP_DIR/git_mock/sleep" <<'EOF'
#!/usr/bin/bash
exit 0
EOF
        chmod +x "$TEMP_DIR/git_mock/sleep"

        # Add the mock directory to the front of PATH
        export PATH="$TEMP_DIR/git_mock:$PATH"
    }

    run_script() {
        cd "$TEMP_DIR"
        VERSION=$1 bash "$SCRIPT_PATH"
    }
}

teardown() {
    rm -rf "$TEMP_DIR"
}

@test "apply creates and pushes a version tag" {
    # Arrange
    init_test_repo

    # Act
    run run_script "1.2.3"

    # Assert
    [ "$status" -eq 0 ]

    # Check that the tag was created locally
    run git tag -l "v1.2.3"
    [ "$status" -eq 0 ]
    [ "$output" = "v1.2.3" ]

    # Check that push was called with the right arguments
    [ -f "$TEMP_DIR/git_mock/push_args" ]
    run cat "$TEMP_DIR/git_mock/push_args"
    [ "$status" -eq 0 ]
    [ "$output" = "push origin v1.2.3" ]
}

@test "apply fails when tag already exists" {
    # Arrange
    init_test_repo

    # Create a tag that will conflict
    git tag "v3.0.0"

    # Act - try to create the same tag again
    run run_script "3.0.0"

    # Assert - should fail
    [ "$status" -ne 0 ]

    # The push should not have been attempted
    [ ! -f "$TEMP_DIR/git_mock/push_args" ]
}

@test "apply fails when tag already exists on remote" {
    # Arrange
    init_test_repo
    echo "v2.0.0" > "$TEMP_DIR/git_mock/remote_tags"

    # Act
    run run_script "2.0.0"

    # Assert - should fail
    [ "$status" -ne 0 ]

    # The push should not have been attempted
    [ ! -f "$TEMP_DIR/git_mock/push_args" ]
}

@test "apply creates tag with complex semantic version" {
    # Arrange
    init_test_repo

    # Act - use a complex version with pre-release and build metadata
    run run_script "1.0.0-alpha.1+build.123"

    # Assert
    [ "$status" -eq 0 ]

    # Check that the tag was created with the full version
    run git tag -l "v1.0.0-alpha.1+build.123"
    [ "$status" -eq 0 ]
    [ "$output" = "v1.0.0-alpha.1+build.123" ]

    # Check push arguments
    run cat "$TEMP_DIR/git_mock/push_args"
    [ "$status" -eq 0 ]
    [ "$output" = "push origin v1.0.0-alpha.1+build.123" ]
}

@test "apply retries on push failure and succeeds" {
    # Arrange - fail the first 2 push attempts, succeed on the 3rd
    init_test_repo
    echo "2" > "$TEMP_DIR/git_mock/push_fail_count"

    # Act
    run run_script "1.2.3"

    # Assert
    [ "$status" -eq 0 ]

    # Verify it took exactly 3 push attempts
    run cat "$TEMP_DIR/git_mock/push_call_count"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "apply succeeds when tag confirmed on remote after push error" {
    # Arrange - push always fails, but tag appears on remote after first attempt
    init_test_repo
    echo "5" > "$TEMP_DIR/git_mock/push_fail_count"
    echo "v1.2.3" > "$TEMP_DIR/git_mock/remote_tags_after_push"

    # Act
    run run_script "1.2.3"

    # Assert - partial-success guard should fire after first failed push
    [ "$status" -eq 0 ]

    run cat "$TEMP_DIR/git_mock/push_call_count"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "apply fails after max retry attempts" {
    # Arrange - all 5 push attempts fail, tag never appears on remote
    init_test_repo
    echo "5" > "$TEMP_DIR/git_mock/push_fail_count"

    # Act
    run run_script "1.2.3"

    # Assert
    [ "$status" -ne 0 ]

    # Verify all 5 attempts were made
    run cat "$TEMP_DIR/git_mock/push_call_count"
    [ "$status" -eq 0 ]
    [ "$output" = "5" ]
}