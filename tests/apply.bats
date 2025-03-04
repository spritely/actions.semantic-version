#!/usr/bin/env bats

setup() {
    # Create a temporary directory for each test
    export TEMP_DIR="$(mktemp -d)"

    # Path to the script being tested
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../apply/apply-semantic-version.sh"

    init_test_repo() {
        cd "$TEMP_DIR"
        git init --initial-branch=master > /dev/null 2>&1
        git config --local user.email "test@example.com"
        git config --local user.name "Test User"

        echo "# Test repo" > README.md
        git add README.md
        git commit -m "Initial commit" > /dev/null 2>&1

        # Mock git push to avoid actual remote operations
        create_git_push_mock
    }

    # Create a mock for git push to avoid actual remote operations
    create_git_push_mock() {
        mkdir -p "$TEMP_DIR/git_mock"

        # Create a mock git push script
        cat > "$TEMP_DIR/git_mock/git" <<'EOF'
#!/usr/bin/bash
if [[ "$1" == "push" ]]; then
    # Record the push command for verification
    echo "$@" > "$(dirname "$0")/push_args"
    exit 0
else
    # Pass through to the real git for other commands
    /usr/bin/git "$@"
fi
EOF
        chmod +x "$TEMP_DIR/git_mock/git"

        # Add the mock directory to the PATH
        export PATH="$TEMP_DIR/git_mock:$PATH"
    }

    run_script() {
        cd "$TEMP_DIR"

        VERSION=$1 source "$SCRIPT_PATH"
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
