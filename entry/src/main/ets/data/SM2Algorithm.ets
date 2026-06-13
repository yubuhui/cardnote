import { Card } from '../model/Card';
import { CardStatus } from '../model/CardTypeEnum';

export interface UpdateResult {
  interval: number;
  repetitions: number;
  easeFactor: number;
  status: CardStatus;
}

export enum Rating {
  forget = 0,
  hard = 1,
  good = 2,
  easy = 3,
}

function getInitialInterval(rating: Rating): number {
  switch (rating) {
    case Rating.forget:
      return 1;
    case Rating.hard:
      return 10;
    case Rating.good:
      return 1440;
    case Rating.easy:
      return 5760;
  }
}

function getEfAdjust(rating: Rating): number {
  switch (rating) {
    case Rating.forget:
      return -0.4;
    case Rating.hard:
      return -0.1;
    case Rating.good:
      return 0.0;
    case Rating.easy:
      return 0.15;
  }
}

/** SM-2 算法实现（4 级评分 + 可调节倍率） */
export class SM2Algorithm {
  /**
   * 根据评分计算下一次复习参数
   * @param card 当前卡片
   * @param rating 评分 0-3
   * @param sm2Factor 倍率百分比，默认 250（即 250% = 2.5 倍系数）
   */
  static calculateNextReview(card: Card, rating: Rating, sm2Factor: number = 250): UpdateResult {
    const factor: number = sm2Factor / 100; // 百分比转小数

    // 首次学习
    if (card.repetitions === 0) {
      const result: UpdateResult = {
        interval: getInitialInterval(rating),
        repetitions: 1,
        easeFactor: card.easeFactor,
        status: CardStatus.reviewing,
      };
      return result;
    }

    // 非首次学习：使用可调节倍率
    let newInterval: number;
    if (card.repetitions === 1) {
      // 第 2 次
      newInterval = getInitialInterval(Rating.good) * card.easeFactor * factor;
    } else {
      // 第 3 次及以后
      newInterval = card.interval * card.easeFactor * factor;
    }

    // 调整 easeFactor
    const efAdjust = getEfAdjust(rating);
    const newEaseFactor = Math.max(1.3, Math.min(3.0, card.easeFactor + efAdjust));

    // 判断状态
    const newIntervalDays = newInterval / 1440;
    const newStatus = newIntervalDays > 32
      ? CardStatus.mastered
      : CardStatus.reviewing;

    const result: UpdateResult = {
      interval: Math.round(newInterval),
      repetitions: card.repetitions + 1,
      easeFactor: newEaseFactor,
      status: newStatus,
    };
    return result;
  }
}
