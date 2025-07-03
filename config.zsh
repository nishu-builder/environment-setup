#!/usr/bin/env zsh

# Worktree Manager Configuration
# Copy this to ~/.config/worktree/config.zsh and customize

# Workspace file pattern
# This is used to find your .code-workspace file
# Examples:
#   "*.code-workspace"           - any workspace file
#   "myproject.code-workspace"   - specific file
#   "dev.code-workspace"         - specific file
export WORKTREE_WORKSPACE_PATTERN="*.code-workspace"

# Worktree naming pattern
# Use {repo} for repo name and {branch} for branch name
# Examples:
#   "{repo}-{branch}"     - myproject-feature-auth
#   "{branch}"            - feature-auth
#   "wt-{branch}"         - wt-feature-auth
export WORKTREE_NAME_PATTERN="{repo}-{branch}"

# Parent directory for worktrees
# Use "." for sibling directories (default)
# Use an absolute path for a specific location
# Examples:
#   "."                   - ../myproject-feature
#   "$HOME/worktrees"     - ~/worktrees/myproject-feature
export WORKTREE_PARENT_DIR="."

# IDE command
# Command to open your IDE
# Examples:
#   "cursor"              - Cursor
#   "code"                - VS Code
#   "code-insiders"       - VS Code Insiders
#   ""                    - Don't open IDE
export WORKTREE_IDE_COMMAND="cursor"

# IDE options
# Additional arguments for IDE command
# Examples:
#   "--reuse-window"      - Reuse existing window
#   "--new-window"        - Always new window
export WORKTREE_IDE_OPTIONS="--reuse-window"