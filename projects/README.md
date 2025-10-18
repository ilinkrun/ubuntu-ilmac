# Project Creation Script (cp.sh)

## Overview

The `cp.sh` script creates new projects from the ubuntu-project template with automatic port allocation using the PORT management system.

## Usage

```bash
./cp.sh -n <project-name> [-u <github-user>] [-d "<description>"] [-l <location>] [-t <template>]
```

### Options

- `-n` **Project name** (required) - Name of the project to create
- `-u` **GitHub username** (optional) - GitHub user (default: auto-detected from cu.sh or current user)
- `-d` **Description** (optional) - Project description (default: project name)
- `-l` **Target location** (optional) - Where to create the project (default: ./)
- `-t` **Template directory** (optional) - Template to use (default: /var/services/homes/jungsam/dockers/_templates/ubuntu-project)
- `-h` **Help** - Show usage information

## Port Allocation System

The script automatically integrates with the PORT management system to allocate ports for your project.

### How It Works

1. **Detects Platform**: Automatically detects the platform name from the current directory structure
2. **Gets Platform SN**: Retrieves the platform serial number from `platforms.json`
3. **Gets Next Project SN**: Calculates the next available project serial number
4. **Calculates Ports**: Uses `port-allocator.js` to calculate all project ports
5. **Creates .env Files**: Generates environment files with correct port configurations

### Port Structure

Each project gets **20 ports**:

#### PRODUCTION Ports (Offsets 0-9)
- **Offset 0**: SSH Server
- **Offset 1**: Backend (Node.js)
- **Offset 2**: Backend (Python)
- **Offset 3**: API (GraphQL)
- **Offset 4**: API (REST)
- **Offset 5**: API (Reserved)
- **Offset 6**: Frontend (Next.js)
- **Offset 7**: Frontend (SvelteKit)
- **Offset 8**: Frontend (Reserved)
- **Offset 9**: System Reserved

#### DEVELOPMENT Ports (Offsets 10-19)
- Same structure as production but with +10 offset

## Examples

### Basic Usage

```bash
# Create a project with minimal options
./cp.sh -n my-ecommerce

# Output:
# Detected platform: ubuntu-ilmac
# Platform SN: 0
# Project SN: 1
#
# Production Ports (Offsets 0-9):
#   SSH:              11020
#   Backend (Node):   11021
#   Backend (Python): 11022
#   GraphQL API:      11023
#   REST API:         11024
#   Next.js:          11026
#   SvelteKit:        11027
#
# Development Ports (Offsets 10-19):
#   SSH:              11030
#   Backend (Node):   11031
#   GraphQL API:      11033
#   Next.js:          11036
#   SvelteKit:        11037
```

### Full Options

```bash
./cp.sh -n blog-platform \
  -u myuser \
  -d "My Blog Platform" \
  -l /var/services/homes/jungsam/dockers/ubuntu-ilmac/projects
```

### Using from Platform Directory

```bash
# Navigate to platform's projects directory
cd /var/services/homes/jungsam/dockers/ubuntu-ilmac/projects

# Run cp.sh
./cp.sh -n crm-system -d "CRM System"
```

## Generated Files

After running `cp.sh`, the following files are created with port configurations:

### Root .env.example

```env
#------------------------------------------------------------------------------
# Port Configuration
# Platform: ubuntu-ilmac (SN: 0)
# Project: my-project (SN: 0)
# Base Port: 11000
# Port Range: 11000 - 11019
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# PRODUCTION Ports (Offsets: 0-9)
#------------------------------------------------------------------------------
SSH_PORT_PROD=11000
BACKEND_PORT=11001
BACKEND_PYTHON_PORT=11002
GRAPHQL_PORT=11003
API_REST_PORT=11004
FRONTEND_NEXTJS_PORT=11006
FRONTEND_SVELTEKIT_PORT=11007

#------------------------------------------------------------------------------
# DEVELOPMENT Ports (Offsets: 10-19)
#------------------------------------------------------------------------------
SSH_PORT_DEV=11010
BACKEND_PORT_DEV=11011
GRAPHQL_PORT_DEV=11013
FRONTEND_NEXTJS_PORT_DEV=11016
FRONTEND_SVELTEKIT_PORT_DEV=11017

# ... other configuration
```

## Requirements

### Prerequisites

1. **Platform must exist**: Run `cu.sh` first to create a platform
2. **Platform directory structure**: Must be in `/path/to/PLATFORM-ubuntu/projects/`
3. **Node.js**: Required for port-allocator.js
4. **platforms.json**: Must exist in `_manager/data/` with platform SN information

### Directory Structure

```
/var/services/homes/jungsam/dockers/
├── _scripts/
│   └── port-allocator.js       # Port allocation utility
├── _manager/
│   └── data/
│       ├── platforms.json       # Platform configurations with SN
│       └── projects.json        # Project configurations with SN
├── ubuntu-ilmac/                # Example platform
│   └── projects/
│       ├── cp.sh                # This script
│       └── my-project/          # Created project
```

## Port Allocation Fallback

If the port allocator is not found, the script falls back to legacy port allocation:

1. Reads base port from platform settings
2. Calculates hash from project name
3. Allocates ports based on hash offset

**Note**: Legacy allocation does not guarantee port uniqueness. Always use the port allocator for production.

## Troubleshooting

### Error: "Could not detect platform name"

**Solution**: Run the script from within a platform directory:
```bash
cd /var/services/homes/jungsam/dockers/ubuntu-ilmac/projects
./cp.sh -n my-project
```

### Error: "Port allocator not found"

**Solution**: Ensure `/var/services/homes/jungsam/dockers/_scripts/port-allocator.js` exists and is executable:
```bash
chmod +x /var/services/homes/jungsam/dockers/_scripts/port-allocator.js
node /var/services/homes/jungsam/dockers/_scripts/port-allocator.js --help
```

### Warning: "Platform SN not found in platforms.json"

**Solution**: Update platforms.json to include the `sn` field:
```json
{
  "platforms": {
    "ubuntu-ilmac": {
      "id": "ubuntu-ilmac",
      "sn": 0,
      "name": "ubuntu-ilmac",
      ...
    }
  }
}
```

### Port Conflicts

If ports are already in use:

1. Check current port allocations:
   ```bash
   node /var/services/homes/jungsam/dockers/_scripts/port-allocator.js project 0 0
   ```

2. Verify no other services use those ports:
   ```bash
   netstat -tlnp | grep <port>
   ```

3. Use the next available project SN

## Next Steps

After creating a project:

1. **Copy environment file**:
   ```bash
   cd my-project
   cp .env.example .env
   ```

2. **Edit configuration**:
   ```bash
   vim .env
   # Update database passwords, API keys, etc.
   ```

3. **Install dependencies**:
   ```bash
   cd backend && npm install
   cd frontend/nextjs-app && npm install
   ```

4. **Start development servers**:
   ```bash
   # Backend
   npm run dev

   # GraphQL
   npm run graphql:dev

   # Frontend (Next.js)
   cd frontend/nextjs-app && npm run dev
   ```

## Related Documentation

- [PORT 관리시스템.md](/var/services/homes/jungsam/dockers/jnj-ubuntu/projects/jnj-dev/docs/PORT%20관리시스템.md) - Port allocation specification
- [_scripts/README.md](/var/services/homes/jungsam/dockers/_scripts/README.md) - Port allocator utility documentation
- [cu.sh](/var/services/homes/jungsam/dockers/cu.sh) - Platform creation script
