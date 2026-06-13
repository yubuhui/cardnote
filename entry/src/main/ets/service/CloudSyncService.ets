import { DatabaseManager } from '../data/DatabaseManager';
import { cloudData } from '@kit.ArkData';
import { relationalStore } from '@kit.ArkData';

/** 同步状态枚举 */
export enum SyncStatus {
  IDLE = '空闲',
  SYNCING = '同步中...',
  SUCCESS = '同步完成',
  PAUSED = '已暂停',
  NETWORK_ERROR = '网络错误',
  NOT_ENABLED = '未开启',
  RETRYING = '重试中...',
  STORAGE_FULL = '存储空间不足',
  WIFI_ONLY = '仅WLAN同步',
}

export enum SyncCode {
  COMPLETED = 0,
  PAUSED = 1,
  NETWORK_ERROR = 2,
  DISABLED = 3,
  RETRYING = 4,
  DATA_LIMIT = 5,
  STORAGE_FULL = 6,
  WIFI_ONLY = 7,
}

export class CloudSyncService {
  private static instance: CloudSyncService | null = null;
  private currentStatus: SyncStatus = SyncStatus.IDLE;
  private lastSyncTime: number = 0;

  private constructor() {}

  static getInstance(): CloudSyncService {
    if (!CloudSyncService.instance) {
      CloudSyncService.instance = new CloudSyncService();
    }
    return CloudSyncService.instance;
  }

  /** 获取当前同步状态文本 */
  getStatusText(): string {
    return this.currentStatus;
  }

  /** 获取上次同步时间 */
  getLastSyncTime(): number {
    return this.lastSyncTime;
  }

  /** 获取上次同步时间的友好文本 */
  getLastSyncTimeText(): string {
    if (this.lastSyncTime === 0) {
      return '从未同步';
    }
    const diff = Date.now() - this.lastSyncTime;
    const minutes = Math.floor(diff / 60000);
    if (minutes < 1) {
      return '刚刚';
    }
    if (minutes < 60) {
      return `${minutes} 分钟前`;
    }
    const hours = Math.floor(minutes / 60);
    if (hours < 24) {
      return `${hours} 小时前`;
    }
    const days = Math.floor(hours / 24);
    return `${days} 天前`;
  }

  /** 手动触发云同步 */
  async sync(
    onProgress?: (status: SyncStatus, progress?: relationalStore.ProgressDetails) => void
  ): Promise<SyncCode> {
    this.currentStatus = SyncStatus.SYNCING;
    if (onProgress) {
      onProgress(SyncStatus.SYNCING);
    }

    try {
      const code = await DatabaseManager.getInstance().manualCloudSync(
        (progress: relationalStore.ProgressDetails) => {
          if (onProgress) {
            onProgress(SyncStatus.SYNCING, progress);
          }
        }
      );

      let syncCode: SyncCode = code as SyncCode;
      switch (syncCode) {
        case SyncCode.COMPLETED:
          this.currentStatus = SyncStatus.SUCCESS;
          this.lastSyncTime = Date.now();
          break;
        case SyncCode.PAUSED:
          this.currentStatus = SyncStatus.PAUSED;
          break;
        case SyncCode.NETWORK_ERROR:
          this.currentStatus = SyncStatus.NETWORK_ERROR;
          break;
        case SyncCode.DISABLED:
          this.currentStatus = SyncStatus.NOT_ENABLED;
          break;
        case SyncCode.RETRYING:
          this.currentStatus = SyncStatus.RETRYING;
          break;
        case SyncCode.STORAGE_FULL:
          this.currentStatus = SyncStatus.STORAGE_FULL;
          break;
        case SyncCode.WIFI_ONLY:
          this.currentStatus = SyncStatus.WIFI_ONLY;
          break;
        default:
          this.currentStatus = SyncStatus.IDLE;
          syncCode = SyncCode.COMPLETED;
          break;
      }

      if (onProgress) {
        onProgress(this.currentStatus);
      }
      return syncCode;
    } catch (err) {
      console.error(`Sync failed: ${JSON.stringify(err)}`);
      this.currentStatus = SyncStatus.NETWORK_ERROR;
      if (onProgress) {
        onProgress(SyncStatus.NETWORK_ERROR);
      }
      return SyncCode.NETWORK_ERROR;
    }
  }

  /**
   * 设置云同步网络策略
   * @param wifiOnly true = 仅 WLAN 同步, false = 全部网络
   */
  async setNetworkStrategy(wifiOnly: boolean): Promise<void> {
    try {
      if (wifiOnly) {
        await cloudData.setCloudStrategy(
          cloudData.StrategyType.NETWORK,
          [cloudData.NetWorkStrategy.WIFI]
        );
      } else {
        await cloudData.setCloudStrategy(
          cloudData.StrategyType.NETWORK,
          [cloudData.NetWorkStrategy.WIFI, cloudData.NetWorkStrategy.CELLULAR]
        );
      }
      console.info(`Cloud sync network strategy set to ${wifiOnly ? 'WIFI' : 'ALL'}`);
    } catch (err) {
      console.error(`setNetworkStrategy failed: ${JSON.stringify(err)}`);
    }
  }
}
