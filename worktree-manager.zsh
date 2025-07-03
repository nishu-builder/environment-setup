#!/usr/bin/env zsh

# Git Worktree Manager with Starship Integration
# Commands: wl (list), wn (new), wg (go), wr (remove)

# Load configuration
if [[ -f "$HOME/.config/worktree/config.zsh" ]]; then
    source "$HOME/.config/worktree/config.zsh"
fi

# Set defaults if not configured
: ${WORKTREE_WORKSPACE_PATTERN:="*.code-workspace"}
: ${WORKTREE_NAME_PATTERN:="{repo}-{branch}"}
: ${WORKTREE_PARENT_DIR:="."}
: ${WORKTREE_IDE_COMMAND:=""}
: ${WORKTREE_IDE_OPTIONS:="--reuse-window"}

# Color palette for worktree indicators
WORKTREE_COLORS=(
    "🔴" "🟠" "🟡" "🟢" "🔵" "🟣" "🟤"
    "🟥" "🟧" "🟨" "🟩" "🟦" "🟪" "🟫"
    "🔶" "🔷" "❤️" "💛" "💚" "💙" "💜"
)

MAIN_INDICATOR="🏠"

# Get repo root safely
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Get color for branch (persistent storage)
get_worktree_color() {
    local branch="$1"
    local repo_root=$(get_repo_root)
    
    # Special case for main/master
    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
        echo "$MAIN_INDICATOR"
        return
    fi
    
    # Check if color already assigned
    if [[ -f "$repo_root/.worktree-colors" ]]; then
        local color=$(grep "^$branch=" "$repo_root/.worktree-colors" 2>/dev/null | cut -d'=' -f2)
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
    local repo_root=$(get_repo_root)
    
    # Create colors file if doesn't exist
    [[ ! -f "$repo_root/.worktree-colors" ]] && touch "$repo_root/.worktree-colors"
    
    # Get list of used colors
    local used_colors=()
    while IFS='=' read -r b c; do
        [[ -n "$c" ]] && used_colors+=("$c")
    done < "$repo_root/.worktree-colors" 2>/dev/null
    
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
    echo "$branch=$assigned_color" >> "$repo_root/.worktree-colors"
    echo "$assigned_color"
}

