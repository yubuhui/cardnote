import { Card } from '../model/Card';
import { Deck } from '../model/Deck';
import { MemoryRecord } from '../model/MemoryRecord';
import { CardViewModel } from './CardViewModel';
import { DeckDao } from '../data/DeckDao';
import { MemoryRecordDao, DailyDuration } from '../data/MemoryRecordDao';
import { Rating } from '../data/SM2Algorithm';
import { ReviewSettingsManager, ReviewSettings } from '../data/ReviewSettingsManager';
import { CardStatus } from '../model/CardTypeEnum';
import { util } from '@kit.ArkTS';

export interface TodayStats {
  forget: number;
  hard: number;
  good: number;
  easy: number;
}

/** 单条日详情记录 */
export interface DayDetailRecord {
  cardId: number;
  cardFront: string;
  result: number;
  resultLabel: string;
  resultColor: ResourceColor;
  durationSeconds: number;
}

/** 单条复习历史记录（含时间戳） */
export interface CardReviewRecord {
  date: number;
  result: number;
  resultLabel: string;
  resultColor: ResourceColor;
  durationSeconds: number;
}

/** 某一天的完整详情 */
export interface DayDetail {
  dateLabel: string;
  totalReviews: number;
  forgetCount: number;
  hardCount: number;
  goodCount: number;
  easyCount: number;
  totalDurationSeconds: number;
  records: DayDetailRecord[];
}

const RATING_LABELS: string[] = ['忘记', '困难', '良好', '容易'];

/** 根据评分获取对应的颜色资源引用（适配深色模式） */
function getRatingColor(rating: number): ResourceColor {
  switch (rating) {
    case 0: return $r('app.color.rating_forget');
    case 1: return $r('app.color.rating_hard');
    case 2: return $r('app.color.rating_good');
    case 3: return $r('app.color.rating_easy');
    default: return $r('app.color.text_secondary');
  }
}

/** 学习视图模型 */
export class StudyViewModel {
  private cardVm: CardViewModel;
  private recordDao: MemoryRecordDao;

  constructor() {
    this.cardVm = new CardViewModel();
    this.recordDao = new MemoryRecordDao();
  }

  // 获取待复习卡片（按牌组独立限额）
  async getDueCards(deckIds?: number[]): Promise<Card[]> {
    const settings: ReviewSettings = ReviewSettingsManager.getInstance().load();
    const deckDao: DeckDao = new DeckDao();

    // 确定要查询的牌组 ID 列表
    let targetDeckIds: number[];
    if (deckIds && deckIds.length > 0) {
      targetDeckIds = deckIds;
    } else {
      const allDecks: Deck[] = await deckDao.getAll();
      targetDeckIds = allDecks.map(d => d.id);
    }

    const result: Card[] = [];

    for (const deckId of targetDeckIds) {
      // 获取该牌组的有效限额：牌组自身设置 > 0 则用它，否则用全局设置
      const deck: Deck | null = await deckDao.getById(deckId);
      const newLimit: number = (deck && deck.dailyNewCards && deck.dailyNewCards > 0)
        ? deck.dailyNewCards : settings.dailyNewCards;
      const reviewLimit: number = (deck && deck.dailyReviewCards && deck.dailyReviewCards > 0)
        ? deck.dailyReviewCards : settings.dailyReviewCards;

      // 查询该牌组的待复习卡片
      let cards: Card[] = await this.cardVm.getDueCards([deckId]);

      // 过滤已掌握的卡片
      if (settings.skipMasteredCards) {
        cards = cards.filter(c => c.status !== CardStatus.mastered);
      }

      // 分离新卡和复习卡
      const newCards: Card[] = [];
      const reviewCards: Card[] = [];
      for (const c of cards) {
        if (c.status === CardStatus.unlearned) {
          newCards.push(c);
        } else {
          reviewCards.push(c);
        }
      }

      // 按该牌组独立限额截取
      const limitedNew: Card[] = newCards.slice(0, newLimit);
      const limitedReview: Card[] = reviewCards.slice(0, reviewLimit);

      // 新卡优先，复习卡在后
      result.push(...limitedNew, ...limitedReview);
    }

    return result;
  }

  // 根据 ID 获取牌组
  async getDeckById(id: number): Promise<Deck | null> {
    return this.cardVm.getDeckById(id);
  }

