#!/bin/bash

# Docker Compose Up with automatic setup
# This script runs docker-compose up from root context, with automatic setup of compose file

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
ATTACH=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --detach           Detached mode (background)"
    echo "  -a, --attach           Attached mode (foreground, default)"
    echo "  --verbose              Enable verbose output"
    echo "  --quiet                Disable verbose output (default)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Description:"
    echo "  This script runs docker-compose up with automatic setup of compose file."
    echo "  If docker-compose.yml doesn't exist, it creates it from merged files."
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--detach)
                ATTACH=false
                shift
                ;;
            -a|--attach)
                ATTACH=true
                shift
                ;;
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
    
    # Check for standard compose file names
    local compose_names=(
        "docker-compose.yml"
        "docker-compose.yaml"
        "compose.yml"
        "compose.yaml"
    )
    
    for name in "${compose_names[@]}"; do
        if [ -f "$project_root/$name" ]; then
            COMPOSE_FILE="$name"
            if [ "$VERBOSE" = true ]; then
                green "Found compose file: $COMPOSE_FILE"
            fi
            return 0
        fi
    done
    
    if [ "$VERBOSE" = true ]; then
        yellow "No standard compose file found, will create from merged files"
    fi
    return 1
}

# Function to setup compose from merged files
setup_compose_from_merged() {
    local project_root="$(pwd)"
    local temp_dir="$project_root/deployment/temp"
    
    # Find merged compose file
    local merged_compose=""
    if [ -f "$project_root/docker-compose.merged.yml" ]; then
        merged_compose="$project_root/docker-compose.merged.yml"
    elif [ -f "$temp_dir/docker-compose.merged.yml" ]; then
        merged_compose="$temp_dir/docker-compose.merged.yml"
    else
        error "No merged compose file found. Run 'make deploy' first."
        exit 1
    fi
    
    # Copy merged compose to docker-compose.yml
    if [ "$VERBOSE" = true ]; then
        green "Creating docker-compose.yml from $merged_compose"
    fi
    cp "$merged_compose" "$project_root/docker-compose.yml"
    
    # Find and copy env file
    local merged_env=""
    if [ -f "$project_root/.env.merged" ]; then
        merged_env="$project_root/.env.merged"
    elif [ -f "$temp_dir/.env.merged" ]; then
        merged_env="$temp_dir/.env.merged"
    fi
    
    if [ -n "$merged_env" ]; then
        if [ "$VERBOSE" = true ]; then
            green "Creating .env from $merged_env"
        fi
        cp "$merged_env" "$project_root/.env"
    fi
    
    # Update env_file paths in docker-compose.yml
    update_env_file_paths "$project_root/docker-compose.yml"
}

# Function to update env_file paths in compose file
update_env_file_paths() {
    local compose_file="$1"
    
    if [ "$VERBOSE" = true ]; then
        yellow "Updating env_file paths to point to .env"
    fi
    
    # Use Python to update env_file paths
    local verbose_flag="False"
    if [ "$VERBOSE" = true ]; then
        verbose_flag="True"
    fi
    
    python3 << EOF
import yaml
import sys

compose_file = '$compose_file'
verbose = $verbose_flag

try:
    # Read the compose file
    with open(compose_file, 'r') as f:
        compose_data = yaml.safe_load(f) or {}
    
    # Update env_file for each service
    if 'services' in compose_data:
        for service_name in compose_data['services']:
            if 'env_file' in compose_data['services'][service_name]:
                compose_data['services'][service_name]['env_file'] = '.env'
    
    # Write back the updated compose file
    with open(compose_file, 'w') as f:
        yaml.dump(compose_data, f, default_flow_style=False, sort_keys=False)
        
    if verbose:
        print("Updated env_file paths to .env")
        
except Exception as e:
    print(f"Error updating env_file paths: {e}", file=sys.stderr)
    sys.exit(1)
EOF
}

# Function to run docker-compose up
run_docker_compose_up() {
    local project_root="$(pwd)"
    local compose_file="$COMPOSE_FILE"
    
    if [ "$VERBOSE" = true ]; then
        green "Running docker-compose up..."
        echo -e "  ${YELLOW}Compose file: ${compose_file}${NC}"
        echo -e "  ${YELLOW}Project directory: ${project_root}${NC}"
        echo -e "  ${YELLOW}Mode: $([ "$ATTACH" = true ] && echo "attached" || echo "detached")${NC}"
    fi
    
    # Build command
    local cmd="docker-compose -f $compose_file --project-directory $project_root up"
    
    if [ "$ATTACH" = false ]; then
        cmd="$cmd -d"
    fi
    
    # Execute docker-compose
    eval "$cmd"
    
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
    if ! find_compose_file; then
        setup_compose_from_merged
        COMPOSE_FILE="docker-compose.yml"
    fi
    
    # Run docker-compose up
    run_docker_compose_up
}

# Run main function with all arguments
main "$@"
