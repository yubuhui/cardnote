export interface Deck {
  id: number;           // 自增主键
  name: string;         // 牌组名称
  icon: string;         // 图标 emoji，如 '📘'
  color: string;        // 主题色，如 '#4A90D9'
  createdAt: number;    // 创建时间戳（ms）
  updatedAt: number;    // 更新时间戳（ms）
  dailyNewCards?: number;     // 每日新卡数量，0 表示使用全局默认值
  dailyReviewCards?: number;  // 每日复习卡数量，0 表示使用全局默认值
}
