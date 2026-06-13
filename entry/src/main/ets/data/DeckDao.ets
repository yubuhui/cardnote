import relationalStore from '@ohos.data.relationalStore';
import { DatabaseManager } from './DatabaseManager';
import { Deck } from '../model/Deck';

/** 将 Deck 对象转为插入用的 ColumnValueMap */
function deckToValues(deck: Deck): relationalStore.ValuesBucket {
  const values: relationalStore.ValuesBucket = {
    name: deck.name,
    icon: deck.icon,
    color: deck.color,
    created_at: deck.createdAt,
    updated_at: deck.updatedAt,
  };
  if (deck.dailyNewCards !== undefined) {
    values['daily_new_cards'] = deck.dailyNewCards;
  }
  if (deck.dailyReviewCards !== undefined) {
    values['daily_review_cards'] = deck.dailyReviewCards;
  }
  return values;
}

/** 将 ResultSet 行转为 Deck 对象 */
function rowToDeck(resultSet: relationalStore.ResultSet): Deck {
  const deck: Deck = {
    id: resultSet.getLong(resultSet.getColumnIndex('id')),
    name: resultSet.getString(resultSet.getColumnIndex('name')),
    icon: resultSet.getString(resultSet.getColumnIndex('icon')),
    color: resultSet.getString(resultSet.getColumnIndex('color')),
    createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
    updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at')),
  };
  const newCardsIdx: number = resultSet.getColumnIndex('daily_new_cards');
  if (newCardsIdx >= 0) {
    deck.dailyNewCards = resultSet.getLong(newCardsIdx);
  }
  const reviewCardsIdx: number = resultSet.getColumnIndex('daily_review_cards');
  if (reviewCardsIdx >= 0) {
    deck.dailyReviewCards = resultSet.getLong(reviewCardsIdx);
  }
  return deck;
}

export class DeckDao {
  private db: relationalStore.RdbStore;

  constructor() {
    this.db = DatabaseManager.getInstance().getStore();
  }

  /** 插入牌组 */
  async insert(deck: Deck): Promise<number> {
    const values: relationalStore.ValuesBucket = deckToValues(deck);
    const result: number = await this.db.insert('deck', values);
    return result;
  }

  /** 根据 ID 查询 */
  async getById(id: number): Promise<Deck | null> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('deck');
    predicates.equalTo('id', id);
    const resultSet: relationalStore.ResultSet = await this.db.query(predicates);
    if (resultSet.rowCount === 0) {
      resultSet.close();
      return null;
    }
    resultSet.goToFirstRow();
    const deck: Deck = rowToDeck(resultSet);
    resultSet.close();
    return deck;
  }

  /** 查询所有牌组 */
  async getAll(): Promise<Deck[]> {
    const resultSet: relationalStore.ResultSet = await this.db.query(
      new relationalStore.RdbPredicates('deck').orderByDesc('updated_at')
    );
    const decks: Deck[] = [];
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      do {
        decks.push(rowToDeck(resultSet));
      } while (resultSet.goToNextRow());
    }
    resultSet.close();
    return decks;
  }

  /** 更新牌组 */
  async update(deck: Deck): Promise<void> {
    const values: relationalStore.ValuesBucket = deckToValues(deck);
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('deck');
    predicates.equalTo('id', deck.id);
    await this.db.update(values, predicates);
  }

  /** 更新牌组设置（每日限额） */
  async updateDeckSettings(deckId: number, dailyNewCards: number, dailyReviewCards: number): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      daily_new_cards: dailyNewCards,
      daily_review_cards: dailyReviewCards,
      updated_at: Date.now(),
    };
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('deck');
    predicates.equalTo('id', deckId);
    await this.db.update(values, predicates);
  }

  /** 删除牌组 */
  async delete(id: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('deck');
    predicates.equalTo('id', id);
    await this.db.delete(predicates);
  }
}
