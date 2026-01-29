#!/bin/bash

###############################################################################
#                    FLUX – TERMINAL BUILD & RUN SCRIPT                      #
#                                                                             #
# This script provides a complete terminal-based build and run experience    #
# Usage: ./flux-terminal.sh [command]                                        #
#                                                                             #
# Commands:                                                                   #
#   build           Build the app (Debug)                                    #
#   build-release   Build the app (Release)                                  #
#   run             Build and run the app                                    #
#   run-release     Build and run the app (Release)                          #
#   clean           Clean build artifacts                                    #
#   feedback        Run developer feedback analysis                          #
#   system-check    Perform complete system check                            #
#   help            Show this help message                                   #
#                                                                             #
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build"

# Check for Xcode vs Command Line Tools only
check_xcode() {
    # Full Xcode path
    if [ -d "/Applications/Xcode.app" ]; then
        return 0  # Full Xcode installed
    fi
    
    # Check if we only have Command Line Tools
    xcode_path=$(xcode-select -p 2>/dev/null)
    if [[ "$xcode_path" == *"CommandLineTools"* ]]; then
        return 1  # Only Command Line Tools
    fi
    
    return 1  # Neither found
}

# Print helpful message for CLT-only users
print_xcode_required() {
    echo -e "\n${RED}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ ⚠️  Full Xcode Required${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Your system has Command Line Tools only.${NC}"
    echo -e "${YELLOW}SwiftUI macOS apps require full Xcode to build.${NC}\n"
    
    echo -e "${CYAN}Options:${NC}\n"
    echo -e "  1. ${GREEN}Install Xcode from App Store${NC}"
    echo -e "     • Open App Store"
    echo -e "     • Search for 'Xcode'"
    echo -e "     • Click Install (~15GB download)"
    echo -e "     • Wait for installation to complete"
    echo -e "     • Then run: ${BLUE}./flux-terminal.sh run${NC}\n"
    
    echo -e "  2. ${GREEN}Install Xcode via command line${NC}"
    echo -e "     ${BLUE}xcode-select --install${NC}"
    echo -e "     (Note: This installs CLI Tools, not full Xcode)\n"
    
    echo -e "  3. ${GREEN}Use Xcode IDE directly${NC}"
    echo -e "     • Download Xcode.dmg from developer.apple.com"
    echo -e "     • Drag Xcode.app to Applications"
    echo -e "     • Then run: ${BLUE}open Flux.xcodeproj${NC}"
    echo -e "     • Press Cmd+R to build and run\n"
    
    echo -e "${CYAN}Current status:${NC}"
    xcode_path=$(xcode-select -p 2>/dev/null)
    echo -e "  Active developer directory: ${YELLOW}$xcode_path${NC}\n"
    
    return 1
}

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build"

# Functions
print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Build functions
build_debug() {
    print_header "Building Flux (Debug)"
    
    # Check for full Xcode first
    if ! check_xcode; then
        print_xcode_required
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    
    if /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -scheme Flux -configuration Debug -derivedDataPath "$BUILD_DIR"; then
        print_success "Debug build completed"
        echo -e "${CYAN}Build artifact: $BUILD_DIR/Debug/Flux.app${NC}\n"
        return 0
    else
        print_error "Debug build failed"
        return 1
    fi
}

build_release() {
    print_header "Building Flux (Release)"
    
    # Check for full Xcode first
    if ! check_xcode; then
        print_xcode_required
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    
    if /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -scheme Flux -configuration Release -derivedDataPath "$BUILD_DIR"; then
        print_success "Release build completed"
        echo -e "${CYAN}Build artifact: $BUILD_DIR/Release/Flux.app${NC}\n"
        return 0
    else
        print_error "Release build failed"
        return 1
    fi
}

run_app() {
    print_header "Running Flux"
    
    local build_type=$1
    local app_path="$BUILD_DIR/Build/Products/$build_type/Flux.app"
    
    if [ ! -d "$app_path" ]; then
        print_warning "App not found at $app_path"
        print_info "Building first..."
        
        if [ "$build_type" = "Release" ]; then
            build_release || return 1
        else
            build_debug || return 1
        fi
    fi
    
    print_info "Launching $build_type build..."
    open "$app_path"
    print_success "Flux launched (Process ID: $$)"
    
    # Show real-time logs
    print_info "Monitoring application logs...\n"
    sleep 1
    
    # Try to capture logs if available
    if command -v log &> /dev/null; then
        print_info "Press Ctrl+C to stop monitoring logs\n"
        log stream --predicate 'process == "Flux"' --level debug 2>/dev/null || true
    fi
}

