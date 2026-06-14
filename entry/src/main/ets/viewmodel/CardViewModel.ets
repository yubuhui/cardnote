import { Card, CardStatus } from '../model/Card';
import { Deck } from '../model/Deck';
import { CardDao } from '../data/CardDao';
import { DeckDao } from '../data/DeckDao';
import { MemoryRecordDao } from '../data/MemoryRecordDao';
import { SM2Algorithm, Rating } from '../data/SM2Algorithm';
import { ReviewSettingsManager } from '../data/ReviewSettingsManager';
import { util } from '@kit.ArkTS';

/** 卡片视图模型 */
export class CardViewModel {
  private cardDao: CardDao;
  private deckDao: DeckDao;

  constructor() {
    this.cardDao = new CardDao();
    this.deckDao = new DeckDao();
  }

  // ===== 牌组操作 =====
  async getAllDecks(): Promise<Deck[]> {
    return this.deckDao.getAll();
  }

  async getDeckById(id: number): Promise<Deck | null> {
    return this.deckDao.getById(id);
  }

  async createDeck(deck: Deck): Promise<void> {
    deck.uuid = deck.uuid || util.generateRandomUUID(true);
    deck.createdAt = Date.now();
    deck.updatedAt = Date.now();
    await this.deckDao.insert(deck);
  }

  async updateDeck(deck: Deck): Promise<void> {
    deck.updatedAt = Date.now();
    await this.deckDao.update(deck);
  }

  async deleteDeck(id: number): Promise<void> {
    await this.deckDao.delete(id);
  }

  async updateDeckSettings(deckId: number, dailyNewCards: number, dailyReviewCards: number): Promise<void> {
    await this.deckDao.updateDeckSettings(deckId, dailyNewCards, dailyReviewCards);
  }

  // ===== 卡片操作 =====
  async getAllCards(): Promise<Card[]> {
    return this.cardDao.getAll();
  }

  async getCardsByDeckId(deckId: number): Promise<Card[]> {
    return this.cardDao.getByDeckId(deckId);
  }

  async getById(id: number): Promise<Card | null> {
    return this.cardDao.getById(id);
  }

  async getDueCards(deckIds?: number[]): Promise<Card[]> {
    return this.cardDao.getDueCards(deckIds);
  }

  async createCard(card: Card): Promise<void> {
    const now = Date.now();
    card.uuid = card.uuid || util.generateRandomUUID(true);
    card.createdAt = now;
    card.updatedAt = now;
    card.nextReviewTime = now;
    // 自动填充 deckUuid
    if (!card.deckUuid) {
      const deck: Deck | null = await this.deckDao.getById(card.deckId);
      if (deck?.uuid) {
        card.deckUuid = deck.uuid;
      }
    }
    await this.cardDao.insert(card);
  }

  async updateCard(card: Card): Promise<void> {
    card.updatedAt = Date.now();
    await this.cardDao.update(card);
  }

  async deleteCard(id: number): Promise<void> {
    // 先删除关联的记忆记录，再删除卡片
    const recordDao: MemoryRecordDao = new MemoryRecordDao();
    await recordDao.deleteByCardId(id);
    await this.cardDao.delete(id);
  }

  // ===== 学习流程 =====
  /** 处理用户评分 */
  async handleRating(card: Card, rating: Rating): Promise<void> {
    const settings = ReviewSettingsManager.getInstance().load();
    const result = SM2Algorithm.calculateNextReview(card, rating, settings.sm2Factor);
    card.interval = result.interval;
    card.repetitions = result.repetitions;
    card.easeFactor = result.easeFactor;
    card.status = result.status;
    card.nextReviewTime = Date.now() + result.interval * 60000;
    await this.cardDao.update(card);
  }

  // ===== 统计 =====
  async getTotalCount(): Promise<number> {
    return this.cardDao.count();
  }

  async getCountByStatus(status: CardStatus): Promise<number> {
    return this.cardDao.countByStatus(status);
  }
}
