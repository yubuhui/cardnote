export interface Deck {
  id: number;           // 自增主键（仅本设备有效）
  uuid?: string;        // 全局唯一标识（跨设备同步用）
  name: string;         // 牌组名称
  color: string;        // 主题色，如 '#4A90D9'
  createdAt: number;    // 创建时间戳（ms）
  updatedAt: number;    // 更新时间戳（ms）
  dailyNewCards?: number;     // 每日新卡数量，0 表示使用全局默认值
  dailyReviewCards?: number;  // 每日复习卡数量，0 表示使用全局默认值
  isDefault?: boolean;  // 是否为系统创建的默认牌组（不可删除）
}
