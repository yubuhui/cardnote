import { ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { HuaweiAuthService } from '../service/HuaweiAuthService';
import { CloudSyncService, SyncStatus } from '../service/CloudSyncService';
import { common } from '@kit.AbilityKit';

export interface SettingsItem {
  title: string;
  subtitle?: string;
  /** 点击跳转的路由路径 */
  routeName?: string;
}

@Component
export struct SettingsPage {
  @State isDarkMode: boolean = false;
  @StorageLink('hwIsLoggedIn') isHwLoggedIn: boolean = false;
  @State syncStatus: SyncStatus = SyncStatus.IDLE;
  @State syncTimeText: string = '从未同步';
  @State isSyncing: boolean = false;
  private settingsPref: preferences.Preferences | null = null;
  private cloudSyncService: CloudSyncService = CloudSyncService.getInstance();

  async aboutToAppear(): Promise<void> {
    try {
      this.settingsPref = preferences.getPreferencesSync(
        this.getUIContext().getHostContext(), { name: 'app_settings' }
      );
      this.isDarkMode = this.settingsPref.getSync('dark_mode', false) as boolean;
    } catch (err) {
      console.error('Failed to load dark mode preference:', err);
    }

    // 初始化并检查华为账号登录状态
    try {
      const context: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      await HuaweiAuthService.getInstance().init(context);
      const loggedIn: boolean = HuaweiAuthService.getInstance().isLoggedIn();
      AppStorage.setOrCreate('hwIsLoggedIn', loggedIn);
    } catch (err) {
      console.error('Failed to check login state:', JSON.stringify(err));
    }

    // 刷新云同步时间显示
    this.syncTimeText = this.cloudSyncService.getLastSyncTimeText();
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
          // 账号与登录
          Column() {
            Text('账号与登录')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333')
              .margin({ bottom: 10 })

            Row() {
              Text('华为账号')
                .fontSize(14)
                .fontColor('#333')
                .layoutWeight(1)
              Text(this.isHwLoggedIn ? '已登录' : '未登录')
                .fontSize(13)
                .fontColor(this.isHwLoggedIn ? '#4CAF50' : '#999')
              Text('›')
                .fontSize(18)
                .fontColor('#CCC')
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .onClick(() => {
              this.goToPage('pages/LoginPage');
            })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(12)

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

          // 云同步
          Column() {
            Text('云同步')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333')
              .margin({ bottom: 10 })

            Row() {
              Text('同步状态')
                .fontSize(14)
                .fontColor('#333')
                .layoutWeight(1)
              Text(this.syncStatus)
                .fontSize(13)
                .fontColor(this.getSyncStatusColor())
            }
            .width('100%')
            .padding({ top: 10, bottom: 6 })

            Row() {
              Text('上次同步')
                .fontSize(14)
                .fontColor('#333')
                .layoutWeight(1)
              Text(this.syncTimeText)
                .fontSize(13)
                .fontColor('#999')
            }
            .width('100%')
            .padding({ top: 6, bottom: 10 })

            Button(this.isSyncing ? '同步中...' : '立即同步')
              .fontSize(14)
              .width('100%')
              .height(40)
              .backgroundColor(this.isSyncing ? '#CCC' : '#4A90D9')
              .fontColor(Color.White)
              .borderRadius(8)
              .enabled(!this.isSyncing)
              .onClick(() => {
                this.triggerSync();
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ top: 10 })

          this.buildSection('关于', [
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

      ForEach(items, (item: SettingsItem) => {
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
        .border({ width: { bottom: 1 }, color: '#f5f5f5' })
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
