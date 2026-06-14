import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { DeckDao } from '../data/DeckDao';
import { CardDao } from '../data/CardDao';
import { MemoryRecordDao } from '../data/MemoryRecordDao';
import { DatabaseManager } from '../data/DatabaseManager';
import { Deck } from '../model/Deck';
import { Card } from '../model/Card';
import { MemoryRecord } from '../model/MemoryRecord';
import { WebDAVSyncService } from './WebDAVSyncService';
import { WebDAVClient, WebDAVItem } from '../webdav/WebDAVClient';
import { WebDAVConfig } from '../webdav/SyncModels';
import { formatFileSize, formatTimestamp } from '../utils/DateUtils';
import { util } from '@kit.ArkTS';
import relationalStore from '@ohos.data.relationalStore';

/** 备份文件格式版本 */
const BACKUP_VERSION: number = 1;

/** 需要备份的 Preferences 名称列表 */
const PREF_NAMES: string[] = ['app_settings', 'webdav_sync', 'huawei_auth'];

/** 本地备份目录名（相对于应用的 filesDir） */
const BACKUP_DIR: string = 'backups';

/** 最大保留备份文件数量 */
const MAX_BACKUP_FILES: number = 10;

/** 单个 Preferences 存储域的快照 */
export interface PreferenceSnapshot {
  name: string;
  entries: Record<string, string | number | boolean>;
}

/** 备份文件的顶层数据结构 */
export interface BackupData {
  version: number;
  exportedAt: number;
  decks: Deck[];
  cards: Card[];
  records: MemoryRecord[];
  preferences: PreferenceSnapshot[];
}

/** 备份摘要（用于恢复前预览） */
export interface BackupSummary {
  deckCount: number;
  cardCount: number;
  recordCount: number;
}

/** 本地备份文件信息 */
export interface BackupFileInfo {
  fileName: string;
  path: string;
  timestamp: number;
  size: number;
  formattedSize: string;
  formattedTime: string;
}

export class BackupService {
  private static instance: BackupService;

  private deckDao: DeckDao = new DeckDao();
  private cardDao: CardDao = new CardDao();
  private recordDao: MemoryRecordDao = new MemoryRecordDao();

  static getInstance(): BackupService {
    if (!BackupService.instance) {
      BackupService.instance = new BackupService();
    }
    return BackupService.instance;
  }

  // ==================== JSON 导出 / 恢复 ====================

  /** 导出全部数据为 JSON 字符串 */
  async exportBackupJson(context: Context): Promise<string> {
    const decks: Deck[] = await this.deckDao.getAll();
    const cards: Card[] = await this.cardDao.getAll();
    const records: MemoryRecord[] = await this.recordDao.getAll();
    const prefSnapshots: PreferenceSnapshot[] = this.readAllPreferences(context);

    const backup: BackupData = {
      version: BACKUP_VERSION,
      exportedAt: Date.now(),
      decks: decks,
      cards: cards,
      records: records,
      preferences: prefSnapshots,
    };

    return JSON.stringify(backup);
  }

  /** 从 JSON 字符串恢复全部数据，返回恢复摘要 */
  async restoreFromBackup(context: Context, jsonString: string): Promise<BackupSummary> {
    const backup: BackupData = JSON.parse(jsonString) as BackupData;

    if (!backup.version || !backup.decks || !backup.cards || !backup.records) {
      throw new Error('无效的备份文件格式');
    }

    const store: relationalStore.RdbStore = DatabaseManager.getInstance().getStore();
    if (!store) {
      throw new Error('数据库未初始化');
    }

    // 清空现有数据（顺序：先删子表再删主表，避免外键约束问题）
    store.executeSql('DELETE FROM memory_record');
    store.executeSql('DELETE FROM card');
    store.executeSql('DELETE FROM deck');

    // 恢复牌组
    for (const deck of backup.decks) {
      await this.deckDao.insert(deck);
    }

    // 恢复卡片
    for (const card of backup.cards) {
      await this.cardDao.insert(card);
    }

    // 恢复记忆记录
    for (const record of backup.records) {
      await this.recordDao.insert(record);
    }

    // 恢复 Preferences
    this.restoreAllPreferences(context, backup.preferences);

    return {
      deckCount: backup.decks.length,
      cardCount: backup.cards.length,
      recordCount: backup.records.length,
    };
  }