  // 记录评分（带事务性保护：Card 更新失败时回滚已写入的 MemoryRecord）
  async recordRating(cardId: number, rating: Rating, durationSeconds: number = 0): Promise<void> {
    // 先获取卡片信息（含 UUID），再记录学习结果
    const card: Card | null = await this.cardVm.getById(cardId);
    const record: MemoryRecord = {
      id: 0,
      cardId: cardId,
      cardUuid: card?.uuid,
      uuid: util.generateRandomUUID(true),
      result: rating,
      date: Date.now(),
      duration: durationSeconds,
    };
    await this.recordDao.insert(record);

    // 再更新卡片状态；若失败则回滚已插入的记录
    if (card) {
      try {
        await this.cardVm.handleRating(card, rating);
      } catch (err) {
        console.error('StudyViewModel: 卡片状态更新失败，回滚记忆记录', JSON.stringify(err));
        await this.recordDao.deleteLatestByCardId(cardId);
        return;
      }
    }
  }

  // 今日统计：各评分的次数
  async getTodayStats(): Promise<TodayStats> {
    const records: MemoryRecord[] = await this.recordDao.getTodayRecords();
    let forget: number = 0;
    let hard: number = 0;
    let good: number = 0;
    let easy: number = 0;
    for (const r of records) {
      if (r.result === Rating.forget) forget++;
      else if (r.result === Rating.hard) hard++;
      else if (r.result === Rating.good) good++;
      else if (r.result === Rating.easy) easy++;
    }
    return { forget, hard, good, easy };
  }

  // 获取指定月份的复习日期集合
  async getReviewDatesForMonth(year: number, month: number): Promise<Set<number>> {
    return await this.recordDao.getReviewDatesByMonth(year, month);
  }

  // 获取近 N 天每日学习时长
  async getDailyDurations(days: number): Promise<DailyDuration[]> {
    return await this.recordDao.getDailyDurations(days);
  }

  // 获取某一天的详细记录（含卡片信息）
  async getDayDetail(year: number, month: number, day: number): Promise<DayDetail> {
    const records: MemoryRecord[] = await this.recordDao.getRecordsByDate(year, month, day);
    const detailRecords: DayDetailRecord[] = [];
    let forgetCount: number = 0;
    let hardCount: number = 0;
    let goodCount: number = 0;
    let easyCount: number = 0;
    let totalDuration: number = 0;

    for (const r of records) {
      const card: Card | null = await this.cardVm.getById(r.cardId);
      // 跳过已删除的卡片，不显示其学习数据
      if (!card) {
        continue;
      }
      totalDuration += r.duration;
      if (r.result === Rating.forget) forgetCount++;
      else if (r.result === Rating.hard) hardCount++;
      else if (r.result === Rating.good) goodCount++;
      else if (r.result === Rating.easy) easyCount++;
      detailRecords.push({
        cardId: r.cardId,
        cardFront: card.front,
        result: r.result,
        resultLabel: RATING_LABELS[r.result] ?? '未知',
        resultColor: getRatingColor(r.result),
        durationSeconds: r.duration,
      });
    }

    return {
      dateLabel: `${year}/${month}/${day}`,
      totalReviews: detailRecords.length,
      forgetCount,
      hardCount,
      goodCount,
      easyCount,
      totalDurationSeconds: totalDuration,
      records: detailRecords,
    };
  }

  // 撤销评分：删除记忆记录 + 恢复卡片到评分前状态
  async undoRating(cardId: number, oldCard: Card): Promise<void> {
    await this.recordDao.deleteLatestByCardId(cardId);
    await this.cardVm.updateCard(oldCard);
  }

  /** 获取某张卡片的全部复习历史（按时间倒序） */
  async getCardReviewHistory(cardId: number): Promise<CardReviewRecord[]> {
    const records: MemoryRecord[] = await this.recordDao.getByCardId(cardId);
    const result: CardReviewRecord[] = [];
    for (const r of records) {
      result.push({
        date: r.date,
        result: r.result,
        resultLabel: RATING_LABELS[r.result] ?? '未知',
        resultColor: getRatingColor(r.result),
        durationSeconds: r.duration,
      });
    }
    return result;
  }

  /** 清除卡片学习数据：删除全部记忆记录 + 重置卡片到未学习状态 */
  async resetCardData(cardId: number): Promise<Card | null> {
    await this.recordDao.deleteByCardId(cardId);
    const card: Card | null = await this.cardVm.getById(cardId);
    if (card) {
      card.status = CardStatus.unlearned;
      card.interval = 0;
      card.repetitions = 0;
      card.easeFactor = 2.5;
      card.nextReviewTime = Date.now();
      card.updatedAt = Date.now();
      await this.cardVm.updateCard(card);
    }
    return card;
  }
}
