import { Deck } from '../model/Deck';
import { Card } from '../model/Card';
import { MemoryRecord } from '../model/MemoryRecord';

// ==========================================
// 索引文件
// ==========================================

/** 远程根索引：/kanjisync/index.json */
export interface SyncIndex {
  /** 索引格式版本（用于兼容未来升级） */
  version: number;
  /** 索引最后更新时间戳 */
  updatedAt: number;
  /** 以 deck.uuid 为 key 的牌组摘要 */
  decks: Record<string, DeckSummary>;
}

/** 单个牌组的摘要信息 */
export interface DeckSummary {
  /** 该牌组的最后更新时间戳（取 deck.updatedAt） */
  updatedAt: number;
  /** 卡片数量 */
  cardCount: number;
  /** 记忆记录数量 */
  recordCount: number;
}

// ==========================================
// 数据包：牌组 + 卡片 + 记忆记录
// ==========================================

/** 单个牌组的完整数据包：/kanjisync/deck_<uuid>.json */
export interface DeckBundle {
  deck: Deck;
  cards: Card[];
  records: MemoryRecord[];
  /** 数据包生成时间戳 */
  exportedAt: number;
}

// ==========================================
// 同步配置
// ==========================================

/** WebDAV 连接配置 */
export interface WebDAVConfig {
  /** WebDAV 服务器根 URL */
  baseUrl: string;
  /** 用户名 */
  username: string;
  /** 密码 */
  password: string;
  /** 同步目录名（远端基路径，默认 kanjisync） */
  syncPath: string;
}

/** 同步方向 */
export enum SyncDirection {
  /** 只拉取远端变更 */
  PULL = 1,
  /** 只推送本地变更 */
  PUSH = 2,
  /** 先拉取再推送 */
  FULL = 3,
}

/** 单次同步结果 */
export interface SyncResult {
  /** 同步方向 */
  direction: SyncDirection;
  /** 同步开始时间 */
  startTime: number;
  /** 同步结束时间 */
  endTime: number;
  /** 推送的牌组数 */
  pushedDecks: number;
  /** 拉取的牌组数 */
  pulledDecks: number;
  /** 删除的牌组数（逻辑删除） */
  deletedDecks: number;
  /** 错误信息（成功时为 null） */
  error: string | null;
}

/** PUSH 阶段结果 */
export interface PushPhaseResult {
  pushedDecks: number;
  deletedDecks: number;
}

/** PULL 阶段结果 */
export interface PullPhaseResult {
  pulledDecks: number;
}
