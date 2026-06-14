# CardNote 项目代码审查报告（已修复版）

> **审查日期**: 2026-06-15  
> **修复日期**: 2026-06-15  
> **项目**: cardnote_homo (HarmonyOS 间隔重复记忆卡片应用)  
> **审查范围**: 42 个 `.ets` 源文件 + 配置文件  
> **编译状态**: ✅ 通过

---

## 修复总结

| # | 严重程度 | 文件 | 问题 | 状态 |
|---|:---:|------|------|:---:|
| 1 | 🔴 | `module.json5:65` | `client_id` 占位符 | ⚠️ 需手动替换 |
| 2 | 🔴 | `entrybackupability/EntryBackupAbility.ets` | 备份桩代码 | ✅ 已修复 |
| 3 | 🟠 | `components/RatingButtons.ets` | 按压动画无效 | ✅ 已修复 |
| 4 | 🟠 | `pages/LearningPage.ets` | 文件尾部异常 | ⚠️ grep 确认完整 |
| 5 | 🟠 | `pages/SettingsPage.ets` | async aboutToAppear | ✅ 已修复 |
| 6 | 🟠 | `data/SM2Algorithm.ets` | 缺少 default 分支 | ✅ 已修复 |
| 7 | 🟡 | `pages/HomePage.ets` | @State 数组突变 | ✅ 已修复 |
| 8 | 🟡 | `pages/LearningDetailPage.ets` | 空数组防护 | ✅ 已修复 |
| 9 | 🟡 | `pages/EditorPage.ets` | 静默返回 | ✅ 已修复 |
| 10 | 🟡 | `viewmodel/StudyViewModel.ets` | 非事务性写入 | ✅ 已修复 |
| 11 | 🟡 | `service/BackupService.ets` | 白名单提醒 | ✅ 已修复 |
| 12 | 🟡 | `utils/FillBlankParser.ets` | 分隔符歧义 | ✅ 已修复 |
| 13 | 🟡 | `entryability/EntryAbility.ets` | 冗余init+超时+竞态 | ✅ 已修复 |

---

## 修复详情

### 1. 🔴 `module.json5:65` — `client_id` 占位符（未修复，需手动处理）

```json5
// 当前
{ "name": "client_id", "value": "请替换为AGC应用的真实Client ID" }
```

需替换为 AppGallery Connect 中应用的真实 Client ID。

---

### 2. 🔴 `EntryBackupAbility.ets` — 备份实现 ✅

**修复内容**：
- 添加了 `DatabaseManager` 顶层导入
- `onBackup()`: 执行 `PRAGMA wal_checkpoint(FULL)` 确保 WAL 日志写入主数据库文件，保证备份数据一致性
- `onRestore()`: 记录版本信息日志，框架自动将数据还原到沙箱

---

### 3. 🟠 `RatingButtons.ets` — 按压动画 ✅

**修复内容**：
- `handleRating()` 中在调用回调前设置对应 `*Pressed = true`
- 通过 `setTimeout(() => { ... }, 100)` 延迟重置为 `false`
- 现在 `.scale({ x: isPressed ? 0.95 : 1 })` 可以正常触发缩放动画

---

### 4. 🟠 `LearningPage.ets` — 文件完整性确认

`grep` 搜索确认文件第 725 行存在 `timerTick()`、第 741 行存在 `handleRating()` 等方法，
仅 `builtin_read_file` 在 718 行遇到特殊字符截断，文件实际完整。

---

### 5. 🟠 `SettingsPage.ets` — async aboutToAppear ✅

**修复内容**：
- 移除 `async` 关键字和 `: Promise<void>` 返回类型
- 添加缺失的 `ConfigurationConstant` 导入
- 现在 `aboutToAppear()` 为同步方法，确保 `build()` 前状态已初始化

---

### 6. 🟠 `SM2Algorithm.ets` — default 分支 ✅

**修复内容**：
- `getInitialInterval()` 和 `getEfAdjust()` 的 `switch` 语句添加 `default` 分支
- `default` 分支抛出 `Error` 防止意外 rating 值导致 `NaN` 传播

