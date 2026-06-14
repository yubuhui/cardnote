import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { DatabaseManager } from '../data/DatabaseManager';

const DOMAIN = 0x0000;
const TAG = 'EntryBackupAbility';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    hilog.info(DOMAIN, TAG, 'onBackup: 开始备份准备');
    try {
      const store = DatabaseManager.getInstance().getStore();
      if (store) {
        await store.executeSql('PRAGMA wal_checkpoint(FULL)');
        hilog.info(DOMAIN, TAG, 'onBackup: 数据库 checkpoint 完成');
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'onBackup: 数据库准备失败 %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, 'onBackup 完成');
  }

  async onRestore(bundleVersion: BundleVersion) {
    hilog.info(DOMAIN, TAG, 'onRestore: 版本 %{public}s', JSON.stringify(bundleVersion));
    hilog.info(DOMAIN, TAG, 'onRestore 完成');
  }
}