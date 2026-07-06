# ChuScript

ChuScript 是一个基于 Roblox 的轻量级管理脚本框架，使用模块化命令系统组织功能，支持自动扫描并加载命令模块。

## 项目结构

- `ChuScript.lua`：主入口，负责初始化服务、注册命令和加载命令模块。
- `Commands/`：命令模块目录，包含移动、管理员、工具、辅助等命令。
- `Services/`：服务层，负责命令执行、配置、玩家选择、通知、UI 等能力。
- `Core/`：消息总线与依赖注入容器。
- `Packages/UI/`：控制台与界面相关模块。
- `Utils/`：工具函数。

## 已支持的命令

### 移动与角色控制

- `:fly` / `:f`
- `:noclip` / `:nc`
- `:walkspeed` / `:ws`
- `:jumppower` / `:jp`
- `:goto` / `:to`
- `:teleport` / `:tp`

### 基础管理员命令

- `:kill` / `:slay`
- `:heal` / `:hp`
- `:respawn` / `:re`
- `:freeze` / `:ff`
- `:unfreeze` / `:uf`
- `:sit`
- `:stand`
- `:bring` / `:gethere`

### 经典风格管理员命令

- `:god` / `:godmode`
- `:invis` / `:invisible` / `:ghost`
- `:visible` / `:vis`
- `:explode` / `:boom`
- `:reset` / `:rejoin`
- `:kick`

### 扩展管理员命令

- `:tool` / `:giveweapon` / `:giveitem`
- `:removeTool` / `:rmtool`
- `:tpall` / `:bringall`
- `:spin`
- `:ragdoll`
- `:unragdoll`
- `:sethealth` / `:health`

### 高级管理员命令

- `:ban`
- `:unban`
- `:mute`
- `:unmute`
- `:serverlock` / `:lockserver`
- `:serverunlock` / `:unlockserver`
- `:announce` / `:bc` / `:broadcast`

### 辅助命令

- `:help` / `:?`
- `:ping`
- `:say`

## 使用方式

1. 将整个项目放入 Roblox Studio 的工具脚本或插件脚本环境中。
2. 运行主入口脚本 `ChuScript.lua`。
3. 在控制台或命令输入界面输入命令，例如：
   - `:fly me 80`
   - `:noclip me`
   - `:heal me`
   - `:god me`
   - `:tp 0 0 0`

## 说明

- 当前实现以“可扩展命令模块”为核心，适合继续扩展为更完整的 Roblox 管理脚本。
- 部分命令依赖 Roblox 运行时对象，如 `Humanoid`、`HumanoidRootPart`、`Explosion` 等。