system_check() {
    print_header "System Check"
    
    local issues=0
    
    # Check Swift
    if command -v swift &> /dev/null; then
        swift_version=$(swift --version)
        print_success "Swift: $swift_version"
    else
        print_error "Swift not found"
        issues=$((issues + 1))
    fi
    
    # Check Xcode
    if command -v xcode-select &> /dev/null; then
        xcode_path=$(xcode-select -p)
        print_success "Xcode: $xcode_path"
    else
        print_error "Xcode not found"
        issues=$((issues + 1))
    fi
    
    # Check Wine (Apple Silicon Homebrew installs commonly provide `wine` only)
    if command -v wine &> /dev/null; then
        wine_version=$(wine --version)
        print_success "Wine: $wine_version"
    else
        print_warning "Wine not found (required for running Windows apps)"
    fi
    
    # Check Steam
    if [ -d "$HOME/Library/Application Support/Steam" ]; then
        print_success "Steam: Installed"
    else
        print_warning "Steam not found (needed for game detection)"
    fi
    
    # Note: GPTK checking is deferred to runtime (game launch only)
    # See GPTK_RUNTIME_CHECK.md for details
    
    # Check Metal
    if system_profiler SPDisplaysDataType &>/dev/null; then
        metal_gpu=$(system_profiler SPDisplaysDataType | grep -i "chip" | head -1 | sed 's/.*: //')
        if [ -n "$metal_gpu" ]; then
            print_success "Metal GPU: $metal_gpu"
        else
            print_warning "Metal GPU detection failed"
        fi
    fi
    
    echo ""
    if [ $issues -eq 0 ]; then
        print_success "All required tools found!"
    else
        print_warning "$issues issues found"
    fi
    echo ""
}

clean_build() {
    print_header "Cleaning Build Artifacts"
    
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_success "Cleaned: $BUILD_DIR"
    fi
    
    cd "$SCRIPT_DIR"
    xcodebuild clean -scheme Flux 2>/dev/null || true
    print_success "Cleaned Xcode build"
    
    # Clean derived data
    if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
        rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/*Flux* 2>/dev/null || true
        print_success "Cleaned derived data"
    fi
    
    echo ""
}

show_status() {
    print_header "Flux Status"
    
    # Check if app is running
    if pgrep -f "Flux.app" > /dev/null; then
        local pids=$(pgrep -f "Flux.app")
        print_success "Flux is running (PIDs: $pids)"
        
        # Show memory usage
        local memory=$(ps aux | grep "Flux" | grep -v grep | awk '{sum+=$6} END {print sum " KB"}')
        print_info "Memory usage: $memory"
    else
        print_info "Flux not currently running"
    fi
    
    # Check builds
    if [ -f "$BUILD_DIR/Debug/Flux.app/Contents/MacOS/Flux" ]; then
        print_success "Debug build available"
    fi
    
    if [ -f "$BUILD_DIR/Release/Flux.app/Contents/MacOS/Flux" ]; then
        print_success "Release build available"
    fi
    
    echo ""
}

show_help() {
    cat << EOF
${BLUE}╔════════════════════════════════════════════════════╗${NC}
${BLUE}║             FLUX TERMINAL INTERFACE               ║${NC}
${BLUE}╚════════════════════════════════════════════════════╝${NC}

${CYAN}USAGE:${NC}
    $0 [command]

${CYAN}COMMANDS:${NC}
    ${GREEN}build${NC}              Build Flux (Debug configuration)
    ${GREEN}build-release${NC}      Build Flux (Release configuration)
    ${GREEN}run${NC}                Build and run Flux (Debug)
    ${GREEN}run-release${NC}        Build and run Flux (Release)
    ${GREEN}clean${NC}              Clean all build artifacts
    ${GREEN}status${NC}             Show current status
    ${GREEN}system-check${NC}       Perform complete system check
    ${GREEN}help${NC}               Show this help message

${CYAN}EXAMPLES:${NC}
    $0 build              # Build debug version
    $0 run                # Build and run
    $0 clean              # Clean all builds
    $0 system-check       # Check system requirements

${CYAN}BUILD ARTIFACTS:${NC}
    Debug:   $BUILD_DIR/Debug/Flux.app
    Release: $BUILD_DIR/Release/Flux.app

${CYAN}KEYBOARD SHORTCUTS (in Xcode):${NC}
    Cmd+B               Build
    Cmd+R               Build and Run
    Cmd+Shift+K         Clean
    Cmd+Option+Return   Show previews

EOF
}

# Main script logic
main() {
    local command=${1:-help}
    
    case "$command" in
        build)
            build_debug
            ;;
        build-release)
            build_release
            ;;
        run)
            build_debug && run_app Debug
            ;;
        run-release)
            build_release && run_app Release
            ;;
        clean)
            clean_build
            ;;
        status)
            show_status
            ;;
        system-check)
            system_check
            ;;
        help)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
