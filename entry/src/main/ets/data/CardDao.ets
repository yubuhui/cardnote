import relationalStore from '@ohos.data.relationalStore';
import { DatabaseManager } from './DatabaseManager';
import { Card } from '../model/Card';
import { CardType, CardStatus } from '../model/CardTypeEnum';

/** 将 Card 对象转为 ColumnValueMap */
function cardToValues(card: Card): relationalStore.ValuesBucket {
  const values: relationalStore.ValuesBucket = {
    deck_id: card.deckId,
    type: card.type,
    status: card.status,
    front: card.front,
    options: JSON.stringify(card.options),
    correct_answer: card.correctAnswer,
    display_order: JSON.stringify(card.displayOrder),
    analysis: card.analysis,
    ease_factor: card.easeFactor,
    interval: card.interval,
    repetitions: card.repetitions,
    next_review_time: card.nextReviewTime,
    created_at: card.createdAt,
    updated_at: card.updatedAt,
    is_bookmarked: card.isBookmarked ? 1 : 0,
  };
  if (card.uuid) {
    values['uuid'] = card.uuid;
  }
  if (card.deckUuid) {
    values['deck_uuid'] = card.deckUuid;
  }
  return values;
}

/** 将 ResultSet 行转为 Card 对象 */
function rowToCard(resultSet: relationalStore.ResultSet): Card {
  const card: Card = {
    id: resultSet.getLong(resultSet.getColumnIndex('id')),
    deckId: resultSet.getLong(resultSet.getColumnIndex('deck_id')),
    type: resultSet.getLong(resultSet.getColumnIndex('type')) as CardType,
    status: resultSet.getLong(resultSet.getColumnIndex('status')) as CardStatus,
    front: resultSet.getString(resultSet.getColumnIndex('front')),
    options: (() => { try { return JSON.parse(resultSet.getString(resultSet.getColumnIndex('options'))) as string[]; } catch (_e) { return [] as string[]; } })(),
    correctAnswer: resultSet.getString(resultSet.getColumnIndex('correct_answer')),
    displayOrder: (() => { try { return JSON.parse(resultSet.getString(resultSet.getColumnIndex('display_order'))) as number[]; } catch (_e) { return [] as number[]; } })(),
    analysis: resultSet.getString(resultSet.getColumnIndex('analysis')),
    easeFactor: resultSet.getDouble(resultSet.getColumnIndex('ease_factor')),
    interval: resultSet.getLong(resultSet.getColumnIndex('interval')),
    repetitions: resultSet.getLong(resultSet.getColumnIndex('repetitions')),
    nextReviewTime: resultSet.getLong(resultSet.getColumnIndex('next_review_time')),
    createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
    updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at')),
  };
  const uuidIdx: number = resultSet.getColumnIndex('uuid');
  if (uuidIdx >= 0) {
    card.uuid = resultSet.getString(uuidIdx);
  }
  const deckUuidIdx: number = resultSet.getColumnIndex('deck_uuid');
  if (deckUuidIdx >= 0) {
    card.deckUuid = resultSet.getString(deckUuidIdx);
  }
  const bookmarkIdx: number = resultSet.getColumnIndex('is_bookmarked');
  if (bookmarkIdx >= 0) {
    card.isBookmarked = resultSet.getLong(bookmarkIdx) !== 0;
  }
  return card;
}

export class CardDao {
  private _db: relationalStore.RdbStore | null = null;

  // 懒加载：构造时不访问数据库，避免在组件字段初始化阶段因 DB 未就绪而崩溃
  private get db(): relationalStore.RdbStore {
    if (!this._db) {
      this._db = DatabaseManager.getInstance().getStore();
    }
    return this._db;
  }

  /** 插入卡片 */
  async insert(card: Card): Promise<number> {
    const values: relationalStore.ValuesBucket = cardToValues(card);
    const result: number = await this.db.insert('card', values);
    return result;
  }