  /** 从 JSON 字符串解析备份数据（仅读取元数据，不写入） */
  parseBackupSummary(jsonString: string): BackupSummary {
    const backup: BackupData = JSON.parse(jsonString) as BackupData;
    return {
      deckCount: backup.decks?.length ?? 0,
      cardCount: backup.cards?.length ?? 0,
      recordCount: backup.records?.length ?? 0,
    };
  }

  // ==================== 本地备份文件管理 ====================

  /** 获取备份文件目录路径 */
  private getBackupDir(context: Context): string {
    return context.filesDir + '/' + BACKUP_DIR;
  }

  /** 确保备份目录存在 */
  private ensureBackupDir(context: Context): void {
    const dir: string = this.getBackupDir(context);
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
  }

  /** 将 JSON 数据保存到本地备份目录，返回文件名 */
  saveBackupToLocal(context: Context, jsonString: string): string {
    this.ensureBackupDir(context);
    const now: Date = new Date();
    const fileName: string = `cardnote_backup_${formatTimestamp(now)}.json`;
    const filePath: string = this.getBackupDir(context) + '/' + fileName;

    const file: fs.File = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    fs.writeSync(file.fd, jsonString);
    fs.closeSync(file);

    // 清理旧备份
    this.cleanOldBackups(context);

    return fileName;
  }

  /** 列出本地备份目录中的所有备份文件，按时间倒序 */
  listLocalBackups(context: Context): BackupFileInfo[] {
    const dir: string = this.getBackupDir(context);
    if (!fs.accessSync(dir)) {
      return [];
    }

    const allFiles: string[] = fs.listFileSync(dir);
    const results: BackupFileInfo[] = [];

    for (const fileName of allFiles) {
      if (!fileName.endsWith('.json')) {
        continue;
      }
      const filePath: string = dir + '/' + fileName;
      try {
        const stat: fs.Stat = fs.statSync(filePath);
        const mtimeMs: number = stat.mtime * 1000;
        results.push({
          fileName: fileName,
          path: filePath,
          timestamp: mtimeMs,
          size: stat.size,
          formattedSize: formatFileSize(stat.size),
          formattedTime: this.formatLocalTime(mtimeMs),
        });
      } catch (_e) {
        // 跳过无法读取的文件
      }
    }

    // 按修改时间倒序排列
    results.sort((a: BackupFileInfo, b: BackupFileInfo) => b.timestamp - a.timestamp);
    return results;
  }

  /** 删除指定本地备份文件 */
  deleteLocalBackup(context: Context, fileName: string): boolean {
    const filePath: string = this.getBackupDir(context) + '/' + fileName;
    try {
      if (fs.accessSync(filePath)) {
        fs.unlinkSync(filePath);
        return true;
      }
    } catch (_e) {
      // ignore
    }
    return false;
  }

  /** 读取本地备份文件的 JSON 内容 */
  readLocalBackup(context: Context, fileName: string): string {
    const filePath: string = this.getBackupDir(context) + '/' + fileName;
    const file: fs.File = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
    const stat: fs.Stat = fs.statSync(filePath);
    const arrayBuffer: ArrayBuffer = new ArrayBuffer(stat.size);
    fs.readSync(file.fd, arrayBuffer);
    fs.closeSync(file);

    const textDecoder: util.TextDecoder = new util.TextDecoder('utf-8', { fatal: false });
    return textDecoder.decodeToString(new Uint8Array(arrayBuffer));
  }

  /** 清理旧备份：仅保留最近 MAX_BACKUP_FILES 个 */
  private cleanOldBackups(context: Context): void {
    const backups: BackupFileInfo[] = this.listLocalBackups(context);
    if (backups.length <= MAX_BACKUP_FILES) {
      return;
    }
    // 按时间升序，删除最旧的
    const oldest: BackupFileInfo[] = backups.slice(MAX_BACKUP_FILES);
    for (const item of oldest) {
      this.deleteLocalBackup(context, item.fileName);
    }
  }

