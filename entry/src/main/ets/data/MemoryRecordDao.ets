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
  private db: relationalStore.RdbStore;

  constructor() {
    this.db = DatabaseManager.getInstance().getStore();
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
}
