import { WebDAVClient, WebDAVItem } from '../webdav/WebDAVClient';
import {
  SyncIndex, DeckSummary, DeckBundle, WebDAVConfig,
  SyncDirection, SyncResult, PushPhaseResult, PullPhaseResult,
} from '../webdav/SyncModels';
import { Deck } from '../model/Deck';
import { Card } from '../model/Card';
import { MemoryRecord } from '../model/MemoryRecord';
import { DeckDao } from '../data/DeckDao';
import { CardDao } from '../data/CardDao';
import { MemoryRecordDao } from '../data/MemoryRecordDao';
import { preferences } from '@kit.ArkData';
import { DataRefreshHelper } from '../utils/DataRefreshHelper';

/** 持久化存储名 */
const PREF_NAME: string = 'webdav_sync';

/** 偏好存储键名 */
const KEY_BASE_URL: string = 'base_url';
const KEY_USERNAME: string = 'username';
const KEY_PASSWORD: string = 'password';
const KEY_SYNC_PATH: string = 'sync_path';
const KEY_LAST_SYNC_TIME: string = 'last_sync_time';
const KEY_SYNC_ENABLED: string = 'sync_enabled';
const KEY_TOMBSTONES: string = 'tombstones';
const DEFAULT_SYNC_PATH: string = 'cardnote';

/**
 * WebDAV 牌组粒度增量同步服务
 *
 * 同步架构（方案 B）：
 *   远端文件：
 *     /<syncPath>/index.json              — 索引文件
 *     /<syncPath>/deck_<uuid>.json        — 牌组完整数据包
 *   PUSH：比较 updatedAt → 仅上传变更牌组
 *   PULL：下载索引比较 → 仅下载变更牌组 → merge
 *   FULL：先 PULL 后 PUSH
 *   删除：墓碑 UUID 列表跟踪已删除牌组，PUSH 时清理远端文件
 */
export class WebDAVSyncService {
  private static instance: WebDAVSyncService | null = null;
  private client: WebDAVClient | null = null;
  private pref: preferences.Preferences | null = null;
  private deckDao: DeckDao;
  private cardDao: CardDao;
  private recordDao: MemoryRecordDao;
  private syncPath: string = DEFAULT_SYNC_PATH;

  private constructor() {
    this.deckDao = new DeckDao();
    this.cardDao = new CardDao();
    this.recordDao = new MemoryRecordDao();
  }

  /** 获取单例（需先调用 initOnce） */
  static getInstance(): WebDAVSyncService {
    if (!WebDAVSyncService.instance) {
      WebDAVSyncService.instance = new WebDAVSyncService();
    }
    return WebDAVSyncService.instance;
  }

  /** 在 EntryAbility 中调用一次，初始化 preferences */
  initOnce(context: Context): void {
    if (this.pref) {
      return;
    }
    this.pref = preferences.getPreferencesSync(context, { name: PREF_NAME });
  }

  /** 远端索引文件路径 */
  private getIndexPath(): string {
    return `${this.syncPath}/index.json`;
  }

  /** 远端牌组文件路径 */
  private getDeckPath(deckUuid: string): string {
    return `${this.syncPath}/deck_${deckUuid}.json`;
  }

  // ==========================================
  // 配置管理
  // ==========================================

  /** 加载 WebDAV 配置 */
  loadConfig(): WebDAVConfig | null {
    if (!this.pref) {
      return null;
    }
    const baseUrl: string = this.pref.getSync(KEY_BASE_URL, '') as string;
    const username: string = this.pref.getSync(KEY_USERNAME, '') as string;
    const password: string = this.pref.getSync(KEY_PASSWORD, '') as string;
    const syncPath: string = this.pref.getSync(KEY_SYNC_PATH, DEFAULT_SYNC_PATH) as string;
    if (!baseUrl || !username || !password) {
      return null;
    }
    this.syncPath = syncPath || DEFAULT_SYNC_PATH;
    return { baseUrl, username, password, syncPath: this.syncPath };
  }

