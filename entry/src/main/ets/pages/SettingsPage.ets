import { ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CloudSyncService, SyncStatus } from '../service/CloudSyncService';
import { WebDAVSyncService } from '../service/WebDAVSyncService';
import { formatDateTime } from '../utils/DateUtils';

export interface SettingsItem {
  title: string;
  subtitle?: string;
  routeName?: string;
}

@Component
export struct SettingsPage {
  @State isDarkMode: boolean = false;
  @State syncStatus: SyncStatus = SyncStatus.IDLE;
  @State syncTimeText: string = '从未同步';
  @State isSyncing: boolean = false;
  @State webdavLastSync: string = '尚未同步';
  @State syncEnabled: boolean = false;
  @State isUploading: boolean = false;
  @State isDownloading: boolean = false;
  @State uploadResultText: string = '';
  @State downloadResultText: string = '';
  private settingsPref: preferences.Preferences | null = null;
  private cloudSyncService: CloudSyncService = CloudSyncService.getInstance();
  private webdavService: WebDAVSyncService = WebDAVSyncService.getInstance();

  aboutToAppear(): void {
    try {
      this.settingsPref = preferences.getPreferencesSync(
        this.getUIContext().getHostContext(), { name: 'app_settings' }
      );
      this.isDarkMode = this.settingsPref.getSync('dark_mode', false) as boolean;
    } catch (err) {
      console.error('Failed to load dark mode preference:', err);
    }

    this.syncTimeText = this.cloudSyncService.getLastSyncTimeText();

    this.syncEnabled = this.webdavService.isSyncEnabled();
    const webdavTime: number = this.webdavService.getLastSyncTime();
    if (webdavTime > 0) {
      const d: Date = new Date(webdavTime);
      this.webdavLastSync = `上次同步: ${formatDateTime(d)}`;
    }
  }

  private async triggerSync(): Promise<void> {
    if (this.isSyncing) return;
    this.isSyncing = true;
    await this.cloudSyncService.sync((status: SyncStatus) => {
      this.syncStatus = status;
      this.syncTimeText = this.cloudSyncService.getLastSyncTimeText();
    });
    this.isSyncing = false;
  }

  private async triggerUpload(): Promise<void> {
    if (this.isUploading || !this.syncEnabled) return;
    if (!this.webdavService.isConfigured()) {
      this.uploadResultText = '请先配置 WebDAV 并测试连接';
      return;
    }
    this.isUploading = true;
    this.uploadResultText = '上传中...';
    const result = await this.webdavService.pushToCloud();
    if (result.error) {
      this.uploadResultText = '上传失败';
    } else {
      const d: Date = new Date();
      this.uploadResultText = `上次上传: ${formatDateTime(d)} (${result.pushedDecks}个牌组)`;
      this.webdavLastSync = formatDateTime(d);
    }
    this.isUploading = false;
  }

  private triggerDownload(): void {
    if (this.isDownloading || !this.syncEnabled) return;
    if (!this.webdavService.isConfigured()) {
      this.downloadResultText = '请先配置 WebDAV 并测试连接';
      return;
    }

    this.getUIContext().showAlertDialog({
      title: '确认下载',
      message: '从云端下载将覆盖本地数据，确定吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '确定',
        fontColor: $r('app.color.warning'),
        action: async () => {
          this.isDownloading = true;
          this.downloadResultText = '下载中...';
          const result = await this.webdavService.pullFromCloud();
          if (result.error) {
            this.downloadResultText = '下载失败';
          } else {
            const d: Date = new Date();
            this.downloadResultText = `上次下载: ${formatDateTime(d)} (${result.pulledDecks}个牌组)`;
            this.webdavLastSync = formatDateTime(d);
          }
          this.isDownloading = false;
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: $r('app.color.text_secondary'),
        action: () => {}
      }
    });
  }

