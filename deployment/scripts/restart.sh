#!/bin/bash

# Start Docker Compose with existing merged files
# This script starts docker-compose using merged files in root or temp directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions for colored output
yellow() {
    echo -e "${YELLOW}$1${NC}"
}
green() {
    echo -e "${GREEN}$1${NC}"
}
error() {
    echo -e "${RED}$1${NC}"
}

# Default values
VERBOSE=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --verbose                  Enable verbose output"
    echo "  --quiet                    Disable verbose output (default)"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Description:"
    echo "  This script starts Docker Compose using merged configuration files."
    echo "  It looks for docker-compose.merged.yml in root or temp directory."
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --quiet)
                VERBOSE=false
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to find compose file
find_compose_file() {
    local project_root="$(pwd)"
    local root_compose="$project_root/docker-compose.merged.yml"
    local temp_dir="$project_root/deployment/temp"
    local temp_compose="$temp_dir/docker-compose.merged.yml"
    
    # Check if file exists in root directory first
    if [ -f "$root_compose" ]; then
        COMPOSE_FILE="$root_compose"
        if [ "$VERBOSE" = true ]; then
            green "Found docker-compose file in root: $COMPOSE_FILE"
        fi
    elif [ -f "$temp_compose" ]; then
        COMPOSE_FILE="$temp_compose"
        if [ "$VERBOSE" = true ]; then
            green "Found docker-compose file in temp: $COMPOSE_FILE"
        fi
    else
        error "Error: docker-compose.merged.yml not found"
        error "Run 'make deploy' first to create merged files"
        exit 1
    fi
}

# Function to ensure env file exists in the location referenced by compose
ensure_env_file() {
    local compose_file="$COMPOSE_FILE"
    local project_root="$(pwd)"
    local temp_dir="$project_root/deployment/temp"
    
    # Extract env_file path from compose file using Python
    local env_file_path=$(python3 << EOF
import yaml
import sys

try:
    with open('$compose_file', 'r') as f:
        compose_data = yaml.safe_load(f) or {}
    
    # Find env_file from any service
    if 'services' in compose_data:
        for service_name, service_data in compose_data['services'].items():
            if isinstance(service_data, dict) and 'env_file' in service_data:
                print(service_data['env_file'])
                break
except Exception as e:
    pass
EOF
)
    
    # If no env_file found in compose, skip
    if [ -z "$env_file_path" ]; then
        if [ "$VERBOSE" = true ]; then
            yellow "No env_file found in compose file"
        fi
        return 0
    fi
    
    # Resolve absolute path relative to compose file's directory
    local compose_dir="$(dirname "$compose_file")"
    
    # Remove leading ./ if present
    env_file_path="${env_file_path#./}"
    local env_file_abs="$compose_dir/$env_file_path"
    
    # Normalize path (resolve relative paths)
    if [ -f "$env_file_abs" ]; then
        env_file_abs="$(cd "$(dirname "$env_file_abs")" && pwd)/$(basename "$env_file_abs")"
    fi
    
    # Check if env file exists at the expected location
    if [ -f "$env_file_abs" ]; then
        if [ "$VERBOSE" = true ]; then
            green "Found env file: $env_file_abs"
        fi
        return 0
    fi
    
    # If compose is in root and points to root env file, check temp
    local compose_is_in_root=false
    if [ "$compose_file" = "$project_root/docker-compose.merged.yml" ]; then
        compose_is_in_root=true
    fi
    
    local env_file_in_root="$project_root/.env.merged"
    local env_file_in_temp="$temp_dir/.env.merged"
    
    # Check if env file is supposed to be in root but is in temp instead
    if [ "$compose_is_in_root" = true ] && [[ "$env_file_abs" == "$env_file_in_root"* ]]; then
        if [ -f "$env_file_in_temp" ] && [ ! -f "$env_file_in_root" ]; then
            if [ "$VERBOSE" = true ]; then
                yellow "Compose file points to root .env.merged, but file is in temp. Copying to root..."
            fi
            cp "$env_file_in_temp" "$env_file_in_root"
            green "Copied .env.merged from temp to root"
        fi
    fi
}

# Function to stop docker-compose
stop_docker_compose() {
    local project_root="$(pwd)"
    local compose_file="$COMPOSE_FILE"
    
    if [ "$VERBOSE" = true ]; then
        green "Stopping Docker Compose services..."
        echo -e "  ${YELLOW}Compose file: ${compose_file}${NC}"
        echo -e "  ${YELLOW}Project directory: ${project_root}${NC}"
    fi
    
    # Execute docker-compose down with remove-orphans
    docker-compose -f "$compose_file" --project-directory "$project_root" down --remove-orphans
    
    if [ $? -eq 0 ]; then
        if [ "$VERBOSE" = true ]; then
            green "Docker Compose stopped successfully"
        fi
    else
        if [ "$VERBOSE" = true ]; then
            yellow "Docker Compose stop completed with warnings (may be normal if nothing was running)"
        fi
    fi
}

# Function to start docker-compose
start_docker_compose() {
    local project_root="$(pwd)"
    local compose_file="$COMPOSE_FILE"
    
    if [ "$VERBOSE" = true ]; then
        green "Starting Docker Compose services..."
        echo -e "  ${YELLOW}Compose file: ${compose_file}${NC}"
        echo -e "  ${YELLOW}Project directory: ${project_root}${NC}"
    fi
    
    # Execute docker-compose up
    docker-compose -f "$compose_file" --project-directory "$project_root" up -d
    
    if [ $? -eq 0 ]; then
        green "Docker Compose started successfully"
    else
        error "Failed to start Docker Compose"
        exit 1
    fi
}

# Main function
main() {
    parse_args "$@"
    
    # Find compose file
    find_compose_file
    
    # Ensure env file exists where compose expects it
    ensure_env_file
    
    # Stop docker-compose first (to ensure clean restart)
    stop_docker_compose
    
    # Start docker-compose
    start_docker_compose
}

# Run main function with all arguments
main "$@"
