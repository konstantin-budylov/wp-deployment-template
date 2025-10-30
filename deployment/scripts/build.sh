#!/bin/bash

# Unified Deployment Script
# Combines service discovery, dependency resolution, configuration merging, and file moving

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
YAML_FILE="services.yaml"
OUTPUT_DIR="deployment/temp"
SERVICES=()
VERBOSE=true
INTERACTIVE_MODE=false

# File patterns and paths
SERVICES_DIR="deployment/services"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env.dist"

# Helper functions for colored output
yellow() {
    echo -e "${YELLOW}$1${NC}"
}
blue() {
    echo -e "${BLUE}$1${NC}"
}
green() {
    echo -e "${GREEN}$1${NC}"
}
error() {
    echo -e "${RED}$1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] <service1> [service2] ..."
    echo ""
    echo "Options:"
    echo "  --yaml <file>                 YAML configuration file (default: services.yaml)"
    echo "  --output-dir <dir>            Output directory for merged files (default: deployment/temp)"
    echo "  --verbose                     Enable verbose output (default: true)"
    echo "  --quiet                       Disable verbose output"
    echo "  --interactive                 Interactive mode for file moving"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "Description:"
    echo "  Unified deployment script that discovers services from YAML configuration,"
    echo "  resolves dependencies, merges Docker Compose configurations, and handles file movement."
    echo ""
    echo "Examples:"
    echo "  $0 nginx84 redis"
    echo "  $0 --verbose nginx84 redis mysql"
    echo "  $0 --yaml custom.yaml --output-dir /tmp/merged nginx84 redis"
    echo "  $0 --quiet nginx84"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --yaml)
                YAML_FILE="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --quiet)
                VERBOSE=false
                shift
                ;;
            --interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                error "unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                SERVICES+=("$1")
                shift
                ;;
        esac
    done

    if [ ${#SERVICES[@]} -eq 0 ]; then
        error "no services specified"
        show_usage
        exit 1
    fi

    if [ ! -f "$YAML_FILE" ]; then
        error "YAML file not found: $YAML_FILE"
        exit 1
    fi
}

# Function to parse YAML and extract service information
parse_yaml_single() {
    local service_name="$1"
    local yaml_file="$2"
    
    # Extract compose file path
    local compose_path=$(grep -A 2 "^${service_name}:" "$yaml_file" | grep "compose:" | sed 's/.*compose: *//' | tr -d ' ')
    
    # Extract env file path
    local env_path=$(grep -A 2 "^${service_name}:" "$yaml_file" | grep "env:" | sed 's/.*env: *//' | tr -d ' ')
    
    # Extract dependencies
    local depends=$(awk "/^${service_name}:/{flag=1; next} /^[a-zA-Z0-9][a-zA-Z0-9]*:/{flag=0} flag" "$yaml_file" | grep "^    - " | sed 's/^    - //' | tr '\n' ' ' | sed 's/ $//')
    
    # Check if service exists in YAML
    if [ -z "$compose_path" ] && [ -z "$env_path" ]; then
        error "Service '$service_name' not found in $yaml_file"
        echo "Available services:"
        grep "^[a-zA-Z0-9]*:" "$yaml_file" | sed 's/:$//' | sed 's/^/  /'
        return 1
    fi
    
    # Return values (space-separated)
    echo "$service_name $compose_path $env_path $depends"
    return 0
}

# Function to check for circular dependencies
check_circular_dependencies() {
    local yaml_file="$1"
    shift
    local services=("$@")
    
    check_circular_recursive() {
        local current="$1"
        local visited="$2"
        local path="$3"
        
        if [[ " $visited " =~ " $current " ]]; then
            error "Circular dependency detected: $path -> $current"
            return 1
        fi
        
        local new_visited="$visited $current"
        local new_path="$path -> $current"
        
        if result=$(parse_yaml_single "$current" "$yaml_file"); then
            read -r service compose_path env_path depends <<< "$result"
            
            if [ -n "$depends" ]; then
                IFS=' ' read -ra deps <<< "$depends"
                for dep in "${deps[@]}"; do
                    if [ -n "$dep" ]; then
                        if ! check_circular_recursive "$dep" "$new_visited" "$new_path"; then
                            return 1
                        fi
                    fi
                done
            fi
        fi
        
        return 0
    }
    
    for service in "${services[@]}"; do
        if ! check_circular_recursive "$service" "" "$service"; then
            return 1
        fi
    done
    
    return 0
}

# Function to resolve dependencies and deduplicate services
resolve_dependencies() {
    local yaml_file="$1"
    shift
    local services=("$@")
    local resolved=()
    local processing=()
    local original_services=("${services[@]}")
    
    # Check for circular dependencies first
    if ! check_circular_dependencies "$yaml_file" "${services[@]}"; then
        return 1
    fi
    
    # Deduplicate input services
    local unique_services=()
    for service in "${services[@]}"; do
        if [[ ! " ${unique_services[*]} " =~ " ${service} " ]]; then
            unique_services+=("$service")
        fi
    done
    
    for service in "${unique_services[@]}"; do
        processing+=("$service")
    done
    
    # Process dependencies recursively
    while [ ${#processing[@]} -gt 0 ]; do
        local current_service="${processing[0]}"
        processing=("${processing[@]:1}")
        
        # Skip if already resolved
        if [[ " ${resolved[*]} " =~ " ${current_service} " ]]; then
            continue
        fi
        
        # Get dependencies for current service
        if result=$(parse_yaml_single "$current_service" "$yaml_file"); then
            read -r service compose_path env_path depends <<< "$result"
            
            # Add dependencies to processing list if they exist
            if [ -n "$depends" ]; then
                IFS=' ' read -ra deps <<< "$depends"
                local has_unresolved_deps=false
                for dep in "${deps[@]}"; do
                    if [ -n "$dep" ] && [[ ! " ${resolved[*]} " =~ " ${dep} " ]]; then
                        has_unresolved_deps=true
                        # Check if dependency is already in processing
                        if [[ ! " ${processing[*]} " =~ " ${dep} " ]]; then
                            processing=("$dep" "${processing[@]}")
                        fi
                    fi
                done
                # Don't add current service to resolved list yet if it has unresolved dependencies
                if [ "$has_unresolved_deps" = true ]; then
                    continue
                fi
            fi
            
            # Add current service to resolved list
            resolved+=("$current_service")
        else
            if [ "$VERBOSE" = true ]; then
                yellow "Warning: Failed to parse service '$current_service', skipping dependencies"
            fi
        fi
    done
    
    # Ensure all original services are included in the final order
    for service in "${original_services[@]}"; do
        if [[ ! " ${resolved[*]} " =~ " ${service} " ]]; then
            resolved+=("$service")
        fi
    done
    
    # Return resolved service order
    echo "${resolved[@]}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to find compose and env files for services
find_service_files() {
    local services=("$@")
    local compose_files=()
    local env_files=()
    
    # Print to stderr so it doesn't interfere with the output
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}merging configuration files...${NC}" >&2
    fi
    
    for service in "${services[@]}"; do
        # Find compose file in service directory
        local service_dir="$SERVICES_DIR/$service"
        local compose_file="$service_dir/$COMPOSE_FILE"
        local env_file="$service_dir/$ENV_FILE"
        
        # Check compose file
        if [[ -f "$compose_file" ]]; then
            compose_files+=("$compose_file")
            if [ "$VERBOSE" = true ]; then
                echo -e "  ${YELLOW}$compose_file${NC}" >&2
            fi
        else
            error "compose file not found for service: $service at $compose_file" >&2
            exit 1
        fi
        
        # Check env file
        if [[ -f "$env_file" ]]; then
            env_files+=("$env_file")
            if [ "$VERBOSE" = true ]; then
                echo -e "  ${YELLOW}$env_file${NC}" >&2
            fi
        else
            if [ "$VERBOSE" = true ]; then
                yellow "Warning: environment file not found for service: $service at $env_file" >&2
            fi
        fi
    done
    
    # Return arrays
    echo "${compose_files[@]}"
    echo "${env_files[@]}"
}

# Function to merge Docker Compose files
merge_compose_files() {
    local output_file="$1"
    shift
    local compose_files=("$@")
    
    echo -e "${GREEN}merging ${YELLOW}${#compose_files[@]} ${GREEN}docker-compose configuration files...${NC}"
    
    # Check if Python and PyYAML are available
    if ! command_exists python3; then
        error "Python 3 is required for merging Docker Compose files"
        exit 1
    fi
    
    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"
    
    # Use Python to merge YAML files
    python3 << EOF
import yaml
import sys

compose_files = [$(printf "'%s'," "${compose_files[@]}" | sed 's/,$//')]
output_file = '$output_file'

merged_data = {}
merged_data['services'] = {}
merged_data['networks'] = {}
merged_data['volumes'] = {}

for file_path in compose_files:
    try:
        with open(file_path, 'r') as f:
            compose_data = yaml.safe_load(f) or {}
        
        # Merge each section
        for key, value in compose_data.items():
            if key == 'services' and isinstance(value, dict):
                for service_name, service_data in value.items():
                    if service_name not in merged_data['services']:
                        merged_data['services'][service_name] = service_data
                    else:
                        # Merge service configurations
                        for k, v in service_data.items():
                            merged_data['services'][service_name][k] = v
            elif key == 'networks' and isinstance(value, dict):
                merged_data['networks'].update(value)
            elif key == 'volumes' and isinstance(value, dict):
                merged_data['volumes'].update(value)
            else:
                merged_data[key] = value
                
    except Exception as e:
        print(f"error processing {file_path}: {e}", file=sys.stderr)
        sys.exit(1)

# Add env_file to each service
for service_name in merged_data.get('services', {}).keys():
    if 'env_file' not in merged_data['services'][service_name]:
        merged_data['services'][service_name]['env_file'] = './deployment/temp/.env.merged'

# Write merged YAML
with open('$output_file', 'w') as f:
    yaml.dump(merged_data, f, default_flow_style=False, sort_keys=False)
EOF
    
    echo -e "${GREEN}docker-compose configuration merged successfully${NC}"
}

# Function to merge environment files
merge_env_files() {
    local output_file="$1"
    shift
    local env_files=("$@")
    
    if [ ${#env_files[@]} -eq 0 ]; then
        yellow "Warning: No environment files to merge"
        return
    fi
    
    echo -e "${GREEN}merging ${#env_files[@]} environment files...${NC}"
    
    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"
    
    # Create a temporary file for merging
    local temp_file=$(mktemp)
    
    # Concatenate all environment files
    for env_file in "${env_files[@]}"; do
        if [[ -f "$env_file" ]]; then
            cat "$env_file" >> "$temp_file"
            echo "" >> "$temp_file"  # Add empty line between files
        fi
    done
    
    # Move temp file to output
    mv "$temp_file" "$output_file"
    
    echo -e "${GREEN}merged environment file created: ${YELLOW}$output_file${NC}"
}

# Function to calculate file checksum
calculate_checksum() {
    local file="$1"
    if [ -f "$file" ]; then
        if command_exists md5sum; then
            md5sum "$file" | cut -d' ' -f1
        elif command_exists md5; then
            md5 -q "$file"
        elif command_exists sha256sum; then
            sha256sum "$file" | cut -d' ' -f1
        elif command_exists sha256; then
            sha256 -q "$file"
        else
            error "No checksum utility found"
            return 1
        fi
    else
        error "File not found: $file"
        return 1
    fi
}

# Function to ask user for confirmation
ask_confirmation() {
    local message="$1"
    
    if [ "$INTERACTIVE_MODE" = true ]; then
        read -p "$message [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            return 1
        else
            return 0
        fi
    else
        # Non-interactive mode - default to yes
        return 0
    fi
}

# Function to move merged files to root directory
move_merged_files() {
    local temp_dir="$OUTPUT_DIR"
    local project_root="$(pwd)"
    
    local merged_compose="$temp_dir/docker-compose.merged.yml"
    local merged_env="$temp_dir/.env.merged"
    local root_compose="$project_root/docker-compose.yml"
    local root_merged_compose="$project_root/docker-compose.merged.yml"
    local root_env="$project_root/.env"
    local root_merged_env="$project_root/.env.merged"
    
    local compose_target=""
    local env_target=""
    local final_env_path=""
    
    # If docker-compose.yml exists in root
    if [ -f "$root_compose" ]; then
        # Replace docker-compose.merged.yml in root (delete if exists, copy new one)
        [ -f "$root_merged_compose" ] && rm -f "$root_merged_compose"
        cp "$merged_compose" "$root_merged_compose"
        compose_target="$root_merged_compose"
        green "Saved: docker-compose.merged.yml (replaced old one if existed)"
        
        # Replace .env.merged in root (delete if exists, copy new one)
        [ -f "$root_merged_env" ] && rm -f "$root_merged_env"
        cp "$merged_env" "$root_merged_env"
        env_target="$root_merged_env"
        final_env_path="$root_merged_env"
        green "Saved: .env.merged (replaced old one if existed)"
        
        # Update env_file reference
        update_env_file_reference "$root_merged_compose" "$final_env_path"
        
    # If docker-compose.yml does NOT exist in root
    else
        # Copy merged compose as docker-compose.yml
        cp "$merged_compose" "$root_compose"
        compose_target="$root_compose"
        green "Saved: docker-compose.yml (no existing compose)"
        
        # Handle .env file based on its existence
        if [ -f "$root_env" ]; then
            # .env exists - save merged as .env.merged
            [ -f "$root_merged_env" ] && rm -f "$root_merged_env"
            cp "$merged_env" "$root_merged_env"
            env_target="$root_merged_env"
            final_env_path="$root_merged_env"
            green "Saved: .env.merged (.env exists)"
        else
            # .env doesn't exist - save merged as .env
            [ -f "$root_merged_env" ] && rm -f "$root_merged_env"
            cp "$merged_env" "$root_env"
            env_target="$root_env"
            final_env_path="$root_env"
            green "Saved: .env (no existing .env)"
        fi
        
        # Update env_file reference in docker-compose.yml
        update_env_file_reference "$root_compose" "$final_env_path"
    fi
    
    # Report to user
    echo ""
    green "Configuration files created:"
    echo -e "  ${YELLOW}Compose: $compose_target${NC}"
    echo -e "  ${YELLOW}Environment: $env_target${NC}"
    
    return 0
}

# Function to update env_file reference in merged compose file
update_env_file_reference() {
    local compose_file="$1"
    local env_file="$2"
    
    # Convert absolute path to relative path from project root
    local project_root="$(pwd)"
    local relative_env_path="${env_file#$project_root/}"
    
    if [ "$VERBOSE" = true ]; then
        green "Updating env_file reference in compose file to: $relative_env_path"
    fi
    
    # Use Python to update the env_file path
    python3 << EOF
import yaml
import sys

compose_file = '$compose_file'
new_env_path = './$relative_env_path'

try:
    # Read the compose file
    with open(compose_file, 'r') as f:
        compose_data = yaml.safe_load(f) or {}
    
    # Update env_file for each service
    if 'services' in compose_data:
        for service_name in compose_data['services']:
            if 'env_file' in compose_data['services'][service_name]:
                compose_data['services'][service_name]['env_file'] = new_env_path
    
    # Write back the updated compose file
    with open(compose_file, 'w') as f:
        yaml.dump(compose_data, f, default_flow_style=False, sort_keys=False)
        
except Exception as e:
    print(f"Error updating env_file reference: {e}", file=sys.stderr)
    sys.exit(1)
EOF
}

# Main function
main() {
    parse_args "$@"
    
    green "running docker-compose setup..."
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}discovering services config in: ${YELLOW}$YAML_FILE"
        echo -e "${GREEN}services to run: ${YELLOW}${SERVICES[*]}"
    fi
    
    # Resolve dependencies and get execution order
    green "resolving dependencies..."
    local execution_order
    execution_order=($(resolve_dependencies "$YAML_FILE" "${SERVICES[@]}"))
    
    if [ $? -ne 0 ]; then
        error "dependency resolution failed"
        exit 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}resolved services to run: ${YELLOW}${execution_order[*]}${NC}"
    fi
    
    local total_count=${#execution_order[@]}
    echo -e "${GREEN}processing ${YELLOW}$total_count${GREEN} service(s)...${NC}"
    
    # Find compose and env files
    declare -a compose_files
    declare -a env_files
    
    # Call find_service_files and capture output 
    local file_result
    if [ "$VERBOSE" = true ]; then
        # In verbose mode, show stderr output
        file_result=$(find_service_files "${execution_order[@]}")
    else
        # In quiet mode, hide stderr
        file_result=$(find_service_files "${execution_order[@]}" 2>/dev/null)
    fi
    
    # Split the result into compose_files and env_files
    local line_count=0
    while IFS= read -r line; do
        if [ $line_count -eq 0 ]; then
            # First line contains compose files
            read -ra compose_files <<< "$line"
        else
            # Second line contains env files
            read -ra env_files <<< "$line"
        fi
        ((line_count++))
    done <<< "$file_result"
    
    # Merge compose files
    local merged_compose="$OUTPUT_DIR/docker-compose.merged.yml"
    merge_compose_files "$merged_compose" "${compose_files[@]}"
    
    # Merge environment files
    local merged_env="$OUTPUT_DIR/.env.merged"
    if [ ${#env_files[@]} -gt 0 ]; then
        merge_env_files "$merged_env" "${env_files[@]}"
    fi
    
    # Show merged files
    green "merged files created:"
    echo -e "  ${YELLOW}compose: $merged_compose${NC}"
    if [[ -f "$merged_env" ]]; then
        echo -e "  ${YELLOW}environment: $merged_env${NC}"
    fi
    
    # Move merged files to root directory if needed
    if [ "$VERBOSE" = true ]; then
        green "moving merged files to root directory..."
    fi
    
    move_merged_files
    
    # Run docker-compose with merged files
    #run_docker_compose
    
    green "all services processed successfully"
}

# Run main function with all arguments
main "$@"
