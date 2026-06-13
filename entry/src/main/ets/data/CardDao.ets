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
  };
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
    options: JSON.parse(resultSet.getString(resultSet.getColumnIndex('options'))),
    correctAnswer: resultSet.getString(resultSet.getColumnIndex('correct_answer')),
    displayOrder: JSON.parse(resultSet.getString(resultSet.getColumnIndex('display_order'))),
    analysis: resultSet.getString(resultSet.getColumnIndex('analysis')),
    easeFactor: resultSet.getDouble(resultSet.getColumnIndex('ease_factor')),
    interval: resultSet.getLong(resultSet.getColumnIndex('interval')),
    repetitions: resultSet.getLong(resultSet.getColumnIndex('repetitions')),
    nextReviewTime: resultSet.getLong(resultSet.getColumnIndex('next_review_time')),
    createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
    updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at')),
  };
  return card;
}

export class CardDao {
  private db: relationalStore.RdbStore;

  constructor() {
    this.db = DatabaseManager.getInstance().getStore();
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
}