  /** 保存 WebDAV 配置 */
  saveConfig(config: WebDAVConfig): void {
    if (!this.pref) {
      return;
    }
    this.pref.putSync(KEY_BASE_URL, config.baseUrl);
    this.pref.putSync(KEY_USERNAME, config.username);
    this.pref.putSync(KEY_PASSWORD, config.password);
    this.pref.putSync(KEY_SYNC_PATH, config.syncPath || DEFAULT_SYNC_PATH);
    this.syncPath = config.syncPath || DEFAULT_SYNC_PATH;
    this.pref.flush();
  }

  /** 获取上次同步时间 */
  getLastSyncTime(): number {
    if (!this.pref) {
      return 0;
    }
    return this.pref.getSync(KEY_LAST_SYNC_TIME, 0) as number;
  }

  /** 保存上次同步时间 */
  private setLastSyncTime(time: number): void {
    if (!this.pref) {
      return;
    }
    this.pref.putSync(KEY_LAST_SYNC_TIME, time);
    this.pref.flush();
  }

  /** 清除 WebDAV 配置（断开连接） */
  clearConfig(): void {
    if (!this.pref) {
      return;
    }
    this.pref.putSync(KEY_BASE_URL, '');
    this.pref.putSync(KEY_USERNAME, '');
    this.pref.putSync(KEY_PASSWORD, '');
    this.pref.putSync(KEY_SYNC_PATH, DEFAULT_SYNC_PATH);
    this.syncPath = DEFAULT_SYNC_PATH;
    this.client = null;
    this.pref.flush();
  }

  /** 获取同步开关状态 */
  isSyncEnabled(): boolean {
    if (!this.pref) {
      return false;
    }
    return this.pref.getSync(KEY_SYNC_ENABLED, false) as boolean;
  }

  /** 设置同步开关状态 */
  setSyncEnabled(enabled: boolean): void {
    if (!this.pref) {
      return;
    }
    this.pref.putSync(KEY_SYNC_ENABLED, enabled);
    this.pref.flush();
  }

  /** 获取墓碑 UUID 列表 */
  private getTombstones(): string[] {
    if (!this.pref) {
      return [];
    }
    const raw: string = this.pref.getSync(KEY_TOMBSTONES, '[]') as string;
    try {
      return JSON.parse(raw) as string[];
    } catch (e) {
      return [];
    }
  }

  /** 保存墓碑列表 */
  private saveTombstones(uuids: string[]): void {
    if (!this.pref) {
      return;
    }
    this.pref.putSync(KEY_TOMBSTONES, JSON.stringify(uuids));
    this.pref.flush();
  }

  // ==========================================
  // 连接初始化 & 测试
  // ==========================================

  private initClient(): void {
    const config: WebDAVConfig | null = this.loadConfig();
    if (!config) {
      throw new Error('WebDAV 未配置');
    }
    this.client = new WebDAVClient(config.baseUrl, config.username, config.password);
  }

  /** 测试连接是否可用 */
  async testConnection(): Promise<boolean> {
    try {
      this.initClient();
      const exists: boolean = await this.client!.exists(this.getIndexPath());
      return true; // 能连上就算成功（索引文件未必存在）
    } catch (err) {
      return false;
    }
  }

  /** 列出服务器指定路径下所有子目录 */
  async listDirectories(subPath: string = ''): Promise<string[]> {
    this.initClient();
    const items: WebDAVItem[] = await this.client!.listDirectory(subPath);
    const dirs: string[] = [];
    for (let i: number = 0; i < items.length; i++) {
      if (items[i].isDirectory) {
        dirs.push(items[i].name);
      }
    }
    return dirs;
  }

  /** 在服务器上创建目录 */
  async createDirectory(dirName: string, parentPath: string = ''): Promise<void> {
    this.initClient();
    const fullPath: string = parentPath ? `${parentPath}/${dirName}` : dirName;
    await this.client!.createDirectory(fullPath);
  }

  // ==========================================
  // 索引构建
  // ==========================================