  private getSyncStatusColor(): ResourceColor {
    switch (this.syncStatus) {
      case SyncStatus.SUCCESS:
        return $r('app.color.success');
      case SyncStatus.SYNCING:
      case SyncStatus.RETRYING:
        return $r('app.color.primary');
      case SyncStatus.NETWORK_ERROR:
      case SyncStatus.PAUSED:
      case SyncStatus.STORAGE_FULL:
      case SyncStatus.WIFI_ONLY:
      case SyncStatus.NOT_ENABLED:
        return $r('app.color.danger');
      default:
        return $r('app.color.text_secondary');
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
      // 同步到 AppStorage，供其他页面感知颜色模式变化
      AppStorage.setOrCreate('currentColorMode',
        enabled ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
          : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
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
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 46, bottom: 12 })
        .backgroundColor($r('app.color.surface'))

      Scroll() {
        Column() {
          this.buildSection('数据管理', [
            { title: '背诵设置', routeName: 'pages/ReviewSettingsPage' } as SettingsItem,
            { title: '导入与导出', routeName: 'pages/ImportExportPage' } as SettingsItem,
            { title: '备份', routeName: 'pages/BackupPage' } as SettingsItem,
          ])

          // 外观设置
          Column() {
            Text('外观设置')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 10 })

            Row() {
              Text('深色模式')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
                .onChange((isOn: boolean) => {
                  this.isDarkMode = isOn;
                  this.applyDarkMode(isOn);
                })
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)
          .margin({ top: 10 })

          // 同步
          Column() {
            Text('同步')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 10 })

            Row() {
              Text('启用同步')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.syncEnabled })
                .selectedColor($r('app.color.primary'))
                .onChange((isOn: boolean) => {
                  this.syncEnabled = isOn;
                  this.webdavService.setSyncEnabled(isOn);
                })
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .border({ width: { bottom: 1 }, color: $r('app.color.outline') })

            Row() {
              Text('WebDAV设置')
                .fontSize(14)
                .fontColor(this.syncEnabled ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
                .layoutWeight(1)
              Text('›')
                .fontSize(18)
                .fontColor(this.syncEnabled ? $r('app.color.text_secondary') : $r('app.color.text_secondary'))
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .border({ width: { bottom: 1 }, color: $r('app.color.outline') })
            .onClick(() => {
              if (this.syncEnabled) this.goToPage('pages/WebDavSyncPage');
            })

            Row() {
              Text('上传到云端')
                .fontSize(14)
                .fontColor(this.syncEnabled ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
                .layoutWeight(1)
              if (this.isUploading) {
                LoadingProgress()
                  .width(20).height(20).color($r('app.color.primary'))
              } else {
                Text(this.uploadResultText)
                  .fontSize(13).fontColor($r('app.color.text_secondary'))
              }
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .border({ width: { bottom: 1 }, color: $r('app.color.outline') })
            .onClick(() => { this.triggerUpload(); })

            Row() {
              Text('从云端下载')
                .fontSize(14)
                .fontColor(this.syncEnabled ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
                .layoutWeight(1)
              if (this.isDownloading) {
                LoadingProgress()
                  .width(20).height(20).color($r('app.color.primary'))
              } else {
                Text(this.downloadResultText)
                  .fontSize(13).fontColor($r('app.color.text_secondary'))
              }
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .onClick(() => { this.triggerDownload(); })
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)
          .margin({ top: 10 })

          this.buildSection('关于', [
            { title: '帮助与反馈', routeName: 'pages/HelpFeedbackPage' } as SettingsItem,
            { title: '隐私政策', routeName: 'pages/PrivacyPolicyPage' } as SettingsItem,
            { title: '版本号', subtitle: '1.0.0' } as SettingsItem,
          ])

          Text('ICP备案号：待备案')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ top: 12, bottom: 24 })

          Blank().height(68)
        }
      }
      .align(Alignment.Top)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  buildSection(title: string, items: SettingsItem[]) {
    Column() {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 10 })

      ForEach(items, (item: SettingsItem, index: number) => {
        Row() {
          Text(item.title)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          if (item.subtitle) {
            Text(item.subtitle)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          if (item.routeName) {
            Text('›')
              .fontSize(18)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .border(index < items.length - 1 ? { width: { bottom: 1 }, color: $r('app.color.outline') } : {})
        .onClick(() => {
          if (item.routeName) this.goToPage(item.routeName);
        })
      }, (item: SettingsItem) => item.title)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ top: 10 })
  }
}