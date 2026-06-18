import relationalStore from '@ohos.data.relationalStore';
import { DatabaseManager } from './DatabaseManager';
import { MemoryRecord } from '../model/MemoryRecord';

/** 每日学习时长数据结构 */
export interface DailyDuration {
  dateLabel: string;
  totalSeconds: number;
}

/** 将 MemoryRecord 对象转为 ColumnValueMap */
function recordToValues(record: MemoryRecord): relationalStore.ValuesBucket {
  const values: relationalStore.ValuesBucket = {
    card_id: record.cardId,
    result: record.result,
    date: record.date,
    duration: record.duration,
  };
  if (record.uuid) {
    values['uuid'] = record.uuid;
  }
  if (record.cardUuid) {
    values['card_uuid'] = record.cardUuid;
  }
  return values;
}

/** 将 ResultSet 行转为 MemoryRecord 对象 */
function rowToRecord(resultSet: relationalStore.ResultSet): MemoryRecord {
  const record: MemoryRecord = {
    id: resultSet.getLong(resultSet.getColumnIndex('id')),
    cardId: resultSet.getLong(resultSet.getColumnIndex('card_id')),
    result: resultSet.getLong(resultSet.getColumnIndex('result')),
    date: resultSet.getLong(resultSet.getColumnIndex('date')),
    duration: resultSet.getLong(resultSet.getColumnIndex('duration')),
  };
  const uuidIdx: number = resultSet.getColumnIndex('uuid');
  if (uuidIdx >= 0) {
    record.uuid = resultSet.getString(uuidIdx);
  }
  const cardUuidIdx: number = resultSet.getColumnIndex('card_uuid');
  if (cardUuidIdx >= 0) {
    record.cardUuid = resultSet.getString(cardUuidIdx);
  }
  return record;
}

export class MemoryRecordDao {
  private _db: relationalStore.RdbStore | null = null;

  // 懒加载：构造时不访问数据库，避免在组件字段初始化阶段因 DB 未就绪而崩溃
  private get db(): relationalStore.RdbStore {
    if (!this._db) {
      this._db = DatabaseManager.getInstance().getStore();
    }
    return this._db;
  }

  /** 插入记录 */
  async insert(record: MemoryRecord): Promise<number> {
    const values: relationalStore.ValuesBucket = recordToValues(record);
    const result: number = await this.db.insert('memory_record', values);
    return result;
  }