  /** 从本地数据库构建索引 */
  private async buildLocalIndex(): Promise<SyncIndex> {
    const decks: Deck[] = await this.deckDao.getAll();
    const indexMap: Record<string, DeckSummary> = {};
    let maxUpdatedAt: number = 0;

    for (let i: number = 0; i < decks.length; i++) {
      const deck: Deck = decks[i];
      if (!deck.uuid) {
        continue;
      }
      const cards: Card[] = await this.cardDao.getByDeckId(deck.id);
      let recordCount: number = 0;
      for (let j: number = 0; j < cards.length; j++) {
        const records: MemoryRecord[] = await this.recordDao.getByCardId(cards[j].id);
        recordCount += records.length;
      }
      indexMap[deck.uuid] = {
        updatedAt: deck.updatedAt,
        cardCount: cards.length,
        recordCount: recordCount,
      };
      if (deck.updatedAt > maxUpdatedAt) {
        maxUpdatedAt = deck.updatedAt;
      }
    }

    return {
      version: 1,
      updatedAt: maxUpdatedAt,
      decks: indexMap,
    };
  }

  /** 从远端下载索引 */
  private async fetchRemoteIndex(): Promise<SyncIndex | null> {
    if (!this.client) {
      return null;
    }
    try {
      const text: string = await this.client.getText(this.getIndexPath());
      return JSON.parse(text) as SyncIndex;
    } catch (err) {
      return null; // 首次同步：索引不存在
    }
  }

  /** 上传索引 */
  private async pushIndex(index: SyncIndex): Promise<void> {
    if (!this.client) {
      throw new Error('Client not initialized');
    }
    await this.client.putText(this.getIndexPath(), JSON.stringify(index));
  }

  // ==========================================
  // PUSH：本地 → 远端
  // ==========================================

  /**
   * 推送本地变更到远端
   */
  private async pushChanges(): Promise<PushPhaseResult> {
    if (!this.client) {
      throw new Error('Client not initialized');
    }
    const remoteIndex: SyncIndex | null = await this.fetchRemoteIndex();
    const localIndex: SyncIndex = await this.buildLocalIndex();
    const tombstones: string[] = this.getTombstones();
    let pushedDecks: number = 0;
    let deletedDecks: number = 0;
    let needRebuild: boolean = false;

    // 1. 处理墓碑：删除远端对应牌组文件
    const remoteUuidList: string[] = remoteIndex ? Object.keys(remoteIndex.decks) : [];
    const remainingTombstones: string[] = [];

    for (let i: number = 0; i < tombstones.length; i++) {
      const uuid: string = tombstones[i];
      if (remoteUuidList.indexOf(uuid) >= 0) {
        try {
          await this.client.deleteFile(this.getDeckPath(uuid));
          deletedDecks++;
          needRebuild = true;
        } catch (err) {
          // 远端可能已不存在，忽略
        }
      } else {
        remainingTombstones.push(uuid);
      }
    }
    this.saveTombstones(remainingTombstones);

    // 2. 上传变更或新增的牌组
    const localUuidList: string[] = Object.keys(localIndex.decks);
    for (let i: number = 0; i < localUuidList.length; i++) {
      const uuid: string = localUuidList[i];
      const localSummary: DeckSummary = localIndex.decks[uuid];
      const remoteSummary: DeckSummary | undefined = remoteIndex?.decks[uuid];

      if (!remoteSummary || localSummary.updatedAt > remoteSummary.updatedAt) {
        const bundle: DeckBundle | null = await this.buildDeckBundle(uuid);
        if (bundle) {
          await this.client.putText(this.getDeckPath(uuid), JSON.stringify(bundle));
          pushedDecks++;
          needRebuild = true;
        }
      }
    }

    // 3. 有变更则重建索引
    if (needRebuild) {
      const newIndex: SyncIndex = await this.buildLocalIndex();
      await this.pushIndex(newIndex);
    }

    const result: PushPhaseResult = { pushedDecks: pushedDecks, deletedDecks: deletedDecks };
    return result;
  }

  // ==========================================
  // PULL：远端 → 本地
  // ==========================================

