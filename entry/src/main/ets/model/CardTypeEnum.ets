// 题型枚举
export enum CardType {
  essay = 0,       // 问答题
  choice = 1,      // 选择题
  fillBlank = 2,   // 填空题
}

// 卡片状态枚举
export enum CardStatus {
  unlearned = 0,   // 未背诵 — repetitions === 0
  reviewing = 1,   // 复习中 — 间隔 ≤ 32 天
  mastered = 2,    // 已掌握 — 间隔 > 32 天
}