  /** 执行一次自动备份（导出 → 存入本地备份目录） */
  async performAutoBackup(context: Context): Promise<string> {
    const jsonString: string = await this.exportBackupJson(context);
    const fileName: string = this.saveBackupToLocal(context, jsonString);
    console.info('自动备份完成:', fileName);
    return fileName;
  }

  // ==================== 云备份（WebDAV） ====================

  /** 获取 WebDAV 客户端实例（需已配置 WebDAV 同步） */
  private getWebDAVClient(): WebDAVClient | null {
    const syncService: WebDAVSyncService = WebDAVSyncService.getInstance();
    const config: WebDAVConfig | null = syncService.loadConfig();
    if (!config || !config.baseUrl) {
      return null;
    }
    return new WebDAVClient(config.baseUrl, config.username, config.password);
  }

  /** 云备份远端目录路径 */
  private getCloudBackupDir(config: WebDAVConfig): string {
    const base: string = config.syncPath || 'kanjisync';
    return base + '/backups';
  }

  /** 上传当前备份到 WebDAV 云端 */
  async uploadBackupToCloud(context: Context): Promise<string> {
    const client: WebDAVClient | null = this.getWebDAVClient();
    if (!client) {
      throw new Error('请先配置 WebDAV 同步');
    }

    const syncService: WebDAVSyncService = WebDAVSyncService.getInstance();
    const config: WebDAVConfig = syncService.loadConfig()!;
    const cloudDir: string = this.getCloudBackupDir(config);

    // 确保云端备份目录存在
    try {
      await client.listDirectory(cloudDir);
    } catch (_e) {
      await client.createDirectory(cloudDir);
    }

    // 导出 JSON 并上传
    const jsonString: string = await this.exportBackupJson(context);
    const now: Date = new Date();
    const fileName: string = `cardnote_backup_${formatTimestamp(now)}.json`;
    const remotePath: string = cloudDir + '/' + fileName;

    await client.putText(remotePath, jsonString, 'application/json');
    return fileName;
  }

  /** 列出云端备份文件 */
  async listCloudBackups(): Promise<WebDAVItem[]> {
    const client: WebDAVClient | null = this.getWebDAVClient();
    if (!client) {
      throw new Error('请先配置 WebDAV 同步');
    }

    const syncService: WebDAVSyncService = WebDAVSyncService.getInstance();
    const config: WebDAVConfig = syncService.loadConfig()!;
    const cloudDir: string = this.getCloudBackupDir(config);

    const items: WebDAVItem[] = await client.listDirectory(cloudDir);
    // 仅保留 .json 文件，按最后修改时间倒序
    const backups: WebDAVItem[] = items.filter((item: WebDAVItem) =>
      !item.isDirectory && item.name.endsWith('.json')
    );
    return backups;
  }

  /** 从云端下载指定备份文件内容 */
  async downloadCloudBackup(remotePath: string): Promise<string> {
    const client: WebDAVClient | null = this.getWebDAVClient();
    if (!client) {
      throw new Error('请先配置 WebDAV 同步');
    }
    return client.getText(remotePath);
  }

  /** 检查 WebDAV 是否已配置 */
  isCloudConfigured(): boolean {
    return WebDAVSyncService.getInstance().isConfigured();
  }

  // ==================== 自动备份偏好设置 ====================

  get autoBackupPrefName(): string {
    return 'app_settings';
  }

  isAutoBackupEnabled(context: Context): boolean {
    try {
      const pref: preferences.Preferences = preferences.getPreferencesSync(context, { name: this.autoBackupPrefName });
      return pref.getSync('auto_backup_enabled', false) as boolean;
    } catch (_e) {
      return false;
    }
  }

