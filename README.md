<details><summary>目录</summary><p>

- [install Claude Code](#install-claude-code)
    - [macOS](#macos)
    - [windows](#windows)
    - [usage](#usage)
- [project setup](#project-setup)
</p></details><p></p>

# install Claude Code

## macOS

```bash
$ brew install --cask claude-code
```

## windows

```bash
$ mkdir claude_code_proj
$ curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
```

## usage

```bash
$ claude --help
$ claude
```

# project setup

1. install Node JS

```bash
$ node -v
$ npm -v
```

2. download `uigen.zip` and extract it
3. install dependencies and set up a local SQLite database

```bash
$ cd uigen
$ npm run setup
```

4. start project

```bash
$ npm run dev
```
