#!/bin/bash
# Workshop Environment Variable Management Helper
# This script provides functions to set and persist environment variables for the workshop

# Configuration
WORKSHOP_ENV_FILE="$HOME/.workshop-env"

# Function to set and persist an environment variable
set_var() {
    local var_name="$1"
    local var_value="$2"
    
    if [ -z "$var_name" ] || [ -z "$var_value" ]; then
        echo "Usage: set_var VAR_NAME VAR_VALUE"
        return 1
    fi
    
    # Set the variable in current session
    export "$var_name"="$var_value"
    
    # Create or update the workshop environment file
    touch "$WORKSHOP_ENV_FILE"
    
    # Remove any existing entry for this variable
    if grep -q "^export $var_name=" "$WORKSHOP_ENV_FILE" 2>/dev/null; then
        # Use a temporary file for cross-platform compatibility
        grep -v "^export $var_name=" "$WORKSHOP_ENV_FILE" > "${WORKSHOP_ENV_FILE}.tmp"
        mv "${WORKSHOP_ENV_FILE}.tmp" "$WORKSHOP_ENV_FILE"
    fi
    
    # Add the new value
    echo "export $var_name=\"$var_value\"" >> "$WORKSHOP_ENV_FILE"
    
    echo "✓ Set $var_name and saved to $WORKSHOP_ENV_FILE"
}

# Function to load workshop environment variables
load_vars() {
    if [ -f "$WORKSHOP_ENV_FILE" ]; then
        echo "Loading workshop environment variables from $WORKSHOP_ENV_FILE..."
        source "$WORKSHOP_ENV_FILE"
        echo "✓ Environment variables loaded"
        
        # Display current variables
        echo ""
        echo "Current workshop variables:"
        grep "^export " "$WORKSHOP_ENV_FILE" | sed 's/^export /  /' | sed 's/=/ = /'
    else
        echo "No workshop environment file found at $WORKSHOP_ENV_FILE"
        echo "Run the setup steps to create environment variables."
    fi
}

# Function to show current workshop variables
show_vars() {
    if [ -f "$WORKSHOP_ENV_FILE" ]; then
        echo "Workshop environment variables:"
        grep "^export " "$WORKSHOP_ENV_FILE" | sed 's/^export /  /' | sed 's/=/ = /'
    else
        echo "No workshop environment file found."
    fi
}

# Function to clear workshop variables
clear_vars() {
    if [ -f "$WORKSHOP_ENV_FILE" ]; then
        echo "Clearing workshop environment variables..."
        rm "$WORKSHOP_ENV_FILE"
        echo "✓ Workshop environment variables cleared"
        echo "Note: Variables in current shell session are still set. Start a new shell or run 'source ~/.bashrc' to clear them completely."
    else
        echo "No workshop environment file found."
    fi
}

# Function to verify required variables are set
verify_vars() {
    local required_vars=("BASE_NAME" "RESOURCE_GROUP" "APIM_GATEWAY_URL" "SUBSCRIPTION_KEY" "CONTAINER_APP_ID")
    local missing_vars=()
    local invalid_vars=()
    
    echo "Verifying required workshop variables..."
    
    for var in "${required_vars[@]}"; do
        local var_value=$(eval echo \$${var})
        if [ -z "$var_value" ]; then
            missing_vars+=("$var")
        else
            echo "✓ $var is set"
            
            # Validate APIM_GATEWAY_URL contains current BASE_NAME
            if [ "$var" = "APIM_GATEWAY_URL" ] && [ -n "$BASE_NAME" ]; then
                if [[ ! "$var_value" =~ $BASE_NAME ]]; then
                    invalid_vars+=("$var (contains wrong BASE_NAME - expected: $BASE_NAME)")
                fi
            fi
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ] || [ ${#invalid_vars[@]} -gt 0 ]; then
        echo ""
        if [ ${#missing_vars[@]} -gt 0 ]; then
            echo "❌ Missing required variables:"
            for var in "${missing_vars[@]}"; do
                echo "  - $var"
            done
        fi
        if [ ${#invalid_vars[@]} -gt 0 ]; then
            echo "❌ Invalid variables:"
            for var in "${invalid_vars[@]}"; do
                echo "  - $var"
            done
        fi
        echo ""
        echo "Please run the setup steps or source the workshop environment:"
        echo "  source ~/.workshop-env"
        return 1
    else
        echo ""
        echo "✅ All required variables are set!"
        return 0
    fi
}

# Auto-load if script is sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # Script is being sourced, auto-load variables
    load_vars
fi

# If script is run directly, show help
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Workshop Environment Variable Helper"
    echo ""
    echo "Usage:"
    echo "  Source this script to load functions and auto-load variables:"
    echo "    source scripts/workshop-env.sh"
    echo ""
    echo "Available functions:"
    echo "  set_var VAR_NAME VAR_VALUE           - Set and persist a variable"
    echo "  load_vars                            - Load persisted variables"
    echo "  show_vars                            - Show current persisted variables"
    echo "  verify_vars                          - Check if required variables are set"
    echo "  clear_vars                           - Clear all workshop variables"
    echo ""
    echo "Examples:"
    echo "  set_var BASE_NAME \"srepk\""
    echo "  set_var RESOURCE_GROUP \"srepk-workshop\""
    echo "  verify_vars"
fi