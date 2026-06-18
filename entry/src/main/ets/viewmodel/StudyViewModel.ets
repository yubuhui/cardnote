import { Card } from '../model/Card';
import { Deck } from '../model/Deck';
import { MemoryRecord } from '../model/MemoryRecord';
import { CardViewModel } from './CardViewModel';
import { DeckDao } from '../data/DeckDao';
import { CardDao } from '../data/CardDao';
import { MemoryRecordDao, DailyDuration, RatingDistribution, CardDifficultyRow, DailyAccuracyRow } from '../data/MemoryRecordDao';
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

export interface OverviewStats {
  totalCards: number;
  masteredCards: number;
  dueToday: number;
  totalReviews: number;
}

export { RatingDistribution };

export interface StreakInfo {
  currentStreak: number;
  longestStreak: number;
}

export interface MasteryProgress {
  unlearned: number;
  reviewing: number;
  mastered: number;
  total: number;
}

export interface DailyAccuracy {
  dateLabel: string;
  accuracy: number;
  totalReviews: number;
}

export interface DifficultCard {
  cardId: number;
  cardFront: string;
  forgetCount: number;
  totalReviews: number;
  forgetRate: number;
}

export interface DueForecast {
  day1: number;
  day3: number;
  day7: number;
}

export interface DurationStats {
  totalHours: number;
  weekHours: number;
  monthHours: number;
}

const RATING_LABELS: string[] = ['忘记', '困难', '良好', '容易'];

/** 根据评分获取对应的颜色资源引用（适配深色模式） */
function getRatingColor(rating: number): ResourceColor {
  switch (rating) {
    case 0: return $r('app.color.danger');
    case 1: return $r('app.color.warning');
    case 2: return $r('app.color.success');
    case 3: return $r('app.color.success');
    default: return $r('app.color.text_secondary');
  }
}

/** 学习视图模型 */
export class StudyViewModel {
  private cardVm: CardViewModel;
  private recordDao: MemoryRecordDao;
  private cardDao: CardDao;

