# Helper Commands

Executable helper commands live in:

```text
~/.zshrc_config/bin/
```

Each executable in this directory should have its own section in this document.

That directory is added to `PATH` by:

```text
~/.zshrc_config/env.zsh
```

## aiCommit

Path:

```text
~/.zshrc_config/bin/aiCommit
```

Purpose:

1. Verify the current directory is inside a Git repository.
2. Run `git add --all`.
3. Read the staged diff with `git diff --cached --no-ext-diff --no-color`.
4. Ask `fastAI` for an imperative commit subject under 50 characters.
5. Strip risky shell quoting and extra lines.
6. Run `git commit -am "<message>"`.

Environment defaults:

```text
FASTAI_DEFAULT_PROVIDER=openrouter
FASTAI_DEFAULT_MODEL=deepseek/deepseek-v4-flash
```

Those defaults are set in:

```text
~/.zshrc_config/env.zsh
```

Dependencies:

- [`ericwooley/fastAI`](https://github.com/ericwooley/fastAI) must be installed and available on `PATH`.
- `OPENROUTER_API_KEY` should be set outside this repo.

Recommended `~/.zshrc_local` entry:

```zsh
export OPENROUTER_API_KEY='<openrouter key>'
```

Usage:

```sh
aiCommit
```

Notes:

- The command expects `fastAI` to be installed and available on `PATH`.
- Keep the OpenRouter key in `~/.zshrc_local`, not in this repo.
- It commits all tracked and staged changes after `git add --all`.
- It intentionally requests only the commit message from `fastAI`.
- It is an executable command, not a zsh function or alias.

## zshow

Path:

```text
~/.zshrc_config/bin/zshow
```

Purpose:

1. Accept a natural-language question about this zsh setup from arguments or `$EDITOR`.
2. Read text files from `~/.zshrc_config`, excluding generated completions.
3. Ask `fastAI` to answer using only that local config context.
4. Keep follow-up history in the repository global `fastAI` session.
5. Require Markdown output.
6. Render the answer through `glow`.

Dependencies:

- [`ericwooley/fastAI`](https://github.com/ericwooley/fastAI) must be installed and available on `PATH`.
- `glow` must be installed and available on `PATH`.
- `OPENROUTER_API_KEY` should be set outside this repo.

Recommended `~/.zshrc_local` entry:

```zsh
export OPENROUTER_API_KEY='<openrouter key>'
```

Usage:

```sh
zshow
zshow --new
zshow --new update my nvim plugins
zshow create a file in nvim
zshow switch tmux windows
zshow do something useful
zshow "switch tmux windows"
zh create a file in nvim
```

Notes:

- Arguments are joined with spaces, so `zshow do something useful` and `zshow "do something useful"` ask the same question.
- `zh` is an alias for `zshow`.
- Bare fragments are treated as implicit "How do I ...?" questions because punctuation and shell quoting are optional for quick use.
- Running `zshow` with no arguments opens `${EDITOR:-vi}` on a temporary Markdown file, prints a formatted question block after the editor exits, then uses it as the question.
- The editor buffer includes the last five saved zshow question/answer pairs as `#` comments when session history exists.
- Comment lines are ignored, so you can leave the history in place and type the new question below it.
- Normal runs pass `--globalSession` to `fastAI` so follow-up questions remember prior context through fastAI's persisted session history.
- Running `zshow --new` passes `--newGlobalSession` to `fastAI`, which wipes the repository global session before asking the next question.
- This requires a `fastAI` version with global-session support.
- The command sends only the contents of `~/.zshrc_config` text files that match the helper's allowlist.
- Generated completion files are skipped.
- It asks `fastAI` to say when behavior is not documented locally.
- It is an executable command, not a zsh function or alias.
