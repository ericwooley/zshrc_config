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
