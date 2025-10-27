# Bitwarden Integration

This project uses Bitwarden CLI to manage secrets with chezmoi.

## Setup

### 1. Install Bitwarden CLI

```bash
./dotfile-utils/scripts/install_bw_cli.sh
```

### 2. Configure Credentials

1. Get your API credentials from Bitwarden web vault:
   - Login to <https://vault.bitwarden.com>
   - Go to **Settings** → **Security** → **Keys**
   - Click **View API Key**
   - Copy your `client_id`, `client_secret`

2. Create `.env.bitwarden` file:

   ```bash
   cp .env.bitwarden.example .env.bitwarden
   ```

3. Edit `.env.bitwarden` and add your credentials:

   ```bash
   BW_CLIENTID=user.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   BW_CLIENTSECRET=xxxxxxxxxxxxxxxxxxxxxxxxxx
   BW_PASSWORD=your-master-password
   ```

### 3. Source the Session Script

```bash
source ./dotfile-utils/scripts/source_bitwarden_session.sh
```

This will authenticate with Bitwarden and set up the `czm` alias.

## Usage

### Interactive Use

After sourcing the script, you can use the `czm` alias:

```bash
czm apply      # Apply chezmoi templates
czm diff       # Show differences
czm add file   # Add a file to chezmoi
```

### In Scripts

Other scripts can source the Bitwarden session script to get access:

```bash
# Get parent repository root (handles both submodule and parent repo contexts)
PROJECT_ROOT=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
fi
source "$PROJECT_ROOT/dotfile-utils/scripts/source_bitwarden_session.sh" || exit 1

# Now BW_SESSION and PROJECT_ROOT are available
chezmoi --config "$PROJECT_ROOT/.chezmoi.toml" apply
```

See [example_script_with_bitwarden.sh](./scripts/example_script_with_bitwarden.sh)
for a complete example.

### In Templates

Access Bitwarden secrets in your chezmoi templates:

```bash
# Get login credentials
DB_USER={{ (bitwarden "item" "my-database").login.username }}
DB_PASS={{ (bitwarden "item" "my-database").login.password }}

# Get custom fields
API_KEY={{ (bitwardenFields "item" "my-api").token.value }}
```

## CI/CD Usage

In CI environments, set these as secrets:

- `BW_CLIENTID`
- `BW_CLIENTSECRET`
- `BW_PASSWORD`

Then source the script as normal - it will use environment variables if `.env.bitwarden`
doesn't exist.

## Security Notes

- `.env.bitwarden` is gitignored - never commit it
- Store your master password securely
- Consider using a separate Bitwarden organization for CI secrets
- Use `bw lock` when done to secure your vault