  /** 按卡片 ID 查询所有记录 */
  async getByCardId(cardId: number): Promise<MemoryRecord[]> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('memory_record');
    predicates.equalTo('card_id', cardId).orderByDesc('date');
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    const records: MemoryRecord[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        records.push(rowToRecord(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return records;
  }

  /** 根据 UUID 查询（跨设备同步用） */
  async getByUuid(uuid: string): Promise<MemoryRecord | null> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('memory_record');
    predicates.equalTo('uuid', uuid);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    if (resultSet.rowCount === 0) {
      resultSet.close();
      return null;
    }
    resultSet.goToFirstRow();
    const record: MemoryRecord = rowToRecord(resultSet);
    resultSet.close();
    return record;
  }

  /** 查询所有记忆记录（备份用） */
  async getAll(): Promise<MemoryRecord[]> {
    const resultSet: relationalStore.ResultSet = await this.db.query(
      new relationalStore.RdbPredicates('memory_record').orderByDesc('date')
    );
    const records: MemoryRecord[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        records.push(rowToRecord(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return records;
  }

  /** 按卡片 UUID 查询所有记录（跨设备同步用） */
  async getByCardUuid(cardUuid: string): Promise<MemoryRecord[]> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('memory_record');
    predicates.equalTo('card_uuid', cardUuid).orderByDesc('date');
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    const records: MemoryRecord[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        records.push(rowToRecord(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return records;
  }

  /** 查询今日记录（排除已删除卡片的记录） */
  async getTodayRecords(): Promise<MemoryRecord[]> {
    const now: Date = new Date();
    const startOfDay: number = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const endOfDay: number = startOfDay + 86400000;

    // 使用 JOIN 确保只统计仍存在的卡片的记录
    const sql: string =
      `SELECT mr.id, mr.card_id, mr.result, mr.date, mr.duration FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ?`;
    const bindArgs: relationalStore.ValueType[] = [startOfDay, endOfDay];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    const records: MemoryRecord[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        records.push(rowToRecord(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return records;
  }

  /**
   * 查询指定月份中有复习记录的所有日期（返回 day-of-month 集合）
   * 排除已删除卡片的记录
   * @param year 四位年份，如 2026
   * @param month 月份 1-12
   */
  async getReviewDatesByMonth(year: number, month: number): Promise<Set<number>> {
    const startDate: Date = new Date(year, month - 1, 1);
    const endDate: Date = new Date(year, month, 1);
    const startMs: number = startDate.getTime();
    const endMs: number = endDate.getTime();

    // 使用 JOIN 确保只统计仍存在的卡片的记录
    const sql: string =
      `SELECT mr.date FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ?`;
    const bindArgs: relationalStore.ValueType[] = [startMs, endMs];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    const dates: Set<number> = new Set();

    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const timestamp: number = resultSet.getLong(resultSet.getColumnIndex('date'));
        const recordDate: Date = new Date(timestamp);
        dates.add(recordDate.getDate());
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return dates;
  }

  /**
   * 查询近 N 天每天的学习总时长（秒）→ 用于柱状图
   * 返回按日期升序排列的 { dateLabel, totalSeconds } 数组
   * 通过 INNER JOIN card 表排除已删除卡片的记录
   */
  async getDailyDurations(daysBack: number): Promise<DailyDuration[]> {
    const today: Date = new Date();
    const startDate: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysBack + 1);
    const startMs: number = startDate.getTime();
    const endMs: number = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1).getTime();

    // 使用 JOIN 确保只统计仍存在的卡片的记录
    const sql: string =
      `SELECT mr.date, mr.duration FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ?`;
    const bindArgs: relationalStore.ValueType[] = [startMs, endMs];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);

    // 按日期汇总
    const dayMap: Map<string, number> = new Map();
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const timestamp: number = resultSet.getLong(resultSet.getColumnIndex('date'));
        const duration: number = resultSet.getLong(resultSet.getColumnIndex('duration'));
        const recordDate: Date = new Date(timestamp);
        const key: string = `${recordDate.getMonth() + 1}/${recordDate.getDate()}`;
        dayMap.set(key, (dayMap.get(key) || 0) + duration);
      } while (resultSet.goToNextRow());
    }
    resultSet.close();

    // 补齐缺失的日期（保证连续 7 天）
    const result: DailyDuration[] = [];
    for (let i: number = 0; i < daysBack; i++) {
      const d: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysBack + 1 + i);
      const key: string = `${d.getMonth() + 1}/${d.getDate()}`;
      result.push({
        dateLabel: key,
        totalSeconds: dayMap.get(key) || 0,
      } as DailyDuration);
    }
    return result;
  }

  /** 删除最新一条记录（撤销用） */
  async deleteLatestByCardId(cardId: number): Promise<void> {
    const records: MemoryRecord[] = await this.getByCardId(cardId);
    if (records.length > 0) {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('memory_record');
      predicates.equalTo('id', records[0].id);
      await this.db.delete(predicates);
    }
  }

  /** 删除指定卡片的所有记忆记录 */
  async deleteByCardId(cardId: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('memory_record');
    predicates.equalTo('card_id', cardId);
    await this.db.delete(predicates);
  }

  /** 根据卡片 UUID 删除所有记忆记录（跨设备同步用） */
  async deleteByCardUuid(cardUuid: string): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('memory_record');
    predicates.equalTo('card_uuid', cardUuid);
    await this.db.delete(predicates);
  }

  /** 根据 UUID 删除单条记忆记录（跨设备同步用） */
  async deleteByUuid(uuid: string): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('memory_record');
    predicates.equalTo('uuid', uuid);
    await this.db.delete(predicates);
  }

  /** 查询指定日期的所有记录（排除已删除卡片的记录） */
  async getRecordsByDate(year: number, month: number, day: number): Promise<MemoryRecord[]> {
    const startOfDay: number = new Date(year, month - 1, day).getTime();
    const endOfDay: number = startOfDay + 86400000;

    // 使用 JOIN 确保只统计仍存在的卡片的记录
    const sql: string =
      `SELECT mr.id, mr.card_id, mr.result, mr.date, mr.duration FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ? ORDER BY mr.date DESC`;
    const bindArgs: relationalStore.ValueType[] = [startOfDay, endOfDay];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    const records: MemoryRecord[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        records.push(rowToRecord(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return records;
  }

  /** 查询历史总复习次数（排除已删除卡片的记录） */
  async getTotalCount(): Promise<number> {
    const sql: string = `SELECT COUNT(*) as cnt FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id`;
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, []);
    let count: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
    }
    resultSet.close();
    return count;
  }

  /** 查询全历史评分分布（排除已删除卡片的记录） */
  async getRatingDistribution(): Promise<RatingDistribution> {
    const sql: string =
      `SELECT mr.result, COUNT(*) as cnt FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id GROUP BY mr.result`;
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, []);
    let forget: number = 0;
    let hard: number = 0;
    let good: number = 0;
    let easy: number = 0;
    let total: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const result: number = resultSet.getLong(resultSet.getColumnIndex('result'));
        const cnt: number = resultSet.getLong(resultSet.getColumnIndex('cnt'));
        if (result === 0) forget = cnt;
        else if (result === 1) hard = cnt;
        else if (result === 2) good = cnt;
        else if (result === 3) easy = cnt;
        total += cnt;
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    const dist: RatingDistribution = { forget, hard, good, easy, total };
    return dist;
  }

  /** 查询所有有复习记录的日期时间戳（升序，排除已删除卡片），用于计算连续学习天数 */
  async getAllReviewDates(): Promise<number[]> {
    const sql: string =
      `SELECT DISTINCT mr.date FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id ORDER BY mr.date ASC`;
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, []);
    const dates: number[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        dates.push(resultSet.getLong(resultSet.getColumnIndex('date')));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return dates;
  }

  /** 查询各卡片的难度统计（至少有 3 条记录），按忘记率降序排列 */
  async getCardsWithDifficulty(): Promise<CardDifficultyRow[]> {
    const sql: string =
      `SELECT mr.card_id, c.front, SUM(CASE WHEN mr.result = 0 THEN 1 ELSE 0 END) as forgets, COUNT(*) as total FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id GROUP BY mr.card_id HAVING total >= 3 ORDER BY forgets * 1.0 / total DESC`;
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, []);
    const rows: CardDifficultyRow[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const row: CardDifficultyRow = {
          cardId: resultSet.getLong(resultSet.getColumnIndex('card_id')),
          cardFront: resultSet.getString(resultSet.getColumnIndex('front')),
          forgetCount: resultSet.getLong(resultSet.getColumnIndex('forgets')),
          totalReviews: resultSet.getLong(resultSet.getColumnIndex('total')),
        };
        rows.push(row);
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return rows;
  }

  /** 查询指定天数范围内每天的 good+easy 次数和总复习次数（用于计算正确率趋势） */
  async getDailyAccuracyStats(daysBack: number): Promise<DailyAccuracyRow[]> {
    const today: Date = new Date();
    const startDate: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysBack + 1);
    const startMs: number = startDate.getTime();
    const endMs: number = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1).getTime();

