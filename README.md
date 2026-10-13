# `gh` for Mavericks

GitHub CLI for Mac OS X 10.9 Mavericks.

## Shell completions

Add to your shell startup file:

- `~/.bash_profile`, after loading the bash-completion package (gh's script needs its
  `_get_comp_words_by_ref`, which 10.9 doesn't ship): `. /usr/local/mavergreen/gh/share/bash-completion/completions/gh`
- `~/.zshrc`: `fpath=(/usr/local/mavergreen/gh/share/zsh/site-functions $fpath)`, then, unless your
  `~/.zshrc` already runs it, `autoload -U compinit && compinit`
- `~/.config/fish/config.fish`: `set -p fish_complete_path /usr/local/mavergreen/gh/share/fish/vendor_completions.d`
