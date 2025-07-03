#!/usr/bin/env zsh

# Git Worktree Manager with Starship Integration
# Commands: wg (list/go), wn (new), wr (remove)
# 
# Color assignments stored in: ~/.config/worktree/{repo-name}/.worktree-colors
# Local VS Code settings in: .vscode/settings.local.json (add to .gitignore)
#
# Starship Integration - Add to ~/.config/starship.toml:
# 
# # Custom format
# format = """${custom.worktree}${directory}${character}"""
# 
# [custom.git_repo_name]
# command = '''
# if git rev-parse --git-dir >/dev/null 2>&1; then
#     # Get the repository name
#     repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
#     if [[ -n "$repo_root" ]]; then
#         echo "${repo_root##*/}"
#     fi
# fi
# '''
# when = 'git rev-parse --git-dir >/dev/null 2>&1'
# format = ' [$output](bold white)'
# 
# [custom.worktree]
# command = '''
# if [[ -n "$WORKTREE_COLOR" ]]; then
#     echo "$WORKTREE_COLOR"
# fi
# '''
# when = 'git rev-parse --git-dir >/dev/null 2>&1'
# format = ' [$output ](bold)'
# disabled = false

# Load configuration
if [[ -f "$HOME/.config/worktree/config.zsh" ]]; then
    source "$HOME/.config/worktree/config.zsh"
fi

# Set defaults if not configured
: ${WORKTREE_WORKSPACE_PATTERN:="*.code-workspace"}
: ${WORKTREE_STRUCTURE:="sibling"}  # Default to old behavior
: ${WORKTREE_NAME_PATTERN:="{repo}-{branch}"}
: ${WORKTREE_PARENT_DIR:="."}
: ${WORKTREE_IDE_COMMAND:=""}
: ${WORKTREE_IDE_OPTIONS:="--reuse-window"}

# Color palette for worktree indicators
WORKTREE_COLORS=(
    "🟠" "🟡" "🟢" "🔵" "🟣"
    "🟧" "🟨" "🟩" "🟦" "🟪"
)

MAIN_INDICATOR="◻️"

# Get repo root safely
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Get main repo name (consistent across all worktrees)
get_main_repo_name() {
    local current_root=$(get_repo_root)
    if [[ -z "$current_root" ]]; then
        return 1
    fi
    
    # Check if we're in a worktree or the main repo
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ "$git_dir" =~ \.git/worktrees/ ]]; then
        # We're in a worktree, extract main repo path
        local main_git_dir="${git_dir%%/.git/worktrees/*}/.git"
        local main_repo_path=$(cd "$main_git_dir/.." && pwd)
        echo "${main_repo_path##*/}"
    else
        # We're in the main repo
        echo "${current_root##*/}"
    fi
}

# Get color for branch (persistent storage)
get_worktree_color() {
    local branch="$1"
    local repo_name=$(get_main_repo_name)
    local colors_file="$HOME/.config/worktree/$repo_name/.worktree-colors"
    
    # Special case for main/master
    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
        echo "$MAIN_INDICATOR"
        return
    fi
    
    # Check if color already assigned
    if [[ -f "$colors_file" ]]; then
        local color=$(grep "^$branch=" "$colors_file" 2>/dev/null | cut -d'=' -f2)
        if [[ -n "$color" ]]; then
            echo "$color"
            return
        fi
    fi
    
    # No color assigned yet
    echo ""
}

# Assign color to branch
assign_color() {
    local branch="$1"
    local repo_name=$(get_main_repo_name)
    local colors_dir="$HOME/.config/worktree/$repo_name"
    local colors_file="$colors_dir/.worktree-colors"
    
    # Create colors directory and file if doesn't exist
    [[ ! -d "$colors_dir" ]] && mkdir -p "$colors_dir"
    [[ ! -f "$colors_file" ]] && touch "$colors_file"
    
    # Get list of used colors
    local used_colors=()
    while IFS='=' read -r b c; do
        [[ -n "$c" ]] && used_colors+=("$c")
    done < "$colors_file" 2>/dev/null
    
    # Find first unused color
    local assigned_color=""
    for color in "${WORKTREE_COLORS[@]}"; do
        if [[ ! " ${used_colors[@]} " =~ " ${color} " ]]; then
            assigned_color="$color"
            break
        fi
    done
    
    # If all colors used, use first one
    [[ -z "$assigned_color" ]] && assigned_color="${WORKTREE_COLORS[1]}"
    
    # Save assignment
    echo "$branch=$assigned_color" >> "$colors_file"
    echo "$assigned_color"
}

