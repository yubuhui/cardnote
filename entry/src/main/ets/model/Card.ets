import { CardType, CardStatus } from './CardTypeEnum';

export { CardStatus };

export interface Card {
  id: number;               // 自增主键
  deckId: number;           // 所属牌组 ID（外键，默认 1）
  type: CardType;           // 题型
  front: string;            // 正面（问题题干）
  options: string[];        // 选项数组（仅选择题）
  correctAnswer: string;    // 正确答案
  displayOrder: number[];   // 显示顺序
  analysis: string;         // 解析（可选，空字符串表示无）
  status: CardStatus;       // 卡片状态
  easeFactor: number;       // 易用性因子，初始 2.5，范围 [1.3, 3.0]
  interval: number;         // 当前间隔（分钟），初始 0
  repetitions: number;      // 连续正确次数，初始 0
  nextReviewTime: number;   // 下次复习时间戳（ms）
  createdAt: number;        // 创建时间戳（ms）
  updatedAt: number;        // 更新时间戳（ms）
}