  constructor() {
    this.cardVm = new CardViewModel();
    this.recordDao = new MemoryRecordDao();
    this.cardDao = new CardDao();
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

  // 根据 ID 获取卡片
  async getCardById(id: number): Promise<Card | null> {
    return this.cardVm.getById(id);
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

  async getOverviewStats(): Promise<OverviewStats> {
    const totalCards: number = await this.cardDao.count();
    const masteredCards: number = await this.cardDao.countByStatus(CardStatus.mastered);
    const dueCards: Card[] = await this.cardDao.getDueCards();
    const totalReviews: number = await this.recordDao.getTotalCount();
    const stats: OverviewStats = {
      totalCards: totalCards,
      masteredCards: masteredCards,
      dueToday: dueCards.length,
      totalReviews: totalReviews,
    };
    return stats;
  }

  async getRatingDistribution(): Promise<RatingDistribution> {
    return await this.recordDao.getRatingDistribution();
  }

  async getStreakInfo(): Promise<StreakInfo> {
    const dates: number[] = await this.recordDao.getAllReviewDates();
    const daySet: Set<string> = new Set<string>();
    for (let i: number = 0; i < dates.length; i++) {
      const d: Date = new Date(dates[i]);
      const key: string = d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
      daySet.add(key);
    }

    let currentStreak: number = 0;
    const today: Date = new Date();
    for (let i: number = 0; true; i++) {
      const check: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i);
      const key: string = check.getFullYear() + '-' + (check.getMonth() + 1) + '-' + check.getDate();
      if (daySet.has(key)) {
        currentStreak++;
      } else {
        break;
      }
    }

    let longestStreak: number = 0;
    if (dates.length > 0) {
      let run: number = 1;
      const firstD: Date = new Date(dates[0]);
      let prevDay: Date = new Date(firstD.getFullYear(), firstD.getMonth(), firstD.getDate());
      for (let i: number = 1; i < dates.length; i++) {
        const d: Date = new Date(dates[i]);
        const curDay: Date = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const diffMs: number = curDay.getTime() - prevDay.getTime();
        const diffDays: number = Math.floor(diffMs / 86400000);
        if (diffDays === 1) {
          run++;
        } else if (diffDays > 1) {
          if (run > longestStreak) {
            longestStreak = run;
          }
          run = 1;
        }
        prevDay = curDay;
      }
      if (run > longestStreak) {
        longestStreak = run;
      }
    }

    const info: StreakInfo = { currentStreak: currentStreak, longestStreak: longestStreak };
    return info;
  }

  async getMasteryProgress(): Promise<MasteryProgress> {
    const unlearned: number = await this.cardDao.countByStatus(CardStatus.unlearned);
    const reviewing: number = await this.cardDao.countByStatus(CardStatus.reviewing);
    const mastered: number = await this.cardDao.countByStatus(CardStatus.mastered);
    const total: number = unlearned + reviewing + mastered;
    const progress: MasteryProgress = {
      unlearned: unlearned,
      reviewing: reviewing,
      mastered: mastered,
      total: total,
    };
    return progress;
  }

  async getDifficultCards(limit: number): Promise<DifficultCard[]> {
    const rows: CardDifficultyRow[] = await this.recordDao.getCardsWithDifficulty();
    const result: DifficultCard[] = [];
    const count: number = Math.min(limit, rows.length);
    for (let i: number = 0; i < count; i++) {
      const row: CardDifficultyRow = rows[i];
      const card: DifficultCard = {
        cardId: row.cardId,
        cardFront: row.cardFront,
        forgetCount: row.forgetCount,
        totalReviews: row.totalReviews,
        forgetRate: row.totalReviews > 0 ? row.forgetCount / row.totalReviews : 0,
      };
      result.push(card);
    }
    return result;
  }

  async getDailyAccuracyTrend(days: number): Promise<DailyAccuracy[]> {
    const rows: DailyAccuracyRow[] = await this.recordDao.getDailyAccuracyStats(days);
    const result: DailyAccuracy[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const row: DailyAccuracyRow = rows[i];
      const accuracy: number = row.totalCount > 0 ? Math.round((row.goodCount / row.totalCount) * 100) : 0;
      const acc: DailyAccuracy = {
        dateLabel: row.dateLabel,
        accuracy: accuracy,
        totalReviews: row.totalCount,
      };
      result.push(acc);
    }
    return result;
  }

  async getDueForecast(): Promise<DueForecast> {
    const day1: number = await this.cardDao.countDueWithinDays(1);
    const day3: number = await this.cardDao.countDueWithinDays(3);
    const day7: number = await this.cardDao.countDueWithinDays(7);
    const forecast: DueForecast = { day1: day1, day3: day3, day7: day7 };
    return forecast;
  }

  // ===== 牌组操作 =====
  async getAllDecks(): Promise<Deck[]> {
    return this.cardVm.getAllDecks();
  }

  async getDurationStats(): Promise<DurationStats> {
    const totalSeconds: number = await this.recordDao.getTotalDuration();
    const weekSeconds: number = await this.recordDao.getWeekDuration();
    const monthSeconds: number = await this.recordDao.getMonthDuration();
    const stats: DurationStats = {
      totalHours: Math.round(totalSeconds / 360 * 10) / 100,
      weekHours: Math.round(weekSeconds / 360 * 10) / 100,
      monthHours: Math.round(monthSeconds / 360 * 10) / 100,
    };
    return stats;
  }

  async getDurationStatsByDeck(deckId: number): Promise<DurationStats> {
    const totalSeconds: number = await this.recordDao.getTotalDurationByDeck(deckId);
    const weekSeconds: number = await this.recordDao.getWeekDurationByDeck(deckId);
    const monthSeconds: number = await this.recordDao.getMonthDurationByDeck(deckId);
    const stats: DurationStats = {
      totalHours: Math.round(totalSeconds / 360 * 10) / 100,
      weekHours: Math.round(weekSeconds / 360 * 10) / 100,
      monthHours: Math.round(monthSeconds / 360 * 10) / 100,
    };
    return stats;
  }

  async getOverviewStatsByDeck(deckId: number): Promise<OverviewStats> {
    const totalCards: number = await this.cardDao.countByDeckId(deckId);
    const masteredCards: number = await this.cardDao.countByStatusAndDeck(CardStatus.mastered, deckId);
    const dueCards: Card[] = await this.cardDao.getDueCards([deckId]);
    const totalReviews: number = await this.recordDao.getTotalCountByDeck(deckId);
    const stats: OverviewStats = {
      totalCards: totalCards,
      masteredCards: masteredCards,
      dueToday: dueCards.length,
      totalReviews: totalReviews,
    };
    return stats;
  }

  async getRatingDistributionByDeck(deckId: number): Promise<RatingDistribution> {
    return await this.recordDao.getRatingDistributionByDeck(deckId);
  }

  async getMasteryProgressByDeck(deckId: number): Promise<MasteryProgress> {
    const unlearned: number = await this.cardDao.countByStatusAndDeck(CardStatus.unlearned, deckId);
    const reviewing: number = await this.cardDao.countByStatusAndDeck(CardStatus.reviewing, deckId);
    const mastered: number = await this.cardDao.countByStatusAndDeck(CardStatus.mastered, deckId);
    const total: number = unlearned + reviewing + mastered;
    const progress: MasteryProgress = {
      unlearned: unlearned,
      reviewing: reviewing,
      mastered: mastered,
      total: total,
    };
    return progress;
  }

  async getDifficultCardsByDeck(deckId: number, limit: number): Promise<DifficultCard[]> {
    const rows: CardDifficultyRow[] = await this.recordDao.getCardsWithDifficultyByDeck(deckId);
    const result: DifficultCard[] = [];
    const count: number = Math.min(limit, rows.length);
    for (let i: number = 0; i < count; i++) {
      const row: CardDifficultyRow = rows[i];
      const card: DifficultCard = {
        cardId: row.cardId,
        cardFront: row.cardFront,
        forgetCount: row.forgetCount,
        totalReviews: row.totalReviews,
        forgetRate: row.totalReviews > 0 ? row.forgetCount / row.totalReviews : 0,
      };
      result.push(card);
    }
    return result;
  }

  async getDailyAccuracyTrendByDeck(days: number, deckId: number): Promise<DailyAccuracy[]> {
    const rows: DailyAccuracyRow[] = await this.recordDao.getDailyAccuracyStatsByDeck(days, deckId);
    const result: DailyAccuracy[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const row: DailyAccuracyRow = rows[i];
      const accuracy: number = row.totalCount > 0 ? Math.round((row.goodCount / row.totalCount) * 100) : 0;
      const acc: DailyAccuracy = {
        dateLabel: row.dateLabel,
        accuracy: accuracy,
        totalReviews: row.totalCount,
      };
      result.push(acc);
    }
    return result;
  }

  async getDailyDurationsByDeck(days: number, deckId: number): Promise<DailyDuration[]> {
    return await this.recordDao.getDailyDurationsByDeck(days, deckId);
  }

  async getDueForecastByDeck(deckId: number): Promise<DueForecast> {
    const day1: number = await this.cardDao.countDueWithinDaysByDeck(1, deckId);
    const day3: number = await this.cardDao.countDueWithinDaysByDeck(3, deckId);
    const day7: number = await this.cardDao.countDueWithinDaysByDeck(7, deckId);
    const forecast: DueForecast = { day1: day1, day3: day3, day7: day7 };
    return forecast;
  }

  async getAllDifficultCards(): Promise<DifficultCard[]> {
    const rows: CardDifficultyRow[] = await this.recordDao.getCardsWithDifficulty();
    const result: DifficultCard[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const row: CardDifficultyRow = rows[i];
      const card: DifficultCard = {
        cardId: row.cardId,
        cardFront: row.cardFront,
        forgetCount: row.forgetCount,
        totalReviews: row.totalReviews,
        forgetRate: row.totalReviews > 0 ? row.forgetCount / row.totalReviews : 0,
      };
      result.push(card);
    }
    return result;
  }

  async getAllDifficultCardsByDeck(deckId: number): Promise<DifficultCard[]> {
    const rows: CardDifficultyRow[] = await this.recordDao.getCardsWithDifficultyByDeck(deckId);
    const result: DifficultCard[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const row: CardDifficultyRow = rows[i];
      const card: DifficultCard = {
        cardId: row.cardId,
        cardFront: row.cardFront,
        forgetCount: row.forgetCount,
        totalReviews: row.totalReviews,
        forgetRate: row.totalReviews > 0 ? row.forgetCount / row.totalReviews : 0,
      };
      result.push(card);
    }
    return result;
  }

  async getDayDetailByDeck(year: number, month: number, day: number, deckId: number): Promise<DayDetail> {
    const records: MemoryRecord[] = await this.recordDao.getRecordsByDateAndDeck(year, month, day, deckId);
    const detailRecords: DayDetailRecord[] = [];
    let forgetCount: number = 0;
    let hardCount: number = 0;
    let goodCount: number = 0;
    let easyCount: number = 0;
    let totalDuration: number = 0;

    for (const r of records) {
      const card: Card | null = await this.cardVm.getById(r.cardId);
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
      dateLabel: year + '/' + month + '/' + day,
      totalReviews: detailRecords.length,
      forgetCount,
      hardCount,
      goodCount,
      easyCount,
      totalDurationSeconds: totalDuration,
      records: detailRecords,
    };
  }

  async getAllTodayCards(): Promise<DayDetailRecord[]> {
    const today: Date = new Date();
    const detail: DayDetail = await this.getDayDetail(
      today.getFullYear(), today.getMonth() + 1, today.getDate()
    );
    return detail.records;
  }

  async getAllTodayCardsByDeck(deckId: number): Promise<DayDetailRecord[]> {
    const today: Date = new Date();
    const detail: DayDetail = await this.getDayDetailByDeck(
      today.getFullYear(), today.getMonth() + 1, today.getDate(), deckId
    );
    return detail.records;
  }

  async getTodayStatsByDeck(deckId: number): Promise<TodayStats> {
    const records: MemoryRecord[] = await this.recordDao.getTodayRecordsByDeck(deckId);
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

  async getReviewDatesForMonthByDeck(year: number, month: number, deckId: number): Promise<Set<number>> {
    return await this.recordDao.getReviewDatesByMonthByDeck(year, month, deckId);
  }
}
