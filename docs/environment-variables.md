# Workshop Environment Variable Management

This document explains the workshop environment variable management system designed to handle shell timeouts and session persistence.

## Overview

Cloud development environments like Azure Cloud Shell, GitHub Codespaces, and remote SSH sessions often have automatic timeouts that can cause loss of environment variables. This workshop includes a helper script that automatically persists environment variables to a file for reliable restoration.

## Key Features

- **Automatic Persistence**: Variables are saved to `~/.workshop-env` immediately when set
- **Session Recovery**: Variables are automatically restored when sourcing the helper script
- **Shell Timeout Resilience**: Survives shell timeouts and new session creation
- **Verification**: Built-in functions to verify all required variables are present
- **Clean Interface**: Simple functions that replace manual `export` and `echo >>` commands

## Quick Start

### Load the Helper

Always start by loading the workshop environment helper:

```bash
source scripts/workshop-env.sh
```

This will:
- Load any existing saved variables from `~/.workshop-env`
- Provide helper functions for variable management
- Display current workshop variables

### Setting Variables

Instead of traditional environment variable setting:
```bash
# Old way (not persistent)
export BASE_NAME="srepk"
export RESOURCE_GROUP="srepk-workshop"
```

Use the workshop helper:
```bash
# New way (automatically persistent)
set_workshop_var "BASE_NAME" "srepk"
set_workshop_var "RESOURCE_GROUP" "srepk-workshop"
```

### Verifying Variables

Check that all required variables are set:
```bash
verify_workshop_vars
```

## Available Functions

### `set_workshop_var VAR_NAME VAR_VALUE`
Sets an environment variable in the current session AND persists it to `~/.workshop-env`

**Example:**
```bash
set_workshop_var "BASE_NAME" "srepk"
set_workshop_var "RESOURCE_GROUP" "srepk-workshop"
```

### `load_workshop_vars`
Loads all persisted variables from `~/.workshop-env` and displays them

**Example:**
```bash
load_workshop_vars
```

### `show_workshop_vars`
Displays all currently persisted workshop variables without loading them

**Example:**
```bash
show_workshop_vars
```

### `verify_workshop_vars`
Checks if all required workshop variables are set in the current session

**Required variables:** `BASE_NAME`, `RESOURCE_GROUP`, `APIM_URL`, `SUBSCRIPTION_KEY`

**Example:**
```bash
verify_workshop_vars
# ✅ All required variables are set!
```

### `clear_workshop_vars`
Removes the `~/.workshop-env` file and clears all persisted variables

**Example:**
```bash
clear_workshop_vars
```

## Usage in Workshop Exercises

### Part 1: Initial Setup
```bash
# Load the helper
source scripts/workshop-env.sh

# Set initial variables
set_workshop_var "BASE_NAME" "srepk"
set_workshop_var "LOCATION" "swedencentral"
set_workshop_var "RESOURCE_GROUP" "${BASE_NAME}-workshop"

# Continue with resource creation...
# Variables are automatically persisted as they're created
```

### Part 2 & 3: Continuation
```bash
# Load the helper (automatically restores all variables)
source scripts/workshop-env.sh

# Verify everything is ready
verify_workshop_vars

# Continue with exercises...
```

## Benefits for Workshop Participants

### 1. Resilience to Timeouts
Cloud environments often timeout after inactivity:
- **Azure Cloud Shell**: 20 minutes of inactivity
- **GitHub Codespaces**: Configurable timeout
- **Remote SSH**: Network-dependent

The helper ensures variables survive these timeouts.

### 2. Multi-Session Support
Participants can:
- Close and reopen terminals
- Switch between different terminal sessions
- Resume work after breaks
- Continue after connection losses

### 3. Error Prevention
- No need to remember complex `export` commands
- No risk of typos in manual variable setting
- Automatic verification prevents missing variables
- Clear error messages when variables are missing

### 4. Simplified Instructions
Workshop instructions become cleaner:
```bash
# Instead of:
export BASE_NAME="srepk"
echo "export BASE_NAME=$BASE_NAME" >> ~/.workshop-env

# Simply:
set_workshop_var "BASE_NAME" "srepk"
```

## Implementation Details

### File Location
Variables are stored in: `~/.workshop-env`

### File Format
Standard shell export format:
```bash
export BASE_NAME="srepk"
export RESOURCE_GROUP="srepk-workshop"
export APIM_URL="https://srepk-dev-apim.azure-api.net"
export SUBSCRIPTION_KEY="abc123..."
```

### Cross-Platform Compatibility
- Works on Linux, macOS, and Windows (with bash)
- Compatible with Azure Cloud Shell
- Compatible with GitHub Codespaces
- Compatible with WSL

### Safety Features
- Variables are updated atomically (no partial writes)
- Existing values are replaced safely
- No duplicate entries in the file
- Proper escaping of special characters

## Troubleshooting

### Variables Not Loading
```bash
# Check if file exists
ls -la ~/.workshop-env

# Manually source the file
source ~/.workshop-env

# Verify current session variables
env | grep -E "(BASE_NAME|RESOURCE_GROUP|APIM_URL|SUBSCRIPTION_KEY)"
```

### Permission Issues
```bash
# Fix permissions if needed
chmod 600 ~/.workshop-env
```

### Clear and Restart
```bash
# Start fresh
clear_workshop_vars
source scripts/workshop-env.sh
# Re-run setup commands
```

## Advanced Usage

### Custom Variables
The helper can manage any environment variable:
```bash
set_workshop_var "CUSTOM_VAR" "custom_value"
set_workshop_var "API_VERSION" "2023-05-01"
```

### Integration with Scripts
```bash
#!/bin/bash
# At the top of workshop scripts
source "$(dirname "$0")/scripts/workshop-env.sh"

# Now all variables are available
az containerapp show --name "${BASE_NAME}-dev-api" --resource-group "$RESOURCE_GROUP"
```

### Multiple Workshops
Different workshops can use different files:
```bash
# Override the default file
WORKSHOP_ENV_FILE="~/.workshop-advanced-env" source scripts/workshop-env.sh
```