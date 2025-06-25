# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing configuration files for various development tools, primarily focused on a comprehensive Neovim setup using NvChad.

## Key Commands

### Setup and Installation
- `./setup.sh` - Creates symbolic links for all dotfiles to their appropriate locations in `$HOME`
- The setup script handles `.config/nvim/lua/custom`, `.config/skhd`, `.config/aerospace`, `.tmux.conf`, `.zshrc`, `.p10k.zsh`, `.wezterm.lua`, and `.gitconfig`

### Neovim Plugin Management
- Plugins are managed through lazy.nvim
- No specific build/test commands for the Neovim configuration itself
- Individual plugins may have their own installation requirements via Mason

## Architecture

### Neovim Configuration Structure
- **Base Framework**: Built on NvChad v2.0, a Neovim configuration framework
- **Entry Point**: `nvim/init.lua` loads core modules and initializes the plugin system
- **Core Configuration**: `nvim/lua/core/` contains bootstrap, mappings, utilities, and default config
- **Custom Overrides**: `nvim/lua/custom/` contains user-specific customizations
  - `chadrc.lua` - Main configuration overrides (theme: chadracula, references plugins directory)
  - `mappings.lua` - Custom key mappings
- **Plugin Directory**: `nvim/lua/plugins/` contains both default and custom plugin specifications

### Plugin Loading Mechanism
- All plugins in `nvim/lua/plugins/` are automatically imported by lazy.nvim
- Each `.lua` file in the plugins directory should return a plugin specification table
- No index file required - lazy.nvim scans the directory automatically
- Plugins can be disabled by setting `enabled = false` in their specification
- Custom plugins are consolidated alongside default NvChad plugins for consistency

### Notable Plugins Configured
- **blink.cmp**: Modern completion engine with Copilot integration
- **copilot**: GitHub Copilot integration (chat disabled, completion enabled)
- **autosession**: Session management
- **snacks**: Various utility enhancements
- **spectre**: Search and replace functionality
- **prisma**: Prisma ORM support
- **lsp-ts-utils**: TypeScript LSP utilities

### Configuration Features
- Transparency enabled by default
- Relative line numbers enabled
- Theme toggle between "chadracula" variants
- Custom visual selection function available globally
- Mason for LSP server management
- Telescope for fuzzy finding
- Git integration via gitsigns

### File Structure Pattern
- Core NvChad files remain largely unchanged
- User customizations in `custom/` directory (mappings, theme overrides)
- All plugin configurations consolidated in `plugins/` directory
- Plugin configurations follow lazy.nvim specification format