    const sql: string =
      `SELECT mr.date, mr.result FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ? ORDER BY mr.date ASC`;
    const bindArgs: relationalStore.ValueType[] = [startMs, endMs];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);

    const dayMap: Map<string, DayAccuracy> = new Map();
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const timestamp: number = resultSet.getLong(resultSet.getColumnIndex('date'));
        const result: number = resultSet.getLong(resultSet.getColumnIndex('result'));
        const recordDate: Date = new Date(timestamp);
        const key: string = recordDate.getMonth() + 1 + '/' + recordDate.getDate();
        const acc: DayAccuracy = dayMap.get(key) ?? { goodCount: 0, totalCount: 0 };
        acc.totalCount++;
        if (result === 2 || result === 3) {
          acc.goodCount++;
        }
        dayMap.set(key, acc);
      } while (resultSet.goToNextRow());
    }
    resultSet.close();

    const result: DailyAccuracyRow[] = [];
    for (let i: number = 0; i < daysBack; i++) {
      const d: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysBack + 1 + i);
      const key: string = d.getMonth() + 1 + '/' + d.getDate();
      const acc: DayAccuracy = dayMap.get(key) ?? { goodCount: 0, totalCount: 0 };
      const row: DailyAccuracyRow = {
        dateLabel: key,
        goodCount: acc.goodCount,
        totalCount: acc.totalCount,
      };
      result.push(row);
    }
    return result;
  }

  /** 查询历史总学习时长（秒）（排除已删除卡片） */
  async getTotalDuration(): Promise<number> {
    const sql: string = `SELECT COALESCE(SUM(mr.duration), 0) as total FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id`;
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, []);
    let total: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      total = resultSet.getLong(resultSet.getColumnIndex('total'));
    }
    resultSet.close();
    return total;
  }

  /** 查询本周学习总时长（秒），周一 0:00 至今 */
  async getWeekDuration(): Promise<number> {
    const today: Date = new Date();
    const dayOfWeek: number = today.getDay();
    const mondayOffset: number = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const monday: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - mondayOffset);
    const mondayMs: number = monday.getTime();

    const sql: string = `SELECT COALESCE(SUM(mr.duration), 0) as total FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ?`;
    const bindArgs: relationalStore.ValueType[] = [mondayMs];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    let total: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      total = resultSet.getLong(resultSet.getColumnIndex('total'));
    }
    resultSet.close();
    return total;
  }

  /** 查询本月学习总时长（秒），1 日 0:00 至今 */
  async getMonthDuration(): Promise<number> {
    const today: Date = new Date();
    const firstDay: Date = new Date(today.getFullYear(), today.getMonth(), 1);
    const firstDayMs: number = firstDay.getTime();

    const sql: string = `SELECT COALESCE(SUM(mr.duration), 0) as total FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ?`;
    const bindArgs: relationalStore.ValueType[] = [firstDayMs];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    let total: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      total = resultSet.getLong(resultSet.getColumnIndex('total'));
    }
    resultSet.close();
    return total;
  }

  /** 查询指定牌组的总复习次数 */
  async getTotalCountByDeck(deckId: number): Promise<number> {
    const sql: string = `SELECT COUNT(*) as cnt FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE c.deck_id = ?`;
    const bindArgs: relationalStore.ValueType[] = [deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    let count: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
    }
    resultSet.close();
    return count;
  }

  /** 查询指定牌组的评分分布 */
  async getRatingDistributionByDeck(deckId: number): Promise<RatingDistribution> {
    const sql: string =
      `SELECT mr.result, COUNT(*) as cnt FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE c.deck_id = ? GROUP BY mr.result`;
    const bindArgs: relationalStore.ValueType[] = [deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    let forget: number = 0;
    let hard: number = 0;
    let good: number = 0;
    let easy: number = 0;
    let total: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const result: number = resultSet.getLong(resultSet.getColumnIndex('result'));
        const cnt: number = resultSet.getLong(resultSet.getColumnIndex('cnt'));
        if (result === 0) forget = cnt;
        else if (result === 1) hard = cnt;
        else if (result === 2) good = cnt;
        else if (result === 3) easy = cnt;
        total += cnt;
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    const dist: RatingDistribution = { forget, hard, good, easy, total };
    return dist;
  }

  /** 查询指定牌组的每日正确率统计 */
  async getDailyAccuracyStatsByDeck(daysBack: number, deckId: number): Promise<DailyAccuracyRow[]> {
    const today: Date = new Date();
    const startDate: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysBack + 1);
    const startMs: number = startDate.getTime();
    const endMs: number = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1).getTime();

    const sql: string =
      `SELECT mr.date, mr.result FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ? AND c.deck_id = ? ORDER BY mr.date ASC`;
    const bindArgs: relationalStore.ValueType[] = [startMs, endMs, deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);

    const dayMap: Map<string, DayAccuracy> = new Map();
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const timestamp: number = resultSet.getLong(resultSet.getColumnIndex('date'));
        const result: number = resultSet.getLong(resultSet.getColumnIndex('result'));
        const recordDate: Date = new Date(timestamp);
        const key: string = recordDate.getMonth() + 1 + '/' + recordDate.getDate();
        const acc: DayAccuracy = dayMap.get(key) ?? { goodCount: 0, totalCount: 0 };
        acc.totalCount++;
        if (result === 2 || result === 3) {
          acc.goodCount++;
        }
        dayMap.set(key, acc);
      } while (resultSet.goToNextRow());
    }
    resultSet.close();

    const result: DailyAccuracyRow[] = [];
    for (let i: number = 0; i < daysBack; i++) {
      const d: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysBack + 1 + i);
      const key: string = d.getMonth() + 1 + '/' + d.getDate();
      const acc: DayAccuracy = dayMap.get(key) ?? { goodCount: 0, totalCount: 0 };
      const row: DailyAccuracyRow = {
        dateLabel: key,
        goodCount: acc.goodCount,
        totalCount: acc.totalCount,
      };
      result.push(row);
    }
    return result;
  }

  /** 查询指定牌组的每日学习时长 */
  async getDailyDurationsByDeck(daysBack: number, deckId: number): Promise<DailyDuration[]> {
    const today: Date = new Date();
    const startDate: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysBack + 1);
    const startMs: number = startDate.getTime();
    const endMs: number = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1).getTime();

    const sql: string =
      `SELECT mr.date, mr.duration FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ? AND c.deck_id = ?`;
    const bindArgs: relationalStore.ValueType[] = [startMs, endMs, deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);

    const dayMap: Map<string, number> = new Map();
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const timestamp: number = resultSet.getLong(resultSet.getColumnIndex('date'));
        const duration: number = resultSet.getLong(resultSet.getColumnIndex('duration'));
        const recordDate: Date = new Date(timestamp);
        const key: string = recordDate.getMonth() + 1 + '/' + recordDate.getDate();
        dayMap.set(key, (dayMap.get(key) || 0) + duration);
      } while (resultSet.goToNextRow());
    }
    resultSet.close();

    const result: DailyDuration[] = [];
    for (let i: number = 0; i < daysBack; i++) {
      const d: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysBack + 1 + i);
      const key: string = d.getMonth() + 1 + '/' + d.getDate();
      const dur: DailyDuration = {
        dateLabel: key,
        totalSeconds: dayMap.get(key) || 0,
      };
      result.push(dur);
    }
    return result;
  }

  /** 查询指定牌组的卡片难度统计 */
  async getCardsWithDifficultyByDeck(deckId: number): Promise<CardDifficultyRow[]> {
    const sql: string =
      `SELECT mr.card_id, c.front, SUM(CASE WHEN mr.result = 0 THEN 1 ELSE 0 END) as forgets, COUNT(*) as total FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE c.deck_id = ? GROUP BY mr.card_id HAVING total >= 3 ORDER BY forgets * 1.0 / total DESC`;
    const bindArgs: relationalStore.ValueType[] = [deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    const rows: CardDifficultyRow[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const row: CardDifficultyRow = {
          cardId: resultSet.getLong(resultSet.getColumnIndex('card_id')),
          cardFront: resultSet.getString(resultSet.getColumnIndex('front')),
          forgetCount: resultSet.getLong(resultSet.getColumnIndex('forgets')),
          totalReviews: resultSet.getLong(resultSet.getColumnIndex('total')),
        };
        rows.push(row);
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return rows;
  }

  /** 查询指定牌组的总学习时长（秒） */
  async getTotalDurationByDeck(deckId: number): Promise<number> {
    const sql: string = `SELECT COALESCE(SUM(mr.duration), 0) as total FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE c.deck_id = ?`;
    const bindArgs: relationalStore.ValueType[] = [deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    let total: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      total = resultSet.getLong(resultSet.getColumnIndex('total'));
    }
    resultSet.close();
    return total;
  }

  /** 查询指定牌组的本周学习时长（秒） */
  async getWeekDurationByDeck(deckId: number): Promise<number> {
    const today: Date = new Date();
    const dayOfWeek: number = today.getDay();
    const mondayOffset: number = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const monday: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - mondayOffset);
    const mondayMs: number = monday.getTime();
    const sql: string = `SELECT COALESCE(SUM(mr.duration), 0) as total FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND c.deck_id = ?`;
    const bindArgs: relationalStore.ValueType[] = [mondayMs, deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    let total: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      total = resultSet.getLong(resultSet.getColumnIndex('total'));
    }
    resultSet.close();
    return total;
  }

  /** 查询指定牌组的本月学习时长（秒） */
  async getMonthDurationByDeck(deckId: number): Promise<number> {
    const today: Date = new Date();
    const firstDay: Date = new Date(today.getFullYear(), today.getMonth(), 1);
    const firstDayMs: number = firstDay.getTime();
    const sql: string = `SELECT COALESCE(SUM(mr.duration), 0) as total FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND c.deck_id = ?`;
    const bindArgs: relationalStore.ValueType[] = [firstDayMs, deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    let total: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      total = resultSet.getLong(resultSet.getColumnIndex('total'));
    }
    resultSet.close();
    return total;
  }

  /** 查询指定牌组某一天的记录 */
  async getRecordsByDateAndDeck(year: number, month: number, day: number, deckId: number): Promise<MemoryRecord[]> {
    const startOfDay: number = new Date(year, month - 1, day).getTime();
    const endOfDay: number = startOfDay + 86400000;

    const sql: string =
      `SELECT mr.id, mr.card_id, mr.result, mr.date, mr.duration FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ? AND c.deck_id = ? ORDER BY mr.date DESC`;
    const bindArgs: relationalStore.ValueType[] = [startOfDay, endOfDay, deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    const records: MemoryRecord[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        records.push(rowToRecord(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return records;
  }

  /** 查询指定牌组的今日记录 */
  async getTodayRecordsByDeck(deckId: number): Promise<MemoryRecord[]> {
    const now: Date = new Date();
    const startOfDay: number = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const endOfDay: number = startOfDay + 86400000;

    const sql: string =
      `SELECT mr.id, mr.card_id, mr.result, mr.date, mr.duration FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ? AND c.deck_id = ?`;
    const bindArgs: relationalStore.ValueType[] = [startOfDay, endOfDay, deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    const records: MemoryRecord[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        records.push(rowToRecord(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return records;
  }

  /** 查询指定牌组某月的复习日期集合 */
  async getReviewDatesByMonthByDeck(year: number, month: number, deckId: number): Promise<Set<number>> {
    const startDate: Date = new Date(year, month - 1, 1);
    const endDate: Date = new Date(year, month, 1);
    const startMs: number = startDate.getTime();
    const endMs: number = endDate.getTime();

    const sql: string =
      `SELECT mr.date FROM memory_record mr INNER JOIN card c ON mr.card_id = c.id WHERE mr.date >= ? AND mr.date < ? AND c.deck_id = ?`;
    const bindArgs: relationalStore.ValueType[] = [startMs, endMs, deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    const dates: Set<number> = new Set();
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        const timestamp: number = resultSet.getLong(resultSet.getColumnIndex('date'));
        const recordDate: Date = new Date(timestamp);
        dates.add(recordDate.getDate());
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return dates;
  }
}

interface DayAccuracy {
  goodCount: number;
  totalCount: number;
}

export interface RatingDistribution {
  forget: number;
  hard: number;
  good: number;
  easy: number;
  total: number;
}

export interface CardDifficultyRow {
  cardId: number;
  cardFront: string;
  forgetCount: number;
  totalReviews: number;
}

export interface DailyAccuracyRow {
  dateLabel: string;
  goodCount: number;
  totalCount: number;
}