# Release color when branch is removed
release_color() {
    local branch="$1"
    local repo_root=$(get_repo_root)
    
    if [[ -f "$repo_root/.worktree-colors" ]]; then
        grep -v "^$branch=" "$repo_root/.worktree-colors" > "$repo_root/.worktree-colors.tmp" 2>/dev/null
        mv "$repo_root/.worktree-colors.tmp" "$repo_root/.worktree-colors"
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

# wl - List worktrees with colors
wl() {
    echo "🌳 Git Worktrees:"
    echo ""
    
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
            color="🌿"  # Default for branches without assigned colors
        fi
        
        # Mark current
        marker=""
        if [[ "$wt_path" == "$current_path" ]]; then
            marker=" ⟵ current"
        fi
        
        # Check if prunable
        if [[ "$line" =~ "prunable" ]]; then
            marker="$marker (prunable)"
        fi
        
        printf "    %s %-30s [%s]%s\n" "$color" "$dirname" "$branch" "$marker"
    done
}

# wn - Create new worktree
wn() {
    if [[ -z "$1" ]]; then
        echo "Usage: wn <branch-name>"
        return 1
    fi
    
    local branch_name="$1"
    local clean_name="${branch_name#*-}"  # Remove prefix if present
    local repo_root=$(get_repo_root)
    local repo_name="${repo_root##*/}"
    
    # Build worktree directory name from pattern
    local worktree_name="${WORKTREE_NAME_PATTERN//\{repo\}/$repo_name}"
    worktree_name="${worktree_name//\{branch\}/$clean_name}"
    
    # Determine parent directory
    local parent_dir="$WORKTREE_PARENT_DIR"
    if [[ "$parent_dir" == "." ]]; then
        parent_dir="$(dirname "$repo_root")"
    fi
    local worktree_dir="$parent_dir/$worktree_name"
    
    # Find workspace file using pattern
    local workspace_file=""
    if [[ -n "$WORKTREE_WORKSPACE_PATTERN" ]]; then
        workspace_file=$(find "$repo_root" -maxdepth 1 -name "$WORKTREE_WORKSPACE_PATTERN" | head -1)
    fi
    
    # Assign color to new branch
    local color=$(assign_color "$clean_name")
    
    echo "🌳 Creating worktree: $clean_name"
    echo "🎨 Color: $color"
    
    # Create worktree
    git worktree add -b "$clean_name" "$worktree_dir" || return 1
    
    # Create .vscode settings
    mkdir -p "$worktree_dir/.vscode"
    cat > "$worktree_dir/.vscode/settings.json" << EOF
{
    "window.title": "$color $clean_name - \${folderName}",
    "cmake.configureOnOpen": false,
    "cmake.automaticReconfigure": false,
    "cmake.configureOnEdit": false
}
EOF
    
    # Update workspace file if it exists
    if [[ -f "$workspace_file" ]]; then
        echo "📂 Updating Cursor/VS Code workspace..."
        
        python3 -c "
import json
with open('$workspace_file', 'r') as f:
    ws = json.load(f)
ws['folders'].append({
    'name': '$color $clean_name',
    'path': '$worktree_dir'
})
with open('$workspace_file', 'w') as f:
    json.dump(ws, f, indent='\t')
print('✅ Workspace updated')
" 2>/dev/null || echo "⚠️  Could not update workspace file"
    fi
    
    # Go to the new worktree
    cd "$worktree_dir"
    update_worktree_env  # Set env vars for Starship
    
    echo ""
    echo "✅ Created at: $worktree_dir"
    echo ""
    
    # Try to open in IDE if configured
    if [[ -n "$WORKTREE_IDE_COMMAND" ]] && command -v "$WORKTREE_IDE_COMMAND" >/dev/null 2>&1; then
        if [[ -n "$workspace_file" ]]; then
            echo "📂 Opening in $WORKTREE_IDE_COMMAND..."
            $WORKTREE_IDE_COMMAND $WORKTREE_IDE_OPTIONS "$workspace_file" 2>/dev/null
        else
            echo "📂 Opening directory in $WORKTREE_IDE_COMMAND..."
            $WORKTREE_IDE_COMMAND $WORKTREE_IDE_OPTIONS "$worktree_dir" 2>/dev/null
        fi
    fi
}

# wg - Go to worktree
wg() {
    if [[ -z "$1" ]]; then
        echo "Usage: wg <worktree-name>"
        echo ""
        wl
        return 1
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
        echo "📂 Going to: ${worktree_path##*/}"
        cd "$worktree_path"
        update_worktree_env  # Update env vars for Starship
    else
        echo "❌ Worktree not found: $target"
        echo ""
        wl
        return 1
    fi
}

# wr - Remove worktree (with --clean option)
wr() {
    # Handle --clean option
    if [[ "$1" == "--clean" ]]; then
        echo "🧹 Cleaning stale worktrees..."
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
                        echo "  🗑️  Removing $branch (never pushed)..."
                        wr "$branch"
                        ((cleaned++))
                    fi
                else
                    # Has upstream - check if fully merged
                    local ahead=$(cd "$wt_path" && git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo "0")
                    if [[ "$ahead" == "0" ]]; then
                        echo "  🗑️  Removing $branch (fully merged)..."
                        wr "$branch"
                        ((cleaned++))
                    fi
                fi
            fi
        done
        
        echo ""
        echo "✅ Cleaned $cleaned worktrees"
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
    local repo_name="${repo_root##*/}"
    
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
        echo "🗑️  Removing worktree: $color ${worktree_path##*/}"
        
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
        
        echo "✅ Removed worktree and local branch: $branch"
    else
        echo "❌ Worktree not found: $branch"
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

# Print usage on load
echo "🌳 Worktree Manager loaded: wl, wn, wg, wr"