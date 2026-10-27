# .NET Core Console Reference App

Goal: Create a project that can be used as a template for .NET Core and the use of Claude code.

Goal: Have a shareable developer experience

Goal: Have use of Claude Code adhere to data governance and AI Policy Use

 Core Technologies:
  - .NET Core
  - Docker Development Environment
  - Claude Code
  - WSL2
  - Dependency Injection

## Environment Variable
```
~/.profile

export BUILDX_BAKE_ENTITLEMENTS_FS=0
```

See https://github.com/microsoft/vscode-remote-release/issues/11896

## To run

App source repo should be in linux filesystem portion of wsl2 ( not the /mnt/ portion of Windows)

```
code .

```

When asked click the `Reopen in Container Button`