  setAutoBackupEnabled(context: Context, enabled: boolean): void {
    try {
      const pref: preferences.Preferences = preferences.getPreferencesSync(context, { name: this.autoBackupPrefName });
      pref.putSync('auto_backup_enabled', enabled);
      pref.flush();
    } catch (err) {
      console.error('BackupService: 设置自动备份开关失败', JSON.stringify(err));
    }
  }

  getAutoBackupFrequency(context: Context): string {
    try {
      const pref: preferences.Preferences = preferences.getPreferencesSync(context, { name: this.autoBackupPrefName });
      return pref.getSync('auto_backup_frequency', 'weekly') as string;
    } catch (_e) {
      return 'weekly';
    }
  }

  setAutoBackupFrequency(context: Context, frequency: string): void {
    try {
      const pref: preferences.Preferences = preferences.getPreferencesSync(context, { name: this.autoBackupPrefName });
      pref.putSync('auto_backup_frequency', frequency);
      pref.flush();
    } catch (err) {
      console.error('BackupService: 设置自动备份频率失败', JSON.stringify(err));
    }
  }

  // ========== 私有方法 ==========

  /** 读取所有 Preferences 快照 */
  private readAllPreferences(context: Context): PreferenceSnapshot[] {
    const snapshots: PreferenceSnapshot[] = [];
    for (const name of PREF_NAMES) {
      try {
        const pref: preferences.Preferences = preferences.getPreferencesSync(context, { name: name });
        const allKeys: string[] = this.getAllPrefKeys(pref);
        const entries: Record<string, string | number | boolean> = {};
        for (const key of allKeys) {
          const val: Object = pref.getSync(key, '');
          if (typeof val === 'string' || typeof val === 'number' || typeof val === 'boolean') {
            entries[key] = val;
          }
        }
        snapshots.push({ name: name, entries: entries });
      } catch (err) {
        console.error(`BackupService: 读取 Preferences '${name}' 失败`, JSON.stringify(err));
      }
    }
    return snapshots;
  }

  /** 恢复所有 Preferences */
  private restoreAllPreferences(context: Context, snapshots: PreferenceSnapshot[]): void {
    for (const snapshot of snapshots) {
      try {
        const pref: preferences.Preferences = preferences.getPreferencesSync(context, { name: snapshot.name });
        // 清除该域现有键，再写入备份中的键
        const existingKeys: string[] = this.getAllPrefKeys(pref);
        for (const key of existingKeys) {
          pref.deleteSync(key);
        }
        const keys: string[] = Object.keys(snapshot.entries);
        for (const key of keys) {
          const val: Object = snapshot.entries[key];
          pref.putSync(key, val);
        }
        pref.flush();
      } catch (err) {
        console.error(`BackupService: 恢复 Preferences '${snapshot.name}' 失败`, JSON.stringify(err));
      }
    }
  }

  /** 获取指定 Preferences 域的所有已知 key */
  private getAllPrefKeys(pref: preferences.Preferences): string[] {
    // 通过尝试 hasSync 检测已知白名单中的 key
    const candidateKeys: string[] = [
      'dark_mode', 'privacy_agreed', 'daily_new_cards', 'daily_review_cards',
      'sm2_factor', 'skip_mastered_cards',
      'base_url', 'username', 'password', 'sync_path',
      'last_sync_time', 'sync_enabled', 'tombstones',
      'union_id', 'open_id', 'is_logged_in',
      'auto_backup_enabled', 'auto_backup_frequency',
    ];
    const found: string[] = [];
    for (const key of candidateKeys) {
      try {
        if (pref.hasSync(key)) {
          found.push(key);
        }
      } catch (_e) {
        // 忽略单个 key 检测失败
      }
    }
    return found;
  }

  private formatLocalTime(timestamp: number): string {
    const d: Date = new Date(timestamp);
    const y: string = String(d.getFullYear());
    const m: string = this.pad2(d.getMonth() + 1);
    const day: string = this.pad2(d.getDate());
    const hh: string = this.pad2(d.getHours());
    const mm: string = this.pad2(d.getMinutes());
    return `${y}-${m}-${day} ${hh}:${mm}`;
  }

  private pad2(n: number): string {
    return n < 10 ? '0' + n : String(n);
  }
}
