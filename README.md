[![asciicast](https://asciinema.org/a/1051683.svg)](https://asciinema.org/a/1051683)

> a minimalist zsh prompt theme inspired by [geometry](https://github.com/geometry-zsh/geometry), fast *by design*.

At a glance, you see what matters. Nothing else clutters your prompt.

- Current branch, tag, or short commit SHA
- Clean `⬢` or dirty `⬡` working tree
- Commits `⇡` ahead or `⇣` behind upstream
- Time since the last commit
- Elapsed time on long-running commands
- Background job count

## Install

### [antidote](https://antidote.sh) *(recommended)*

Add this to your `~/.zsh_plugins.txt`:

```
dio-az/hexagon
```

### [zplug](https://github.com/zplug/zplug)

Add this to your `~/.zshrc`:

```sh
zplug "dio-az/hexagon"
```

## Styling

Hexagon uses `zstyle` for configuration. The general format is:

```zsh
zstyle ':hexagon:context' property value
```

For example, to change the path color to cyan:

```zsh
zstyle ':hexagon:path' color cyan
```

### Prompt path

The path on the left is yours to style:

| Context         | Property | Default | Description                                    |
| --------------- | -------- | ------- | ---------------------------------------------- |
| `:hexagon:path` | `color`  | `blue`  | Left-prompt path color                         |
| `:hexagon:path` | `format` | `%2~`   | Left-prompt path format (zsh prompt expansion) |

### Components

Add, drop, or rearrange the right-prompt pieces:

| Context    | Property     | Default          | Description                       |
| ---------- | ------------ | ---------------- | --------------------------------- |
| `:hexagon` | `components` | `timer jobs git` | Right-prompt components, in order |

### Timer

Slow commands quietly show how long they took:

| Context          | Property    | Default | Description                                             |
| ---------------- | ----------- | ------- | ------------------------------------------------------- |
| `:hexagon:timer` | `threshold` | `5`     | Seconds a command must run before elapsed time is shown |

### Duration

Customize the color of the durations shown by git elapsed and timer:

| Context                    | Property | Default | Description                      |
| -------------------------- | -------- | ------- | -------------------------------- |
| `:hexagon:duration:day`    | `color`  | `red`   | Color for day-scale durations    |
| `:hexagon:duration:hour`   | `color`  | `white` | Color for hour-scale durations   |
| `:hexagon:duration:minute` | `color`  | `green` | Color for minute-scale durations |
| `:hexagon:duration:second` | `color`  | `green` | Color for second-scale durations |

### Jobs

See how many background jobs are running:

| Context         | Property | Default | Description                         |
| --------------- | -------- | ------- | ----------------------------------- |
| `:hexagon:jobs` | `color`  | `blue`  | Job count color                     |
| `:hexagon:jobs` | `symbol` | `⚙`     | Symbol rendered after the job count |

### Git

Inside a repo, see your branch, working-tree state, and upstream tracking:

| Context                     | Property     | Default                        | Description                                  |
| --------------------------- | ------------ | ------------------------------ | -------------------------------------------- |
| `:hexagon:git`              | `components` | `remote branch elapsed status` | Git sub-components, in order                 |
| `:hexagon:git:branch`       | `color`      | `242`                          | Branch, tag, or short SHA color              |
| `:hexagon:git:status:clean` | `color`      | `green`                        | Status indicator color when tree is clean    |
| `:hexagon:git:status:clean` | `symbol`     | `⬢`                            | Status symbol when tree is clean             |
| `:hexagon:git:status:dirty` | `color`      | `red`                          | Status indicator color when tree has changes |
| `:hexagon:git:status:dirty` | `symbol`     | `⬡`                            | Status symbol when tree has changes          |
| `:hexagon:git:remote`       | `color`      | `default`                      | Ahead/behind indicator color                 |
| `:hexagon:git:remote`       | `ahead`      | `⇡`                            | Symbol shown when ahead of upstream          |
| `:hexagon:git:remote`       | `behind`     | `⇣`                            | Symbol shown when behind upstream            |

> [!TIP]
> The `elapsed` sub-component is styled via [`:hexagon:duration:*`](#duration).

## Custom components

A component is a shell function named `hexagon_<name>` that writes its output to `stdout`.

> [!TIP]
> Return without printing anything to hide the component.

Register custom components by setting `:hexagon` `components`. This *replaces* the list, so include any built-ins you still want:

```zsh
zstyle ':hexagon' components <name> timer jobs git
```

The following helper functions are available:

| Helper                                                 | Description                                                           |
| ------------------------------------------------------ | --------------------------------------------------------------------- |
| `hexagon::color <color> <text>`                        | Wrap `text` in a `%F{color}text%f` prompt escape                      |
| `hexagon::escape <text>`                               | Neutralize prompt metacharacters (`%`, `!`, `$`, `` ` ``, `\`)        |
| `hexagon::style -s <context> <property> <default>`     | Read a scalar `zstyle` into `$<property>`, defaulting to `<default>`  |
| `hexagon::style -a <context> <property> <defaults...>` | Like `-s`, but for array styles                                       |
| `hexagon::duration <seconds>`                          | Format a duration label (`5s`, `3m`), styled by `:hexagon:duration:*` |

> [!IMPORTANT]
> Always run untrusted text through `hexagon::escape` before printing it, or it can hijack the prompt and run arbitrary commands.

Here is a component that shows the active major Node.js version:

```zsh
hexagon_node() {
	command -v node &>/dev/null || return

	local color symbol
	hexagon::style -s ':hexagon:node' color green
	hexagon::style -s ':hexagon:node' symbol ⬡

	hexagon::color $color $symbol${${$(node --version)#v}%%.*}
}

zstyle ':hexagon' components node timer jobs git
```

Place this in your `~/.zshrc` *after* loading Hexagon.

### Git components

Like a regular component, but its function is named `hexagon_git_<name>`, registered under `:hexagon:git` `components`, and called only inside a git repository. Before it runs, the `$hexagon_git` associative array is populated with:

| Key                        | Description                                                         |
| -------------------------- | ------------------------------------------------------------------- |
| `hexagon_git[branch]`      | Branch name; tag or 7-character SHA when detached                   |
| `hexagon_git[sha]`         | Full commit SHA of `HEAD`, or `(initial)` in a repo with no commits |
| `hexagon_git[ahead]`       | Commits ahead of upstream, or empty when there's no upstream        |
| `hexagon_git[behind]`      | Commits behind upstream, or empty when there's no upstream          |
| `hexagon_git[dirty]`       | `1` when the working tree is dirty, otherwise empty                 |
| `hexagon_git[commit_time]` | Unix timestamp of the most recent commit, or empty in a fresh repo  |
| `hexagon_git[stash]`       | Number of stashes, or empty when none                               |

Here is a component that shows the stash count:

```zsh
hexagon_git_stash() {
	(( hexagon_git[stash] == 0 )) && return

	local color symbol
	hexagon::style -s ':hexagon:git:stash' color 242
	hexagon::style -s ':hexagon:git:stash' symbol ≡

	hexagon::color $color $hexagon_git[stash]$symbol
}

zstyle ':hexagon:git' components remote branch elapsed status stash
```
