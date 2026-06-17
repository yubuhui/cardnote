import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { preferences } from '@kit.ArkData';
import { DatabaseManager } from '../data/DatabaseManager';
import { ReviewSettingsManager } from '../data/ReviewSettingsManager';
import { PrivacyDialog } from '../components/PrivacyDialog';
import { WebDAVSyncService } from '../service/WebDAVSyncService';

const DOMAIN = 0x0001;
const TAG = 'CardNote';

export default class EntryAbility extends UIAbility {
  private privacyDialogController: CustomDialogController | null = null;
  private windowStage: window.WindowStage | null = null;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    // 从偏好中读取深色模式设置（统一由此处管理，避免与 SettingsPage 竞态）
    try {
      const pref = preferences.getPreferencesSync(this.context, { name: 'app_settings' });
      const darkMode = pref.getSync('dark_mode', false) as boolean;
      if (darkMode) {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');

    // 初始化数据库（框架会等待此 Promise 完成后再进入 onWindowStageCreate）
    const dbManager = DatabaseManager.getInstance();
    await dbManager.init(this.context);

    // 为现有数据填充 UUID，并设置端云同步
    await dbManager.fillMissingUuids();
    await dbManager.setupCloudSync();
    hilog.info(DOMAIN, TAG, 'Database initialized with cloud sync.');

    // 初始化 WebDAV 同步服务单例
    WebDAVSyncService.getInstance().initOnce(this.context);
    hilog.info(DOMAIN, TAG, 'WebDAVSyncService initialized.');

    // 初始化背诵设置管理器
    ReviewSettingsManager.getInstance().init(this.context);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    this.windowStage = windowStage;
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    // 确保数据库初始化完成后再加载页面。
    // 首次安装时 onCreate 中启动的 init() 可能尚未完成，
    // 此处 await initPromise 阻塞直到 DB 就绪。
    const dbManager = DatabaseManager.getInstance();
    await dbManager.init(this.context);
    hilog.info(DOMAIN, TAG, 'Database ready before loading HomePage.');

    // 加载 HomePage 作为默认页面
    windowStage.loadContent('pages/HomePage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });

    // 首次启动隐私弹窗（华为应用市场强制要求）
    this.showPrivacyDialogIfNeeded();
  }

  /**
   * 检查并展示首次启动隐私确认弹窗
   * 仅在用户未同意过隐私政策时展示
   */
  private showPrivacyDialogIfNeeded(): void {
    try {
      const pref = preferences.getPreferencesSync(this.context, { name: 'app_settings' });
      const hasAgreed: boolean = pref.getSync('privacy_agreed', false) as boolean;
      if (!hasAgreed) {
        this.privacyDialogController = new CustomDialogController({
          builder: PrivacyDialog({
            onAgree: () => {
              try {
                pref.putSync('privacy_agreed', true);
                pref.flush();
              } catch (err) {
                hilog.error(DOMAIN, TAG, 'Failed to save privacy consent: %{public}s', JSON.stringify(err));
              }
              hilog.info(DOMAIN, TAG, 'User agreed to privacy policy.');
            },
            onDisagree: () => {
              hilog.info(DOMAIN, TAG, 'User disagreed to privacy policy, exiting.');
              this.context.terminateSelf();
            },
            onViewDetail: () => {
              if (this.windowStage) {
                const mainWindow = this.windowStage.getMainWindowSync();
                if (mainWindow) {
                  mainWindow.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPolicyPage' })
                    .then(() => hilog.info(DOMAIN, TAG, 'Navigated to PrivacyPolicyPage'))
                    .catch((err: Error) => hilog.error(DOMAIN, TAG, 'Failed to navigate: %{public}s', err.message));
                }
              }
            }
          }),
          autoCancel: false,
          customStyle: true,
          alignment: DialogAlignment.Center
        });
        this.privacyDialogController.open();
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to show privacy dialog: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
    AppStorage.setOrCreate('isForeground', true);
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
    AppStorage.setOrCreate('isForeground', false);
  }
}
