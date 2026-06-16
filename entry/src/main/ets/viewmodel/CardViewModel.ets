import { Card, CardStatus } from '../model/Card';
import { Deck } from '../model/Deck';
import { CardDao } from '../data/CardDao';
import { DeckDao } from '../data/DeckDao';
import { MemoryRecordDao } from '../data/MemoryRecordDao';
import { SM2Algorithm, Rating } from '../data/SM2Algorithm';
import { ReviewSettingsManager } from '../data/ReviewSettingsManager';
import { WebDAVSyncService } from '../service/WebDAVSyncService';
import { util } from '@kit.ArkTS';
import { DataRefreshHelper } from '../utils/DataRefreshHelper';

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
    DataRefreshHelper.notify();
  }

  async updateDeck(deck: Deck): Promise<void> {
    deck.updatedAt = Date.now();
    await this.deckDao.update(deck);
    DataRefreshHelper.notify();
  }

  async deleteDeck(id: number): Promise<void> {
    // 检查是否为系统默认牌组，不允许删除
    const deck: Deck | null = await this.deckDao.getById(id);
    if (!deck) {
      return;
    }
    if (deck.isDefault) {
      throw new Error('系统默认牌组不可删除');
    }

    // 级联删除：先删关联卡片的记忆记录，再删卡片
    const cards: Card[] = await this.cardDao.getByDeckId(id);
    const recordDao: MemoryRecordDao = new MemoryRecordDao();
    for (let i: number = 0; i < cards.length; i++) {
      await recordDao.deleteByCardId(cards[i].id);
    }
    await this.cardDao.deleteByDeckId(id);

    // 删除牌组
    await this.deckDao.delete(id);

    // 标记墓碑，下次同步时删除远端牌组文件
    if (deck.uuid && WebDAVSyncService.getInstance().isConfigured()) {
      WebDAVSyncService.getInstance().markDeckDeleted(deck.uuid);
    }
    DataRefreshHelper.notify();
  }

  async updateDeckSettings(deckId: number, dailyNewCards: number, dailyReviewCards: number): Promise<void> {
    await this.deckDao.updateDeckSettings(deckId, dailyNewCards, dailyReviewCards);
    DataRefreshHelper.notify();
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
    await this.deckDao.touchUpdatedAt(card.deckId);
    DataRefreshHelper.notify();
  }

  async updateCard(card: Card): Promise<void> {
    card.updatedAt = Date.now();
    await this.cardDao.update(card);
    await this.deckDao.touchUpdatedAt(card.deckId);
    DataRefreshHelper.notify();
  }

  async deleteCard(id: number): Promise<void> {
    // 先获取卡片信息以知晓所属牌组
    const card: Card | null = await this.cardDao.getById(id);
    // 先删除关联的记忆记录，再删除卡片
    const recordDao: MemoryRecordDao = new MemoryRecordDao();
    await recordDao.deleteByCardId(id);
    await this.cardDao.delete(id);
    // 更新所属牌组的 updatedAt
    if (card) {
      await this.deckDao.touchUpdatedAt(card.deckId);
    }
    DataRefreshHelper.notify();
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
    await this.deckDao.touchUpdatedAt(card.deckId);
    DataRefreshHelper.notify();
  }

  // ===== 统计 =====
  async getTotalCount(): Promise<number> {
    return this.cardDao.count();
  }

  async getCountByStatus(status: CardStatus): Promise<number> {
    return this.cardDao.countByStatus(status);
  }
}
