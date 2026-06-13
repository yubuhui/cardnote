import { Card } from '../model/Card';
import { Deck } from '../model/Deck';
import { MemoryRecord } from '../model/MemoryRecord';
import { CardViewModel } from './CardViewModel';
import { DeckDao } from '../data/DeckDao';
import { MemoryRecordDao, DailyDuration } from '../data/MemoryRecordDao';
import { Rating } from '../data/SM2Algorithm';
import { ReviewSettingsManager, ReviewSettings } from '../data/ReviewSettingsManager';
import { CardStatus } from '../model/CardTypeEnum';

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
  resultColor: string;
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
const RATING_COLORS: string[] = ['#E74C3C', '#F39C12', '#2ECC71', '#27AE60'];

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

  // 记录评分
  async recordRating(cardId: number, rating: Rating, durationSeconds: number = 0): Promise<void> {
    // 先记录学习结果
    const record: MemoryRecord = {
      id: 0,
      cardId: cardId,
      result: rating,
      date: Date.now(),
      duration: durationSeconds,
    };
    await this.recordDao.insert(record);

    // 再更新卡片
    const card: Card | null = await this.cardVm.getById(cardId);
    if (card) {
      await this.cardVm.handleRating(card, rating);
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
      totalDuration += r.duration;
      if (r.result === Rating.forget) forgetCount++;
      else if (r.result === Rating.hard) hardCount++;
      else if (r.result === Rating.good) goodCount++;
      else if (r.result === Rating.easy) easyCount++;
      detailRecords.push({
        cardId: r.cardId,
        cardFront: card ? card.front : '(已删除)',
        result: r.result,
        resultLabel: RATING_LABELS[r.result] ?? '未知',
        resultColor: RATING_COLORS[r.result] ?? '#999',
        durationSeconds: r.duration,
      });
    }

    return {
      dateLabel: `${year}/${month}/${day}`,
      totalReviews: records.length,
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
}
