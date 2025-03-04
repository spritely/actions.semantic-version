# actions.semantic-version

A lightweight, dependency-free GitHub Action for generating and applying semantic versions based on Git history.

## Features

- Generates semantic versions based on Git history
- Supports version bumping via commit messages (#major, #minor)
- Different version formats for main branches vs. feature/development branches
- No external dependencies beyond Git and Bash
- Fully tested with bats test framework

## Components

This action contains two main components:

1. **Get Semantic Version** - Calculates the next semantic version based on Git history
2. **Apply Semantic Version** - Creates and pushes a Git tag with the specified semantic version

### Get Semantic Version

#### Usage

```yaml
- name: Calculate semantic version
  id: version
  uses: spritely/actions.semantic-version/get@0.2

- name: Use the version
  run: |
    echo "Branch: ${{ steps.version.outputs.branchName }}"
    echo "Version: ${{ steps.version.outputs.version }}"
```

#### Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `workingDirectory` | Directory to run git commands in | No | `./` |
| `skipCheckout` | Skip checkout step | No | `"false"` |

#### Outputs

| Name | Description | Example |
|------|-------------|---------|
| `branchName` | Name of the current branch | `main`, `feature/new-thing` |
| `version` | Semantic version number | `1.2.3` or `1.2.3-feature-new-thing.5.a1b2c3d` |

#### Version Format

- **Main branches** (main/master): `{major}.{minor}.{patch}`
- **Other branches**: `{major}.{minor}.{patch}-{branch}.{commits}.{sha7}`

#### Version Bumping

Add the following to commit messages to bump version components:

- `#major` - Increments major version, resets minor and patch to 0
- `#minor` - Increments minor version, resets patch to 0
- If neither is found, patch version is incremented by default

### Apply Semantic Version

#### Usage

```yaml
- name: Get semantic version
  id: version
  uses: spritely/actions.semantic-version/get@0.2

# Other build actions

- name: Apply version tag
  uses: spritely/actions.semantic-version/apply@0.2
  with:
    version: ${{ steps.version.outputs.version }}
```

#### Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `version` | The semantic version to apply (without 'v' prefix) | Yes | N/A |
| `workingDirectory` | Directory to run git commands in | No | `./` |

## Testing

This project uses [bats](https://github.com/bats-core/bats-core) for testing. To run the tests locally:

```bash
bats ./tests/

# To generate a junit xml report locally use:
bats --report-formatter junit ./tests/
```

## License

This project is licensed under the Apache 2.0 License - see the LICENSE file for details.
