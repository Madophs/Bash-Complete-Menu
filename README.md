# Bash-Complete-Menu

Interactive, Zsh-style visual tab-completion menu written in pure Bash—with zero external dependencies.

<!-- Drag and drop your demo .mp4 or .gif here in GitHub's editor -->

## Features

- **Pure Bash & Zero Dependencies:** Uses native Bash completion (`compgen` / `complete`) and ANSI escape sequences—no `fzf`, Python, or compiled binaries required.
- **Visual Grid Selection:** Navigate matches interactively without cluttering your terminal scrollback.
- **Context-Aware Line Parsing:**
  - Completes commands, subcommands/flags (`git st` → `git status`), files, directories, and shell variables (`$VAR` / `${VAR}`).
  - Handles pipes (`|`), logical operators (`&&`, `||`), redirections (`>`, `>>`, `<<<`), command substitutions (`$(...)`), and process substitutions (`<(...)`).
  - Supports mid-line cursor completion (`READLINE_POINT`) inside existing expressions.
  - Quote- and space-aware: escapes spaces automatically (`dir\ name`) or preserves them inside open quotes (`"dir name`), while ignoring literal strings inside single/double quotes.

## Requirements

- **Bash 5.0+**
- `bash-completion` *(optional, recommended for subcommand and flag completions)*

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Madophs/Bash-Complete-Menu ~/.local/share/bash-complete-menu
   ```

2. Source the script and bind `Tab` (`\C-i`) in your `~/.bashrc`:
   ```bash
   if [[ -f "${HOME}/.local/share/bash-complete-menu/bash_complete_menu.sh" ]]; then
       source "${HOME}/.local/share/bash-complete-menu/bash_complete_menu.sh"
       bind -x '"\C-i":bash_complete_menu'
   fi
   ```

3. Reload your shell:
   ```bash
   source ~/.bashrc
   ```

## Usage & Controls

Press **`Tab`** at any point on the command line to open the visual completion menu:

| Key | Action |
| :--- | :--- |
| **`Up`** / **`Down`** / **`Left`** / **`Right`** | Move freely among completion items |
| **`Tab`** / **`Shift+Tab`** | Move to next and previous completion item |
| **`Enter`** | Accept selection and close menu |
| **`Esc`** | Cancel and restore original line |


## Running Tests

Tests are written using [`fwktest_bash`](https://github.com/Madophs/fwktest_bash) (included as a git submodule).


```bash
git submodule update --init --recursive
cd tests
bash -i ./run_tests.sh
```

*(Running with `bash -i` enables interactive-mode completion tests for environment variables.)*

## License

This project is licensed under the [GPL-3.0 License](LICENSE).
