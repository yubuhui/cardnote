export interface MemoryRecord {
  id: number;           // 自增主键（仅本设备有效）
  uuid?: string;        // 全局唯一标识（跨设备同步用）
  cardId: number;       // 关联卡片 ID（本设备外键）
  cardUuid?: string;    // 关联卡片 UUID（跨设备同步用）
  result: number;       // 评分 0-3（忘记/困难/良好/容易）
  date: number;         // 记录时间戳（ms）
  duration: number;     // 该卡片停留时长（秒），默认 0
}