# Release color when branch is removed
release_color() {
    local branch="$1"
    local repo_name=$(get_main_repo_name)
    local colors_file="$HOME/.config/worktree/$repo_name/.worktree-colors"
    
    if [[ -f "$colors_file" ]]; then
        grep -v "^$branch=" "$colors_file" > "$colors_file.tmp" 2>/dev/null
        mv "$colors_file.tmp" "$colors_file"
    fi
}

# Update environment variables for current worktree
update_worktree_env() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        local branch=$(git branch --show-current 2>/dev/null)
        if [[ -n "$branch" ]]; then
            local color=$(get_worktree_color "$branch")
            if [[ -z "$color" ]] && [[ "$branch" != "main" ]] && [[ "$branch" != "master" ]]; then
                # Assign a color if none exists
                color=$(assign_color "$branch")
            fi
            export WORKTREE_BRANCH="$branch"
            export WORKTREE_COLOR="$color"
        fi
    else
        unset WORKTREE_BRANCH
        unset WORKTREE_COLOR
    fi
}

# wg - Go to worktree (or list if no arguments)
wg() {
    # Check for -c flag (create if not exists)
    local create_if_missing=false
    if [[ "$1" == "-c" ]]; then
        create_if_missing=true
        shift
    fi
    
    if [[ -z "$1" ]]; then
        # List worktrees when no argument provided
        local current_path=$(get_repo_root)
        
        git worktree list | while IFS= read -r line; do
            wt_path="${line%% *}"
            dirname="${wt_path##*/}"
            branch="${line##*\[}"
            branch="${branch%\]}"
            
            # Handle prunable worktrees
            branch="${branch% prunable}"
            
            # Get persistent color for this branch
            color=$(get_worktree_color "$branch")
            if [[ -z "$color" ]] && [[ "$branch" != "main" ]] && [[ "$branch" != "master" ]]; then
                color="[*]"  # Default for branches without assigned colors
            fi
            
            # Format directory name with bold light blue if current
            local formatted_dirname="$dirname"
            local marker=""
            if [[ "$wt_path" == "$current_path" ]]; then
                formatted_dirname=$'\033[1;36m'"$dirname"$'\033[0m'
            fi
            
            # Check if prunable
            if [[ "$line" =~ "prunable" ]]; then
                marker=" (prunable)"
            fi
            
            # Since worktree name and branch are now the same, just show directory
            printf "    %s %-30s%s\n" "$color" "$formatted_dirname" "$marker"
        done
        return 0
    fi
    
    local target="$1"
    local worktree_path
    
    # Find matching worktree
    while IFS= read -r line; do
        local wt_path="${line%% *}"
        local dirname="${wt_path##*/}"
        
        # Match on directory name or branch name
        if [[ "$dirname" =~ "$target" ]] || [[ "$line" =~ "\[$target\]" ]] || [[ "$line" =~ "\[${target}\]" ]]; then
            worktree_path="$wt_path"
            break
        fi
    done < <(git worktree list)
    
    if [[ -n "$worktree_path" && -d "$worktree_path" ]]; then
        echo "-> Going to: ${worktree_path##*/}"
        cd "$worktree_path"
        update_worktree_env  # Update env vars for Starship
    else
        if [[ "$create_if_missing" == true ]]; then
            # Create without asking
            echo "Worktree '$target' not found - creating it..."
            wn "$target"
        else
            echo "Worktree '$target' not found"
            echo ""
            # Ask if user wants to create it
            echo -n "Would you like to create a new worktree '$target'? [Y/n] "
            read -r response
            if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
                wn "$target"
            else
                echo "Cancelled"
                return 1
            fi
        fi
    fi
}

