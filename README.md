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
   # Add at the beginning of the file
   format = """
   ${custom.worktree}\
   $all
   """

   # Add at the end of the file
   [custom.worktree]
   command = '''
   if [[ -n "$WORKTREE_COLOR" ]]; then
       echo "$WORKTREE_COLOR"
   fi
   '''
   when = 'git rev-parse --git-dir >/dev/null 2>&1'
   format = '[$output ](bold)'
   '''
   ```

4. Reload your shell:
   ```bash
   source ~/.zshrc
   ```

## Commands

### `wl` - List Worktrees
Shows all worktrees with their assigned color indicators.

```bash
wl
# Output:
# 🌳 Git Worktrees:
#     🏠 my-project [main] ⟵ current
#     🔴 my-project-feature-auth [feature-auth]
#     🟡 my-project-bugfix-login [bugfix-login]
```

### `wn <branch-name>` - New Worktree
Creates a new worktree with automatic color assignment.

```bash
wn feature-payments
# Creates ../my-project-feature-payments with 🟢 indicator
```

### `wg <name>` - Go to Worktree
Switches to a worktree by name (partial matching supported).

```bash
wg payments  # Goes to my-project-feature-payments
wg main      # Goes back to main
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
3. **Persistence**: Colors are stored in `.worktree-colors` in your repo root (add to `.gitignore`)
4. **IDE Integration**: Automatically updates Cursor/VS Code workspace files

## Configuration

### Worktree Manager Configuration

Edit `~/.config/worktree/config.zsh` to customize:

```bash
# Workspace file pattern (e.g., "*.code-workspace", "myproject.code-workspace")
export WORKTREE_WORKSPACE_PATTERN="*.code-workspace"

# Worktree naming pattern
# {repo} = repository name, {branch} = branch name
export WORKTREE_NAME_PATTERN="{repo}-{branch}"

# Parent directory for worktrees
# "." = sibling directories (default)
# "$HOME/worktrees" = specific directory
export WORKTREE_PARENT_DIR="."

# IDE command (e.g., "cursor", "code", "" for none)
export WORKTREE_IDE_COMMAND="cursor"

# IDE options
export WORKTREE_IDE_OPTIONS="--reuse-window"
```

### Examples

For a project structure like:
```
~/projects/
  myapp/          (main repo)
  myapp-feature/  (worktree)
  myapp-bugfix/   (worktree)
```

Use:
```bash
export WORKTREE_NAME_PATTERN="{repo}-{branch}"
export WORKTREE_PARENT_DIR="."
```

For a centralized worktree directory:
```
~/code/myapp/     (main repo)
~/worktrees/
  myapp-feature/  (worktree)
  myapp-bugfix/   (worktree)
```

Use:
```bash
export WORKTREE_NAME_PATTERN="{repo}-{branch}"
export WORKTREE_PARENT_DIR="$HOME/worktrees"
```

### Git Configuration

Add `.worktree-colors` to your global gitignore:

```bash
echo ".worktree-colors" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```
