# GitHub Multi-User SSH Key Manager

A Bash utility for managing multiple GitHub SSH keys on a single machine. It simplifies creating, configuring, and testing SSH keys for different GitHub accounts (e.g., personal, work) without manual editing of `~/.ssh/config`.

## Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
  - [Interactive Mode](#interactive-mode)
  - [Command-Line Mode](#command-line-mode)
- [Commands](#commands)
  - [add](#add)
  - [remove](#remove)
  - [list](#list)
  - [linked](#linked)
  - [check](#check)
  - [delete-all](#delete-all)
- [How It Works](#how-it-works)
  - [Key Generation](#key-generation)
  - [SSH Config](#ssh-config)
  - [Using a Key with Git](#using-a-key-with-git)
- [Examples](#examples)
- [File Structure](#file-structure)
- [Potential Improvements](#potential-improvements)

## Overview

When working with multiple GitHub accounts, each account needs its own SSH key. This script automates the process of:

1. Generating Ed25519 SSH key pairs per profile name
2. Adding host alias entries to `~/.ssh/config`
3. Loading keys into the SSH agent
4. Printing the public key for easy copy-paste into GitHub
5. Testing which keys successfully authenticate with GitHub

## Prerequisites

- **Bash** (version 4.0+)
- **OpenSSH** (`ssh-keygen`, `ssh-agent`, `ssh-add`)
- **Git** (for cloning repos using the configured aliases)
- A GitHub account for each profile you intend to set up

## Installation

```bash
git clone https://github.com/<your-username>/githubMultiuserAuthSSH.git
cd githubMultiuserAuthSSH
chmod +x setupGithubSSHKey.sh
```

## Usage

### Interactive Mode

Run the script with no arguments to launch the interactive menu:

```bash
./setupGithubSSHKey.sh
```

This presents a numbered menu:

```
================ GitHub SSH Key Manager ================
1) Add new SSH key
2) Remove a key
3) List local keys
4) Check which keys authenticate (linked)
5) Delete all keys
6) Test a key by alias
0) Exit
========================================================
```

### Command-Line Mode

Pass a command directly for non-interactive use:

```bash
./setupGithubSSHKey.sh <command> [arguments]
```

## Commands

### add

Generate a new SSH key and configure `~/.ssh/config` for a profile.

```bash
./setupGithubSSHKey.sh add <email> <profile>
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `email` | The email address associated with the GitHub account |
| `profile` | A short label for the profile (e.g., `personal`, `work`) |

**What it does:**
1. Creates `~/.ssh/id_ed25519_<profile>` (private) and `~/.ssh/id_ed25519_<profile>.pub` (public)
2. Starts `ssh-agent` and adds the key
3. Appends a `Host github-<profile>` block to `~/.ssh/config`
4. Prints the public key so you can add it to GitHub under **Settings > SSH and GPG Keys**

**Example:**
```bash
./setupGithubSSHKey.sh add john@example.com work
```

If the key file already exists, generation is skipped and the existing key is loaded.

### remove

Delete a key pair and its SSH config entry.

```bash
./setupGithubSSHKey.sh remove <profile>
```

Removes `~/.ssh/id_ed25519_<profile>`, `~/.ssh/id_ed25519_<profile>.pub`, and the corresponding `Host github-<profile>` block from `~/.ssh/config`.

### list

List all Ed25519 key files in `~/.ssh`.

```bash
./setupGithubSSHKey.sh list
```

### linked

Check which local keys successfully authenticate with GitHub.

```bash
./setupGithubSSHKey.sh linked
```

Iterates over every `id_ed25519*` key and attempts an SSH connection to `git@github.com`, reporting which GitHub user each key maps to (or if permission is denied).

### check

Test a specific host alias.

```bash
./setupGithubSSHKey.sh check <alias>
```

**Example:**
```bash
./setupGithubSSHKey.sh check github-work
```

Runs `ssh -T <alias>` to verify the connection. A successful test prints: `Hi <username>! You've successfully authenticated...`

### delete-all

Delete **all** Ed25519 SSH keys and their config entries. Prompts for confirmation before proceeding.

```bash
./setupGithubSSHKey.sh delete-all
```

## How It Works

### Key Generation

Keys are generated using the Ed25519 algorithm with an empty passphrase:

```bash
ssh-keygen -t ed25519 -C "<email>" -f ~/.ssh/id_ed25519_<profile> -N ""
```

Each profile gets a unique key file named after the profile label.

### SSH Config

For each profile, a host alias block is appended to `~/.ssh/config`:

```
Host github-<profile>
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_<profile>
  IdentitiesOnly yes
```

`IdentitiesOnly yes` ensures SSH only offers the specified key to GitHub, preventing conflicts between multiple keys.

### Using a Key with Git

After setup, clone repositories using the host alias instead of `github.com`:

```bash
# Instead of:
git clone git@github.com:username/repo.git

# Use:
git clone git@github-work:username/repo.git
```

For existing repositories, update the remote URL:

```bash
git remote set-url origin git@github-work:username/repo.git
```

## Examples

**Full workflow for setting up two accounts:**

```bash
# Add a personal account key
./setupGithubSSHKey.sh add personal@gmail.com personal
# Copy the printed public key to https://github.com/settings/keys

# Add a work account key
./setupGithubSSHKey.sh add work@company.com work
# Copy the printed public key to the work GitHub account

# Verify both keys authenticate
./setupGithubSSHKey.sh linked

# Clone a repo with the work account
git clone git@github-work:org/project.git
```

## File Structure

```
~/.ssh/
  config                      # SSH host alias entries (managed by this script)
  id_ed25519_personal         # Private key for "personal" profile
  id_ed25519_personal.pub     # Public key for "personal" profile
  id_ed25519_work             # Private key for "work" profile
  id_ed25519_work.pub         # Public key for "work" profile
```

## Potential Improvements

- **Passphrase support** -- Currently keys are generated with an empty passphrase (`-N ""`). Adding optional passphrase prompts would improve security.
- **Backup and restore** -- Add commands to export and import key pairs and config entries for migration between machines.
- **Per-repo Git identity** -- Automatically set `user.name` and `user.email` in a repository's local Git config based on the profile, so commits use the correct author.
- **GitHub API integration** -- Use the GitHub API (via `gh` CLI or `curl`) to automatically upload the public key to the correct GitHub account, eliminating the manual copy-paste step.
- **Key rotation** -- Add a `rotate` command that generates a new key for a profile, uploads it, and removes the old one.
- **Passphrase-protected key management** -- Integrate with `ssh-agent` or a keychain daemon to cache passphrases, avoiding repeated prompts.
- **Tab completion** -- Provide Bash/Zsh completion scripts for commands and profile names.
- **Profile listing in config** -- Add a command that parses `~/.ssh/config` and lists all configured GitHub host aliases with their associated key paths.
- **Logging** -- Write operations (add, remove, delete-all) to a log file for audit purposes.
- **Cross-platform support** -- Handle differences on macOS (e.g., `--apple-use-keychain` flag for `ssh-add`, `sed -i ''` syntax) to make the script portable.
