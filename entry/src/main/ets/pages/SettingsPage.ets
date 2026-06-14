import { ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CloudSyncService, SyncStatus } from '../service/CloudSyncService';
import { WebDAVSyncService } from '../service/WebDAVSyncService';

export interface SettingsItem {
  title: string;
  subtitle?: string;
  /** 点击跳转的路由路径 */
  routeName?: string;
}

@Component
export struct SettingsPage {
  @State isDarkMode: boolean = false;
  @State syncStatus: SyncStatus = SyncStatus.IDLE;
  @State syncTimeText: string = '从未同步';
  @State isSyncing: boolean = false;
  // WebDAV 状态
  @State webdavLastSync: string = '尚未同步';
  private settingsPref: preferences.Preferences | null = null;
  private cloudSyncService: CloudSyncService = CloudSyncService.getInstance();
  private webdavService: WebDAVSyncService = new WebDAVSyncService();

  async aboutToAppear(): Promise<void> {
    try {
      this.settingsPref = preferences.getPreferencesSync(
        this.getUIContext().getHostContext(), { name: 'app_settings' }
      );
      this.isDarkMode = this.settingsPref.getSync('dark_mode', false) as boolean;
    } catch (err) {
      console.error('Failed to load dark mode preference:', err);
    }

    // 刷新云同步时间显示
    this.syncTimeText = this.cloudSyncService.getLastSyncTimeText();

    // 初始化 WebDAV 同步服务并刷新状态
    this.webdavService.init(this.getUIContext().getHostContext()!);
    const webdavTime: number = this.webdavService.getLastSyncTime();
    if (webdavTime > 0) {
      const d: Date = new Date(webdavTime);
      this.webdavLastSync = `上次同步: ${this.formatDate(d)}`;
    }
  }

  /** 手动触发云同步 */
  private async triggerSync(): Promise<void> {
    if (this.isSyncing) {
      return;
    }
    this.isSyncing = true;
    await this.cloudSyncService.sync((status: SyncStatus) => {
      this.syncStatus = status;
      this.syncTimeText = this.cloudSyncService.getLastSyncTimeText();
    });
    this.isSyncing = false;
  }

  private formatDate(d: Date): string {
    const pad: (n: number) => string = (n: number): string => (n < 10 ? '0' + n : String(n));
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  /** 获取同步状态对应的颜色 */
  private getSyncStatusColor(): string {
    switch (this.syncStatus) {
      case SyncStatus.SUCCESS:
        return '#4CAF50';
      case SyncStatus.SYNCING:
      case SyncStatus.RETRYING:
        return '#2196F3';
      case SyncStatus.NETWORK_ERROR:
      case SyncStatus.PAUSED:
      case SyncStatus.STORAGE_FULL:
      case SyncStatus.WIFI_ONLY:
      case SyncStatus.NOT_ENABLED:
        return '#F44336';
      default:
        return '#999';
    }
  }

  private goToPage(routeName: string) {
    this.getUIContext().getRouter().pushUrl({ url: routeName });
  }

  private applyDarkMode(enabled: boolean) {
    try {
      const appCtx = this.getUIContext().getHostContext()?.getApplicationContext();
      if (appCtx) {
        appCtx.setColorMode(
          enabled ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
            : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        );
      }
      // 持久化设置
      this.settingsPref?.putSync('dark_mode', enabled);
      this.settingsPref?.flush();
    } catch (err) {
      console.error('Failed to apply dark mode:', err);
    }
  }

  build() {
    Column() {
      Text('设置')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 46, bottom: 12 })
        .backgroundColor(Color.White)

      Scroll() {
        Column() {
          this.buildSection('数据管理', [
            { title: '背诵设置', routeName: 'pages/ReviewSettingsPage' } as SettingsItem,
            { title: '导入与导出', routeName: 'pages/ImportExportPage' } as SettingsItem,
          ])

          // 外观设置
          Column() {
            Text('外观设置')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333')
              .margin({ bottom: 10 })

            // 深色模式开关
            Row() {
              Text('深色模式')
                .fontSize(14)
                .fontColor('#333')
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
                .onChange((isOn: boolean) => {
                  this.isDarkMode = isOn;
                  this.applyDarkMode(isOn);
                })
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .padding({ top: 10, bottom: 10 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ top: 10 })

          // 同步
          Column() {
            Text('同步')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333')
              .margin({ bottom: 10 })

            Row() {
              Text('上次同步')
                .fontSize(14)
                .fontColor('#333')
                .layoutWeight(1)
              Text(this.webdavLastSync)
                .fontSize(13)
                .fontColor('#999')
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .border({ width: { bottom: 1 }, color: '#f5f5f5' })

            Row() {
              Text('WebDAV设置')
                .fontSize(14)
                .fontColor('#333')
                .layoutWeight(1)
              Text('›')
                .fontSize(18)
                .fontColor('#CCC')
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .onClick(() => {
              this.goToPage('pages/WebDavSyncPage');
            })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ top: 10 })

          this.buildSection('关于', [
            { title: '帮助与反馈', routeName: 'pages/HelpFeedbackPage' } as SettingsItem,
            { title: '隐私政策', routeName: 'pages/PrivacyPolicyPage' } as SettingsItem,
            { title: '版本号', subtitle: '1.0.0' } as SettingsItem,
          ])

          // ICP备案号（符合中国法律法规要求）
          Text('ICP备案号：待备案')
            .fontSize(11)
            .fontColor('#BBB')
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ top: 12, bottom: 24 })
        }
      }
      .align(Alignment.Top)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  @Builder
  buildSection(title: string, items: SettingsItem[]) {
    Column() {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
        .margin({ bottom: 10 })

      ForEach(items, (item: SettingsItem, index: number) => {
        Row() {
          Text(item.title)
            .fontSize(14)
            .fontColor('#333')
            .layoutWeight(1)
          if (item.subtitle) {
            Text(item.subtitle)
              .fontSize(13)
              .fontColor('#999')
          }
          if (item.routeName) {
            Text('›')
              .fontSize(18)
              .fontColor('#CCC')
          }
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .border(index < items.length - 1 ? { width: { bottom: 1 }, color: '#f5f5f5' } : {})
        .onClick(() => {
          if (item.routeName) {
            this.goToPage(item.routeName);
          }
        })
      }, (item: SettingsItem) => item.title)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ top: 10 })
  }
}
