# Environment Setup

A collection of tools and configurations for an enhanced development environment, focusing on Git worktree management with visual indicators.

## Features

- **Git Worktree Management**: Simplified commands for creating, switching, and removing worktrees
- **Visual Branch Indicators**: Each branch gets a unique colored emoji that appears in your prompt
- **Starship Integration**: Works seamlessly with Starship prompt
- **IDE Integration**: Automatically updates workspace files and opens new worktrees

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/nishu-builder/environment-setup.git ~/repos/environment-setup
   ```

2. Create your configuration:
   ```bash
   mkdir -p ~/.config/worktree
   cp ~/repos/environment-setup/config.zsh ~/.config/worktree/config.zsh
   # Edit ~/.config/worktree/config.zsh to match your setup
   ```

3. Add to your `~/.zshrc`:
   ```bash
   # Git Worktree Management
   eval "$(cat ~/repos/environment-setup/worktree-manager.zsh)"
   ```

4. Configure Starship (add to `~/.config/starship.toml`):
   ```toml
   # Custom format
   format = """${custom.worktree}${directory}${character}"""
   
   [custom.git_repo_name]
   command = '''
   if git rev-parse --git-dir >/dev/null 2>&1; then
       # Get the repository name
       repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
       if [[ -n "$repo_root" ]]; then
           echo "${repo_root##*/}"
       fi
   fi
   '''
   when = 'git rev-parse --git-dir >/dev/null 2>&1'
   format = ' [$output](bold white)'
   
   [custom.worktree]
   command = '''
   if [[ -n "$WORKTREE_COLOR" ]]; then
       echo "$WORKTREE_COLOR"
   fi
   '''
   when = 'git rev-parse --git-dir >/dev/null 2>&1'
   format = ' [$output ](bold)'
   disabled = false
   ```

4. Reload your shell:
   ```bash
   source ~/.zshrc
   ```

## Commands

### `wg` - List or Go to Worktree
Without arguments, lists all worktrees. With an argument, switches to that worktree.

```bash
# List all worktrees
wg
# Output:
# 🌳 Git Worktrees:
#     🏠 main                         
#     🔴 feature-auth                 
#     🟡 bugfix-login                 

# Go to a worktree
wg feature-auth  # Switches to feature-auth worktree
wg main          # Goes back to main
```

### `wn <branch-name>` - New Worktree
Creates a new worktree with automatic color assignment and runs `uv sync`.

```bash
wn feature-payments
# Creates worktree at ../my-project/feature-payments
# Assigns color 🟢
# Runs uv sync to install dependencies
```

### `wr <name>` - Remove Worktree
Removes a worktree and its local branch.

```bash
wr feature-payments
```

### `wr --clean` - Clean Stale Worktrees
Removes all worktrees that have no uncommitted changes and no unpushed commits.

```bash
wr --clean
# Removes worktrees that are fully merged and clean
```

## How It Works

1. **Color Assignment**: Each branch gets a unique colored emoji (🔴 🟠 🟡 🟢 🔵 🟣 etc.) that persists across sessions
2. **Environment Variables**: Sets `WORKTREE_COLOR` and `WORKTREE_BRANCH` that Starship can read
3. **Persistence**: Colors are stored in `~/.config/worktree/{repo-name}/.worktree-colors`
4. **IDE Integration**: Automatically updates Cursor/VS Code workspace files and creates `.vscode/settings.local.json`
5. **Python Environment**: Runs `uv sync` when creating worktrees and configures VS Code to use the local `.venv`

## Configuration

### Worktree Manager Configuration

Edit `~/.config/worktree/config.zsh` to customize:

```bash
# Workspace file pattern (e.g., "*.code-workspace", "myproject.code-workspace")
export WORKTREE_WORKSPACE_PATTERN="*.code-workspace"

# Worktree structure - how to organize worktrees
# "repo-subdir" = branches in repo subdirectory (/path/to/repo/branch-name)
# "sibling" = branches as siblings (/path/to/repo-branch-name)
# "nephew" = branches in WORKTREE directory (/path/to/repo-WORKTREE/branch-name)
# "pattern:{pattern}" = custom pattern using {repo} and {branch}
export WORKTREE_STRUCTURE="repo-subdir"

# IDE command (e.g., "cursor", "code", "" for none)
export WORKTREE_IDE_COMMAND="cursor"

# IDE options
export WORKTREE_IDE_OPTIONS="--reuse-window"
```

### Examples

**Repo Subdirectory Structure** (default):
```
~/projects/
  myapp/          (main repo)
  myapp/
    feature-auth/ (worktree)
    bugfix-login/ (worktree)
```
Use: `export WORKTREE_STRUCTURE="repo-subdir"`

**Sibling Structure**:
```
~/projects/
  myapp/              (main repo)
  myapp-feature-auth/ (worktree)
  myapp-bugfix-login/ (worktree)
```
Use: `export WORKTREE_STRUCTURE="sibling"`

**Nephew Structure**:
```
~/projects/
  myapp/              (main repo)
  myapp-WORKTREE/
    feature-auth/     (worktree)
    bugfix-login/     (worktree)
```
Use: `export WORKTREE_STRUCTURE="nephew"`

**Custom Pattern**:
```
~/projects/myapp/        (main repo)
~/worktrees/
  myapp-feature-auth/    (worktree)
  myapp-bugfix-login/    (worktree)
```
Use: `export WORKTREE_STRUCTURE="pattern:$HOME/worktrees/{repo}-{branch}"`

### Git Configuration

For VS Code local settings, add to your project's `.gitignore`:

```bash
echo ".vscode/settings.local.json" >> .gitignore
```

This ensures that worktree-specific VS Code settings aren't committed to the repository.