  /**
   * 从远端拉取变更
   */
  private async pullChanges(): Promise<PullPhaseResult> {
    if (!this.client) {
      throw new Error('Client not initialized');
    }

    const remoteIndex: SyncIndex | null = await this.fetchRemoteIndex();
    if (!remoteIndex) {
      const emptyResult: PullPhaseResult = { pulledDecks: 0 };
      return emptyResult;
    }

    const tombstones: string[] = this.getTombstones();
    const localDecks: Deck[] = await this.deckDao.getAll();
    let pulledDecks: number = 0;

    const remoteUuids: string[] = Object.keys(remoteIndex.decks);
    for (let i: number = 0; i < remoteUuids.length; i++) {
      const uuid: string = remoteUuids[i];
      const remoteSummary: DeckSummary = remoteIndex.decks[uuid];

      // 跳过墓碑牌组（本地已删除）
      if (tombstones.indexOf(uuid) >= 0) {
        continue;
      }

      // 查找本地对应牌组
      let localDeck: Deck | undefined;
      for (let j: number = 0; j < localDecks.length; j++) {
        if (localDecks[j].uuid === uuid) {
          localDeck = localDecks[j];
          break;
        }
      }

      if (!localDeck || remoteSummary.updatedAt > localDeck.updatedAt) {
        await this.downloadAndMergeDeck(uuid);
        pulledDecks++;
      }
    }

    const result: PullPhaseResult = { pulledDecks: pulledDecks };
    return result;
  }

  // ==========================================
  // 完整同步（先 PULL 再 PUSH）
  // ==========================================

  /** 执行完整同步（先 PULL 再 PUSH） */
  async fullSync(): Promise<SyncResult> {
    const startTime: number = Date.now();
    const result: SyncResult = {
      direction: SyncDirection.FULL,
      startTime: startTime,
      endTime: 0,
      pushedDecks: 0,
      pulledDecks: 0,
      deletedDecks: 0,
      error: null,
    };

    try {
      this.initClient();

      // 1. PULL 先拉取远端变更
      const pullR: PullPhaseResult = await this.pullChanges();
      result.pulledDecks = pullR.pulledDecks;

      // 2. PUSH 再推送本地变更
      const pushR: PushPhaseResult = await this.pushChanges();
      result.pushedDecks = pushR.pushedDecks;
      result.deletedDecks = pushR.deletedDecks;

      this.setLastSyncTime(Date.now());
      if (pullR.pulledDecks > 0) {
        DataRefreshHelper.notify();
      }
    } catch (err) {
      result.error = `同步失败: ${(err as Error).message}`;
    }

    result.endTime = Date.now();
    return result;
  }

  /** 仅上传：本地 → 云端 */
  async pushToCloud(): Promise<SyncResult> {
    const startTime: number = Date.now();
    const result: SyncResult = {
      direction: SyncDirection.PUSH,
      startTime: startTime,
      endTime: 0,
      pushedDecks: 0,
      pulledDecks: 0,
      deletedDecks: 0,
      error: null,
    };

    try {
      this.initClient();
      const pushR: PushPhaseResult = await this.pushChanges();
      result.pushedDecks = pushR.pushedDecks;
      result.deletedDecks = pushR.deletedDecks;
      this.setLastSyncTime(Date.now());
    } catch (err) {
      result.error = `上传失败: ${(err as Error).message}`;
    }

    result.endTime = Date.now();
    return result;
  }

  /** 仅下载：云端 → 本地 */
  async pullFromCloud(): Promise<SyncResult> {
    const startTime: number = Date.now();
    const result: SyncResult = {
      direction: SyncDirection.PULL,
      startTime: startTime,
      endTime: 0,
      pushedDecks: 0,
      pulledDecks: 0,
      deletedDecks: 0,
      error: null,
    };

    try {
      this.initClient();
      const pullR: PullPhaseResult = await this.pullChanges();
      result.pulledDecks = pullR.pulledDecks;
      this.setLastSyncTime(Date.now());
      if (pullR.pulledDecks > 0) {
        DataRefreshHelper.notify();
      }
    } catch (err) {
      result.error = `下载失败: ${(err as Error).message}`;
    }

    result.endTime = Date.now();
    return result;
  }

  /**
   * 标记牌组 uuid 为已删除
   * 调用方在删除牌组后需调用此方法
   */
  markDeckDeleted(deckUuid: string): void {
    const tombstones: string[] = this.getTombstones();
    if (tombstones.indexOf(deckUuid) < 0) {
      tombstones.push(deckUuid);
      this.saveTombstones(tombstones);
    }
  }

  /** 是否已配置 */
  isConfigured(): boolean {
    return this.loadConfig() !== null;
  }

  // ==========================================
  // 内部方法
  // ==========================================

