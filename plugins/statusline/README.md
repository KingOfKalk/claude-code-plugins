# statusline

![statusline preview](screenshot.png)

A colorful Claude Code statusline that renders on a single line:

- **Model** — current model display name
- **Directory** — basename of the working directory
- **Git branch** — with a red `!` if the tree is dirty or has untracked files
- **Context window** — usage bar plus percentage; green above 50%, yellow above 20%, red below
- **Output style** — active Claude Code output style

## Installation

Install via the KingOfKalk marketplace:

```
/plugin marketplace add kingofkalk/skills
/plugin install statusline@kingofkalk-skills
```

The statusline activates automatically once the plugin is enabled — there is no slash command.

## Requirements

- `bash`
- `jq` on `PATH`
- `git` on `PATH` (used to read branch and dirty state)

## How it works

Claude Code invokes `statusline.sh` on every render, piping a JSON payload to stdin. The script extracts model, cwd, context-window remaining percentage, and output style, then prints a single ANSI-colored line. The plugin manifest (`.claude-plugin/plugin.json`) registers the script via the `statusLine` field using `${CLAUDE_PLUGIN_ROOT}` so the path resolves regardless of install location.