  /** 根据 ID 查询 */
  async getById(id: number): Promise<Card | null> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('id', id);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    if (resultSet.rowCount === 0) {
      resultSet.close();
      return null;
    }
    resultSet.goToFirstRow();
    const card: Card = rowToCard(resultSet);
    resultSet.close();
    return card;
  }

  /** 根据 UUID 查询（跨设备同步用） */
  async getByUuid(uuid: string): Promise<Card | null> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('uuid', uuid);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    if (resultSet.rowCount === 0) {
      resultSet.close();
      return null;
    }
    resultSet.goToFirstRow();
    const card: Card = rowToCard(resultSet);
    resultSet.close();
    return card;
  }

  /** 按牌组 UUID 查询卡片（跨设备同步用） */
  async getByDeckUuid(deckUuid: string): Promise<Card[]> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('deck_uuid', deckUuid);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    const cards: Card[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        cards.push(rowToCard(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return cards;
  }

  /** 查询所有卡片 */
  async getAll(): Promise<Card[]> {
    const resultSet: relationalStore.ResultSet = await this.db.query(
      new relationalStore.RdbPredicates('card').orderByDesc('created_at')
    );
    const cards: Card[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        cards.push(rowToCard(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return cards;
  }

  /** 按牌组查询卡片 */
  async getByDeckId(deckId: number): Promise<Card[]> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('deck_id', deckId);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    const cards: Card[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        cards.push(rowToCard(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return cards;
  }

  /** 按状态查询卡片 */
  async getByStatus(status: CardStatus): Promise<Card[]> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('status', status);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    const cards: Card[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        cards.push(rowToCard(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return cards;
  }

  /** 查询待复习卡片（按下次复习时间排序） */
  async getDueCards(deckIds?: number[]): Promise<Card[]> {
    let predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    const now: number = Date.now();
    predicates = predicates.lessThanOrEqualTo('next_review_time', now);
    if (deckIds && deckIds.length > 0) {
      predicates = predicates.in('deck_id', deckIds);
    }
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates.orderByAsc('next_review_time'));
    const cards: Card[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        cards.push(rowToCard(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return cards;
  }

  /** 更新卡片 */
  async update(card: Card): Promise<void> {
    const values: relationalStore.ValuesBucket = cardToValues(card);
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('id', card.id);
    await this.db.update(values, predicates);
  }

  /** 删除卡片 */
  async delete(id: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('id', id);
    await this.db.delete(predicates);
  }

  /** 根据 UUID 删除卡片（跨设备同步用） */
  async deleteByUuid(uuid: string): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('uuid', uuid);
    await this.db.delete(predicates);
  }

  /** 按牌组 ID 批量删除卡片 */
  async deleteByDeckId(deckId: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('deck_id', deckId);
    await this.db.delete(predicates);
  }

  /** 批量根据 ID 查询 */
  async getByIds(ids: number[]): Promise<Card[]> {
    if (ids.length === 0) {
      return [];
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.in('id', ids);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    const cards: Card[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        cards.push(rowToCard(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return cards;
  }

  /** 统计卡片数 */
  async count(): Promise<number> {
    const resultSet: relationalStore.ResultSet = await this.db.query(
      new relationalStore.RdbPredicates('card')
    );
    const count: number = resultSet.rowCount;
    resultSet.close();
    return count;
  }

  /** 按状态统计 */
  async countByStatus(status: CardStatus): Promise<number> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('status', status);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    const count: number = resultSet.rowCount;
    resultSet.close();
    return count;
  }

  /** 统计未来 N 天内到期的卡片数（包含已到期未复习的卡片） */
  async countDueWithinDays(days: number): Promise<number> {
    const future: number = Date.now() + days * 86400000;
    const sql: string = `SELECT COUNT(*) as cnt FROM card WHERE next_review_time <= ?`;
    const bindArgs: relationalStore.ValueType[] = [future];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    let count: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
    }
    resultSet.close();
    return count;
  }

  /** 统计指定牌组的卡片总数 */
  async countByDeckId(deckId: number): Promise<number> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('deck_id', deckId);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    const count: number = resultSet.rowCount;
    resultSet.close();
    return count;
  }

  /** 统计指定牌组中指定状态的卡片数 */
  async countByStatusAndDeck(status: CardStatus, deckId: number): Promise<number> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('card');
    predicates.equalTo('status', status).equalTo('deck_id', deckId);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    const count: number = resultSet.rowCount;
    resultSet.close();
    return count;
  }

  /** 统计指定牌组中未来 N 天内到期的卡片数（包含已到期） */
  async countDueWithinDaysByDeck(days: number, deckId: number): Promise<number> {
    const future: number = Date.now() + days * 86400000;
    const sql: string = `SELECT COUNT(*) as cnt FROM card WHERE next_review_time <= ? AND deck_id = ?`;
    const bindArgs: relationalStore.ValueType[] = [future, deckId];
    const resultSet: relationalStore.ResultSet = await this.db.querySql(sql, bindArgs);
    let count: number = 0;
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
    }
    resultSet.close();
    return count;
  }
}