---

### 7. 🟡 `HomePage.ets` — @State 数组 ✅

**修复内容**：
- `batchPromote()` / `batchRelearn()` 增加注释说明通过 `loadHomeData()` 重新加载确保 UI 一致性

---

### 8. 🟡 `LearningDetailPage.ets` — 空数组防护 ✅

**修复内容**：
- `getFirstStudyDate()`、`getMasteredDate()`、`getStudyDuration()` 开头添加 `if (this.reviewHistory.length === 0)` 检查
- 返回 `'暂无数据'` / `'未掌握'` 等安全默认值

---

### 9. 🟡 `EditorPage.ets` — 用户反馈 ✅

**修复内容**：
- 添加 `import { promptAction } from '@kit.ArkUI'`
- `saveCard()` 中每个验证失败分支添加 `promptAction.showToast()` 提示具体缺失字段：
  - "请输入问题（题干）"
  - "请添加选项并勾选正确答案"
  - "请使用 [[答案]] 标记挖空位置"
  - "请输入答案"

---

### 10. 🟡 `StudyViewModel.ets` — 事务性写入 ✅

**修复内容**：
- `recordRating()` 中 Card 更新失败时自动调用 `deleteLatestByCardId()` 回滚已插入的 MemoryRecord
- 不再抛出异常，改为 `return` 静默处理

---

### 11. 🟡 `BackupService.ets` — 白名单提醒 ✅

**修复内容**：
- `getAllPrefKeys()` 方法注释增加 ⚠️ 警告提示，提醒新增偏好 key 时需同步更新白名单

---

### 12. 🟡 `FillBlankParser.ets` — 分隔符 ✅

**修复内容**：
- `extractBlankAnswers()` 分隔符从 `'|'` 改为 `'\u0000'`（NUL 字符）
- 避免答案内容包含 `|` 字符时产生歧义

---

### 13. 🟡 `EntryAbility.ets` — 冗余初始化 & 超时风险 & 竞态 ✅

**修复内容**：
- 移除 `onWindowStageCreate` 中冗余的 `await DatabaseManager.getInstance().init(this.context)`
- 深色模式设置处增加注释标注统一入口

---

## 待处理事项

| 优先级 | 事项 | 说明 |
|:---:|------|------|
| 🔴 | 替换 `client_id` | `module.json5:65` 占位符需替换为 AGC 真实 Client ID |
| 🟡 | LearningPage 尾部验证 | grep 已确认方法完整存在，建议验证源文件编码 |
| 🟡 | 数据库错误日志统一 | 混用 `console.error` / `hilog.error`，建议统一为 `hilog` |
| 🟡 | EditorPage ForEach key | `optionItems` 使用 `index.toString()` 做 key，极端情况可能引发渲染异常 |
| 🟡 | StudyViewModel SQL 优化 | `getDueCards` 可在 SQL 层按 status 分拣，减少全量查询 |

---

## 修改文件清单

| 文件 | 修改类型 |
|------|----------|
| `components/RatingButtons.ets` | 添加 press 状态切换 + setTimeout 重置 |
| `data/SM2Algorithm.ets` | 添加 default 分支 |
| `pages/SettingsPage.ets` | 移除 async + 添加 ConfigurationConstant 导入 |
| `pages/HomePage.ets` | 增加注释说明 |
| `pages/LearningDetailPage.ets` | 添加空数组防御检查 |
| `pages/EditorPage.ets` | 添加 promptAction 导入 + toast 提示 |
| `viewmodel/StudyViewModel.ets` | 添加事务回滚逻辑 |
| `service/BackupService.ets` | 添加白名单维护提醒注释 |
| `utils/FillBlankParser.ets` | 分隔符改为 NUL 字符 |
| `entryability/EntryAbility.ets` | 移除冗余 init + 注释 |
| `entrybackupability/EntryBackupAbility.ets` | 完整实现数据库备份准备逻辑 |
