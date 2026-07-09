# Tmux

The tmux config lives at:

```text
~/.tmux.conf
```

The repo copy is:

```text
.tmux.conf
```

## Prefix

The standard prefix is kept:

```text
Ctrl-b
```

## General Settings

- mouse support is enabled
- history limit is `100000`
- windows and panes start at index `1`
- windows are renumbered automatically
- RGB terminal color support is enabled
- extended key support is enabled so modified keys such as `Ctrl-Left` and
  `Ctrl-Right` pass through to shells and editors
- the config avoids newer `extended-keys-format` syntax so older Linux tmux
  versions can still load it
- copy mode uses vi keys

## Windows

| Key | Action |
| --- | --- |
| `Ctrl-b c` | Create window in current pane directory |
| `Ctrl-b ,` | Rename current window |
| `Ctrl-b n` | Previous window |
| `Ctrl-b m` | Next window |

The `n` and `m` bindings were chosen for left/right movement.

## Panes

| Key | Action |
| --- | --- |
| `Ctrl-b "` | Split vertically in current pane directory |
| `Ctrl-b %` | Split horizontally in current pane directory |
| `Ctrl-b h` | Move to pane on the left |
| `Ctrl-b j` | Move to pane below |
| `Ctrl-b k` | Move to pane above |
| `Ctrl-b l` | Move to pane on the right |

New panes preserve the current pane's directory.

## Copy And Paste

| Key | Action |
| --- | --- |
| `Ctrl-b [` | Enter copy mode |
| `v` | Begin selection in copy mode |
| `y` | Copy selection with `pbcopy` |
| `Enter` | Copy selection with `pbcopy` |
| mouse drag | Copy selection with `pbcopy` |
| `Ctrl-b p` | Paste tmux buffer |
| `Ctrl-b P` | Load macOS clipboard with `pbpaste` and paste it |

Clipboard bindings currently target macOS via `pbcopy` and `pbpaste`.

## Reload Config

After pulling tmux config changes, reload existing sessions with:

```sh
tmux source-file ~/.tmux.conf
```