# wn - Create new worktree
wn() {
    if [[ -z "$1" ]]; then
        echo "Usage: wn <branch-name>"
        return 1
    fi
    
    local branch_name="$1"
    local repo_root=$(get_repo_root)
    local repo_name=$(get_main_repo_name)
    
    # Determine worktree directory based on structure setting
    local worktree_dir
    case "$WORKTREE_STRUCTURE" in
        "repo-subdir")
            # Branches in repo subdirectory: /path/to/repo/branch-name
            worktree_dir="$repo_root/../$repo_name/$branch_name"
            ;;
        "sibling")
            # Branches as siblings: /path/to/repo-branch-name
            worktree_dir="$repo_root/../$repo_name-$branch_name"
            ;;
        "nephew")
            # Branches in WORKTREE directory: /path/to/repo-WORKTREE/branch-name
            worktree_dir="$repo_root/../$repo_name-WORKTREE/$branch_name"
            ;;
        pattern:*)
            # Custom pattern
            local pattern="${WORKTREE_STRUCTURE#pattern:}"
            worktree_dir="${pattern//\{repo\}/$repo_name}"
            worktree_dir="${worktree_dir//\{branch\}/$branch_name}"
            # Handle relative paths
            if [[ "$worktree_dir" != /* ]]; then
                worktree_dir="$repo_root/../$worktree_dir"
            fi
            ;;
        *)
            # Fallback to legacy behavior
            local worktree_name="${WORKTREE_NAME_PATTERN//\{repo\}/$repo_name}"
            worktree_name="${worktree_name//\{branch\}/$branch_name}"
            local parent_dir="$WORKTREE_PARENT_DIR"
            if [[ "$parent_dir" == "." ]]; then
                parent_dir="$(dirname "$repo_root")"
            fi
            worktree_dir="$parent_dir/$worktree_name"
            ;;
    esac
    
    # Find workspace file using pattern
    local workspace_file=""
    if [[ -n "$WORKTREE_WORKSPACE_PATTERN" ]]; then
        workspace_file=$(find "$repo_root" -maxdepth 1 -name "$WORKTREE_WORKSPACE_PATTERN" | head -1)
        if [[ -n "$workspace_file" ]]; then
            echo "Found workspace file: $workspace_file"
        else
            echo "Warning: No workspace file matching pattern: $WORKTREE_WORKSPACE_PATTERN"
        fi
    fi
    
    # Assign color to new branch
    local color=$(assign_color "$branch_name")
    
    echo "Creating worktree: $branch_name"
    echo "Color: $color"
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$worktree_dir")"
    
    # Create worktree
    git worktree add -b "$branch_name" "$worktree_dir" || return 1
    
    # Create .vscode local settings (not tracked by git)
    mkdir -p "$worktree_dir/.vscode"
    cat > "$worktree_dir/.vscode/settings.local.json" << EOF
{
    "window.title": "$color $branch_name - \${folderName}",
    "cmake.configureOnOpen": false,
    "cmake.automaticReconfigure": false,
    "cmake.configureOnEdit": false,
    "python.defaultInterpreterPath": "\${workspaceFolder}/.venv/bin/python",
    "python.terminal.activateEnvironment": true
}
EOF
    
    # Update workspace file if it exists
    if [[ -f "$workspace_file" ]]; then
        echo "Updating Cursor/VS Code workspace..."
        
        python3 -c "
import json
import sys
try:
    with open('$workspace_file', 'r') as f:
        ws = json.load(f)
    
    # Check if folder already exists
    existing = [f for f in ws['folders'] if f.get('path') == '$worktree_dir']
    if existing:
        print('Warning: Worktree already in workspace')
        sys.exit(0)
    
    ws['folders'].append({
        'name': '$color $branch_name',
        'path': '$worktree_dir'
    })
    
    with open('$workspace_file', 'w') as f:
        json.dump(ws, f, indent='\t')
    
    print('Added to workspace: $color $branch_name')
    print('Total folders in workspace:', len(ws['folders']))
except Exception as e:
    print('Error updating workspace:', str(e))
    sys.exit(1)
" || echo "Warning: Could not update workspace file"
    fi
    
    # Go to the new worktree
    cd "$worktree_dir"
    update_worktree_env  # Set env vars for Starship
    
    # Run uv sync if uv is available
    if command -v uv >/dev/null 2>&1; then
        echo ""
        echo "Running uv sync..."
        if uv sync; then
            echo "Dependencies synced"
        else
            echo "Warning: uv sync failed, but continuing..."
        fi
    fi
    
    echo ""
    echo "Created at: $worktree_dir"
    echo ""
}


# wr - Remove worktree (with --clean option)
wr() {
    # Handle --clean option
    if [[ "$1" == "--clean" ]]; then
        echo "Cleaning stale worktrees..."
        echo ""
        
        local cleaned=0
        local repo_root=$(get_repo_root)
        
        # Get list of worktrees (skip main repo)
        git worktree list | grep -v "$(get_repo_root)" | while IFS= read -r line; do
            local wt_path="${line%% *}"
            local branch="${line##*\[}"
            branch="${branch%\]}"
            branch="${branch% prunable}"
            
            # Skip if we can't determine the branch
            [[ -z "$branch" ]] && continue
            
            # Check if worktree is clean (no uncommitted changes)
            if (cd "$wt_path" 2>/dev/null && git diff --quiet && git diff --cached --quiet); then
                # Check if branch has unpushed commits
                local upstream=$(cd "$wt_path" && git rev-parse --abbrev-ref "@{upstream}" 2>/dev/null)
                
                if [[ -z "$upstream" ]]; then
                    # No upstream - check if branch exists on any remote
                    local on_remote=$(cd "$wt_path" && git ls-remote --heads origin "$branch" 2>/dev/null)
                    if [[ -z "$on_remote" ]]; then
                        echo "  Removing $branch (never pushed)..."
                        wr "$branch"
                        ((cleaned++))
                    fi
                else
                    # Has upstream - check if fully merged
                    local ahead=$(cd "$wt_path" && git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo "0")
                    if [[ "$ahead" == "0" ]]; then
                        echo "  Removing $branch (fully merged)..."
                        wr "$branch"
                        ((cleaned++))
                    fi
                fi
            fi
        done
        
        echo ""
        echo "Cleaned $cleaned worktrees"
        return 0
    fi
    
    # Normal remove operation
    if [[ -z "$1" ]]; then
        echo "Usage: wr <branch-name>"
        echo "       wr --clean  (remove all stale worktrees)"
        return 1
    fi
    
    local branch="$1"
    local worktree_path
    local repo_root=$(get_repo_root)
    local repo_name=$(get_main_repo_name)
    
    # Find the worktree
    while IFS= read -r line; do
        if [[ "$line" =~ "$branch" ]]; then
            worktree_path="${line%% *}"
            # Extract actual branch name from the line
            local actual_branch="${line##*\[}"
            actual_branch="${actual_branch%\]}"
            actual_branch="${actual_branch% prunable}"
            branch="$actual_branch"
            break
        fi
    done < <(git worktree list)
    
    if [[ -n "$worktree_path" ]]; then
        local color=$(get_worktree_color "$branch")
        echo "Removing worktree: $color ${worktree_path##*/}"
        
        # Find and update workspace file
        local workspace_file=$(find "$repo_root" -maxdepth 1 -name "*.code-workspace" | head -1)
        if [[ -f "$workspace_file" ]]; then
            python3 -c "
import json
with open('$workspace_file', 'r') as f:
    ws = json.load(f)
ws['folders'] = [f for f in ws['folders'] if not f.get('path', '').endswith('$branch') and not f.get('path', '').endswith('${repo_name}-$branch')]
with open('$workspace_file', 'w') as f:
    json.dump(ws, f, indent='\t')
" 2>/dev/null
        fi
        
        
        # Release color assignment
        release_color "$branch"
        
        # Remove worktree and branch
        git worktree remove "$worktree_path" --force
        git branch -D "$branch" 2>/dev/null
        
        echo "Removed worktree and local branch: $branch"
    else
        echo "Error: Worktree not found: $branch"
        return 1
    fi
}

# Auto-update environment on directory change
if [[ -n "$ZSH_VERSION" ]]; then
    autoload -U add-zsh-hook
    add-zsh-hook chpwd update_worktree_env
fi

# Initialize on load
update_worktree_env

# Tab completion for wg command
_wg_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local worktrees=()
    
    # Get list of worktree names
    while IFS= read -r line; do
        local wt_path="${line%% *}"
        local dirname="${wt_path##*/}"
        worktrees+=("$dirname")
    done < <(git worktree list 2>/dev/null)
    
    # Generate completions
    COMPREPLY=($(compgen -W "${worktrees[*]}" -- "$cur"))
}

# ZSH completion
if [[ -n "$ZSH_VERSION" ]]; then
    _wg() {
        local worktrees=()
        
        # Get list of worktree names
        while IFS= read -r line; do
            local wt_path="${line%% *}"
            local dirname="${wt_path##*/}"
            worktrees+=("$dirname")
        done < <(git worktree list 2>/dev/null)
        
        _describe 'worktree' worktrees
    }
    compdef _wg wg
fi

# Bash completion
if [[ -n "$BASH_VERSION" ]]; then
    complete -F _wg_completion wg
fi
