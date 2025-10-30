#!/bin/bash

# Clean up Docker Compose and merged files
# This script shuts down docker-compose, removes containers, volumes, and merged files

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
    echo "  This script shuts down docker-compose, removes all project containers,"
    echo "  volumes, networks, and orphaned resources, and removes merged files."
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

# Function to find compose files
find_compose_files() {
    local project_root="$(pwd)"
    local compose_files=()
    
    # Standard compose files
    local compose_names=(
        "docker-compose.yml"
        "docker-compose.yaml"
        "compose.yml"
        "compose.yaml"
        "docker-compose.merged.yml"
    )
    
    for name in "${compose_names[@]}"; do
        if [ -f "$project_root/$name" ]; then
            compose_files+=("$name")
        fi
    done
    
    # Also check temp directory
    if [ -f "$project_root/deployment/temp/docker-compose.merged.yml" ]; then
        compose_files+=("deployment/temp/docker-compose.merged.yml")
    fi
    
    echo "${compose_files[@]}"
}

# Function to shut down docker-compose
shutdown_docker_compose() {
    local project_root="$(pwd)"
    local compose_files=($(find_compose_files))
    
    if [ ${#compose_files[@]} -eq 0 ]; then
        if [ "$VERBOSE" = true ]; then
            yellow "No compose files found, skipping docker-compose shutdown"
        fi
        return 0
    fi
    
    local has_running=false
    for compose_file in "${compose_files[@]}"; do
        if [ "$VERBOSE" = true ]; then
            green "Stopping docker-compose: $compose_file"
        fi
        
        # Try to stop and remove containers
        docker-compose -f "$compose_file" --project-directory "$project_root" down --remove-orphans 2>/dev/null && has_running=true || true
    done
    
    if [ "$has_running" = true ]; then
        green "Docker Compose shutdown completed"
    elif [ "$VERBOSE" = true ]; then
        yellow "No running containers found"
    fi
}

# Function to get project name from compose files
get_project_name() {
    local project_root="$(pwd)"
    
    # Try to get project name from docker-compose.yml
    if [ -f "$project_root/docker-compose.yml" ]; then
        local project_name=$(docker-compose -f "$project_root/docker-compose.yml" -p "$(basename "$project_root")" config --services 2>/dev/null | head -1 | sed 's/_//g' || echo "")
        if [ -n "$project_name" ]; then
            echo "$(basename "$project_root")"
            return
        fi
    fi
    
    # Fallback to directory name
    echo "$(basename "$project_root")"
}

# Function to remove orphaned containers and resources
remove_orphans() {
    local project_name=$(get_project_name)
    
    if [ "$VERBOSE" = true ]; then
        yellow "Removing project-specific Docker resources (project: $project_name)..."
    fi
    
    local removed_count=0
    
    # Remove stopped containers for this project
    local stopped_containers=$(docker ps -aq --filter "status=exited" --filter "label=com.docker.compose.project=$project_name" 2>/dev/null || echo "")
    if [ -n "$stopped_containers" ]; then
        if [ "$VERBOSE" = true ]; then
            yellow "Removing stopped project containers..."
        fi
        docker rm $stopped_containers 2>/dev/null || true
        ((removed_count++))
        if [ "$VERBOSE" = true ]; then
            green "Removed stopped project containers"
        fi
    fi
    
    # Remove all containers (running and stopped) for this project
    local all_containers=$(docker ps -aq --filter "label=com.docker.compose.project=$project_name" 2>/dev/null || echo "")
    if [ -n "$all_containers" ]; then
        if [ "$VERBOSE" = true ]; then
            yellow "Removing all project containers..."
        fi
        docker rm -f $all_containers 2>/dev/null || true
        ((removed_count++))
        if [ "$VERBOSE" = true ]; then
            green "Removed all project containers"
        fi
    fi
    
    # Remove volumes for this project
    local project_volumes=$(docker volume ls -q --filter "label=com.docker.compose.project=$project_name" 2>/dev/null || echo "")
    if [ -z "$project_volumes" ]; then
        # Try alternative method: search by volume name pattern
        project_volumes=$(docker volume ls -q | grep "^${project_name}_" 2>/dev/null || echo "")
    fi
    
    if [ -n "$project_volumes" ]; then
        if [ "$VERBOSE" = true ]; then
            yellow "Removing project volumes..."
        fi
        docker volume rm $project_volumes 2>/dev/null || true
        ((removed_count++))
        if [ "$VERBOSE" = true ]; then
            green "Removed project volumes"
        fi
    fi
    
    # Remove networks for this project
    local project_networks=$(docker network ls -q --filter "label=com.docker.compose.project=$project_name" 2>/dev/null || echo "")
    if [ -z "$project_networks" ]; then
        # Try alternative method: search by network name pattern
        project_networks=$(docker network ls -q | grep "^${project_name}_" 2>/dev/null || echo "")
    fi
    
    if [ -n "$project_networks" ]; then
        if [ "$VERBOSE" = true ]; then
            yellow "Removing project networks..."
        fi
        docker network rm $project_networks 2>/dev/null || true
        ((removed_count++))
        if [ "$VERBOSE" = true ]; then
            green "Removed project networks"
        fi
    fi
    
    if [ $removed_count -eq 0 ] && [ "$VERBOSE" = true ]; then
        yellow "No project-specific resources found to remove"
    fi
}

# Function to remove merged files
remove_merged_files() {
    local project_root="$(pwd)"
    
    if [ "$VERBOSE" = true ]; then
        yellow "Removing merged files..."
    fi
    
    local removed_count=0
    
    # Remove merged files from root (excluding .env and docker-compose.yml)
    local root_files=(
        "docker-compose.merged.yml"
        ".env.merged"
    )
    
    for file in "${root_files[@]}"; do
        if [ -f "$project_root/$file" ]; then
            rm -f "$project_root/$file"
            if [ "$VERBOSE" = true ]; then
                echo "  Removed: $file"
            fi
            ((removed_count++))
        fi
    done
    
    # Remove merged files from temp
    local temp_dir="$project_root/deployment/temp"
    if [ -d "$temp_dir" ]; then
        if [ -f "$temp_dir/docker-compose.merged.yml" ]; then
            rm -f "$temp_dir/docker-compose.merged.yml"
            if [ "$VERBOSE" = true ]; then
                echo "  Removed: deployment/temp/docker-compose.merged.yml"
            fi
            ((removed_count++))
        fi
        if [ -f "$temp_dir/.env.merged" ]; then
            rm -f "$temp_dir/.env.merged"
            if [ "$VERBOSE" = true ]; then
                echo "  Removed: deployment/temp/.env.merged"
            fi
            ((removed_count++))
        fi
    fi
    
    if [ $removed_count -gt 0 ]; then
        green "Removed $removed_count merged file(s)"
    elif [ "$VERBOSE" = true ]; then
        yellow "No merged files found"
    fi
}

# Main function
main() {
    parse_args "$@"
    
    green "Starting cleanup..."
    
    # Shutdown docker-compose
    shutdown_docker_compose
    
    # Remove orphaned resources
    remove_orphans
    
    # Remove merged files
    remove_merged_files
    
    green "Cleanup completed successfully"
}

# Run main function with all arguments
main "$@"
