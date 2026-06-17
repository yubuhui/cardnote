# Git 上传指南

> 项目：CardNote — 基于 HarmonyOS 的闪卡记忆/间隔复习应用

## 快速上传

根目录已有脚本 `git-upload.ps1`，一键完成 add → commit → push：

```powershell
# 使用默认提交信息
.\git-upload.ps1

# 自定义提交信息（推荐）
.\git-upload.ps1 -message "feat: 你的提交信息"
```

## 脚本做了什么

| 步骤 | 命令 | 说明 |
|------|------|------|
| 1. 定位 | `Set-Location` | 切换到项目根目录 |
| 2. 查看 | `git status` | 展示待提交文件 |
| 3. 暂存 | `git add -A` | 添加所有更改 |
| 4. 提交 | `git commit -m` | 使用传入的 message |
| 5. 推送 | `git push` | 推送到 origin |

## 最近提交记录（范例）

```
b92a32c feat: refine backup, WebDAV sync, and data layer
b0c43d8 feat: 完善备份功能、WebDAV同步及数据层优化
6fc970f feat: 完善WebDAV云同步、模板导入导出及数据层重构
0edb874 feat: 优化数据管理、导入导出及首页功能
```

## 提交信息规范（Conventional Commits）

| 前缀 | 用途 |
|------|------|
| `feat:` | 新功能 |
| `fix:` | Bug 修复 |
| `refactor:` | 代码重构 |
| `chore:` | 杂项/构建 |
| `docs:` | 文档 |
| `style:` | 格式调整 |
| `perf:` | 性能优化 |

**推荐格式：** `前缀: 简短描述`

```
feat: 完善备份功能、WebDAV同步及数据层优化
fix: 修复复习页面闪退问题
refactor: 重构 CardDao 查询逻辑
```

## 手动三步走（不用脚本时）

```powershell
cd D:\Ai_Project\cardnote_homo
git add -A
git commit -m "feat: 你的描述"
git push
```

## 注意事项

- **提交前** 检查 `git status` 确认没有意外文件被提交
- **敏感文件** 已在 `.gitignore` 中排除（`local.properties`、`node_modules` 等）
- **中文信息** 在 PowerShell 中正常支持，无需额外配置
- **分支** 当前在 `main` 分支，直接推送到 `origin/main`
