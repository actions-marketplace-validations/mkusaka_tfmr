# tfmr

A CLI tool to analyze Terraform modules and list all related files, including files from local module dependencies.

## Features

- Recursively analyze Terraform modules and their local dependencies
- List all `.tf` and `.tf.json` files in a module and its dependencies
- Detect both local and remote module references
- Filter output based on changed files (useful for CI/CD pipelines)
- Check if a module is affected by file changes

## Installation

### GitHub Action (recommended for CI/CD)

```yaml
- uses: mkusaka/tfmr@v1
# tfmr is now available in PATH
- run: git diff --name-only origin/main | tfmr --affected ./terraform/production
```

Pin to a specific version:

```yaml
- uses: mkusaka/tfmr@v1
  with:
    version: v1.2.3
```

### Pre-built binaries

Download the latest binary for your platform from [GitHub Releases](https://github.com/mkusaka/tfmr/releases).

```bash
# macOS (Apple Silicon)
curl -sL https://github.com/mkusaka/tfmr/releases/latest/download/tfmr_darwin_arm64.tar.gz | tar -xz
sudo mv tfmr /usr/local/bin/

# macOS (Intel)
curl -sL https://github.com/mkusaka/tfmr/releases/latest/download/tfmr_darwin_amd64.tar.gz | tar -xz
sudo mv tfmr /usr/local/bin/

# Linux (amd64)
curl -sL https://github.com/mkusaka/tfmr/releases/latest/download/tfmr_linux_amd64.tar.gz | tar -xz
sudo mv tfmr /usr/local/bin/
```

### go install

```bash
go install github.com/mkusaka/tfmr@latest
```

### Build from source

```bash
git clone https://github.com/mkusaka/tfmr.git
cd tfmr
go build -o tfmr
```

## Usage

### Basic Usage

Analyze a Terraform module and output JSON:

```bash
tfmr /path/to/terraform/module
```

Output:

```json
{
  "root_module": {
    "resolved_path": "/path/to/terraform/module",
    "files": [
      "/path/to/terraform/module/main.tf",
      "/path/to/terraform/module/variables.tf"
    ]
  },
  "local_modules": [
    {
      "name": "vpc",
      "source": "../modules/vpc",
      "resolved_path": "/path/to/modules/vpc",
      "files": [
        "/path/to/modules/vpc/main.tf",
        "/path/to/modules/vpc/outputs.tf"
      ]
    }
  ],
  "remote_modules": [
    {
      "name": "eks",
      "source": "terraform-aws-modules/eks/aws",
      "version": "~> 19.0",
      "called_from": "(root)"
    }
  ]
}
```

### List Files Only

Output only file paths, one per line:

```bash
tfmr --files-only /path/to/terraform/module
```

### Filter by Changed Files

Filter output to only files in modules affected by changes from stdin:

```bash
git diff --name-only | tfmr --files-only --filter-stdin /path/to/terraform/module
```

### Check if Module is Affected

Check if a module is affected by changed files. Useful for conditional CI/CD execution:

```bash
git diff --name-only | tfmr --affected /path/to/terraform/module
```

Exit codes:
- `0`: Module is affected by the changes
- `1`: Module is not affected
- `2`: Error occurred

## Options

| Flag | Description |
|------|-------------|
| `--files-only` | Output only file paths, one per line |
| `--filter-stdin` | Filter output to only files in modules matching stdin input (use with `--files-only`) |
| `--affected` | Check if module is affected by changed files from stdin (exit 0=affected, 1=not affected) |

## Use Cases

### CI/CD: Run Terraform Only for Affected Modules

```yaml
jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: mkusaka/tfmr@v1

      - name: Check if module affected
        id: check
        run: git diff --name-only origin/main | tfmr --affected ./terraform/production
        continue-on-error: true

      - name: Terraform Plan
        if: steps.check.outcome == 'success'
        run: terraform plan
```

### Get All Files for Static Analysis

```bash
tfmr --files-only ./terraform/module | xargs tflint
```

### List Changed Module Files

```bash
git diff --name-only HEAD~1 | tfmr --files-only --filter-stdin ./terraform/module
```

## Releasing

Use the release script to bump the version and trigger the release workflow:

```bash
./scripts/release.sh patch   # 1.0.0 -> 1.0.1
./scripts/release.sh minor   # 1.0.1 -> 1.1.0
./scripts/release.sh major   # 1.1.0 -> 2.0.0
./scripts/release.sh v1.2.3  # explicit version
```

The script creates and pushes a git tag, which triggers GitHub Actions to build binaries for all platforms via [goreleaser](https://goreleaser.com) and publish a GitHub Release.

## License

MIT