  /** 根据 UUID 构建完整牌组数据包 */
  private async buildDeckBundle(deckUuid: string): Promise<DeckBundle | null> {
    const deck: Deck | null = await this.deckDao.getByUuid(deckUuid);
    if (!deck) {
      return null;
    }

    const cards: Card[] = await this.cardDao.getByDeckUuid(deckUuid);
    const records: MemoryRecord[] = [];
    for (let i: number = 0; i < cards.length; i++) {
      if (cards[i].uuid) {
        const crList: MemoryRecord[] = await this.recordDao.getByCardUuid(cards[i].uuid!);
        for (let j: number = 0; j < crList.length; j++) {
          records.push(crList[j]);
        }
      }
    }

    return { deck, cards, records, exportedAt: Date.now() };
  }

  /**
   * 将 Bundle 中的卡片和记录合并到指定牌组
   */
  private async mergeCardsIntoDeck(bundle: DeckBundle, targetDeckId: number, targetDeckUuid: string | undefined): Promise<void> {
    const remoteCardUuids: string[] = [];

    // 合并 Cards
    for (let i: number = 0; i < bundle.cards.length; i++) {
      const card: Card = bundle.cards[i];
      if (!card.uuid) {
        continue;
      }
      remoteCardUuids.push(card.uuid);
      const existing: Card | null = await this.cardDao.getByUuid(card.uuid);
      if (existing) {
        card.id = existing.id;
      } else {
        card.id = 0;
      }
      card.deckId = targetDeckId;
      card.deckUuid = targetDeckUuid;

      if (existing) {
        await this.cardDao.update(card);
      } else {
        await this.cardDao.insert(card);
      }
    }

    // 删除远端已不存在的卡片
    const localCards: Card[] = await this.cardDao.getByDeckId(targetDeckId);
    for (let i: number = 0; i < localCards.length; i++) {
      if (localCards[i].uuid && remoteCardUuids.indexOf(localCards[i].uuid!) < 0) {
        await this.recordDao.deleteByCardId(localCards[i].id);
        await this.cardDao.delete(localCards[i].id);
      }
    }

    // 合并 Records（按 UUID 去重，已存在的不覆盖）
    for (let i: number = 0; i < bundle.records.length; i++) {
      const record: MemoryRecord = bundle.records[i];
      if (!record.uuid) {
        continue;
      }
      const existing: MemoryRecord | null = await this.recordDao.getByUuid(record.uuid);
      if (existing) {
        continue;
      }
      if (record.cardUuid) {
        const localCard: Card | null = await this.cardDao.getByUuid(record.cardUuid);
        if (localCard) {
          record.cardId = localCard.id;
        }
      }
      record.id = 0;
      await this.recordDao.insert(record);
    }
  }

  /** 下载远端牌组并合并到本地数据库 */
  private async downloadAndMergeDeck(deckUuid: string): Promise<void> {
    if (!this.client) {
      throw new Error('Client not initialized');
    }

    const text: string = await this.client.getText(this.getDeckPath(deckUuid));
    const bundle: DeckBundle = JSON.parse(text) as DeckBundle;

    // === 特殊处理：远程默认牌组合并到本地默认牌组 ===
    if (bundle.deck.isDefault) {
      const localDefault: Deck | null = await this.deckDao.getDefaultDeck();
      if (localDefault) {
        await this.mergeCardsIntoDeck(bundle, localDefault.id, localDefault.uuid);
        return;
      }
      // 本地没有默认牌组（异常），走正常创建流程
    }

    // 1. 合并 Deck
    const localDeck: Deck | null = await this.deckDao.getByUuid(deckUuid);
    if (localDeck) {
      bundle.deck.id = localDeck.id;
      // 保留本地 isDefault 标记，不被远程覆盖
      bundle.deck.isDefault = localDeck.isDefault;
      await this.deckDao.update(bundle.deck);
    } else {
      bundle.deck.id = 0;
      await this.deckDao.insert(bundle.deck);
    }

    // 取回本地 ID
    const refreshed: Deck | null = await this.deckDao.getByUuid(deckUuid);
    if (!refreshed) {
      throw new Error('无法获取牌组本地 ID');
    }

    await this.mergeCardsIntoDeck(bundle, refreshed.id, refreshed.uuid);
  }
}
