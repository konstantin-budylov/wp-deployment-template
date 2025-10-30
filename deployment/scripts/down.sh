#!/bin/bash

# Stop Docker Compose and Clean Up Orphaned Containers
# This script stops the merged docker-compose setup and removes orphaned containers

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
REMOVE_ORPHANS=true

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --no-orphans               Do not remove orphaned containers"
    echo "  --verbose                  Enable verbose output"
    echo "  --quiet                    Disable verbose output (default)"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Description:"
    echo "  This script stops the Docker Compose services and removes orphaned containers."
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-orphans)
                REMOVE_ORPHANS=false
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

# Function to find merged compose file
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
        error "No docker-compose.merged.yml file found"
        error "Expected files:"
        error "  $root_compose or $temp_compose"
        exit 1
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
    
    # Build docker-compose stop command
    local cmd="docker-compose -f \"$compose_file\" --project-directory \"$project_root\" down"
    
    if [ "$REMOVE_ORPHANS" = true ]; then
        cmd="$cmd --remove-orphans"
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}Executing: ${cmd}${NC}"
    fi
    
    # Execute the command
    eval "$cmd"
    
    if [ $? -eq 0 ]; then
        green "Docker Compose stopped successfully"
    else
        error "Failed to stop Docker Compose"
        exit 1
    fi
}

# Main function
main() {
    parse_args "$@"
    
    if [ "$VERBOSE" = true ]; then
        green "Stopping Docker Compose setup..."
    fi
    
    # Find compose file
    find_compose_file
    
    # Stop docker-compose
    stop_docker_compose
    
    green "All services stopped successfully"
}

# Run main function with all arguments
main "$@"
