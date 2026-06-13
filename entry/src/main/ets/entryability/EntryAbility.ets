import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { DatabaseManager } from '../data/DatabaseManager';
import { ReviewSettingsManager } from '../data/ReviewSettingsManager';
import { PrivacyDialog } from '../components/PrivacyDialog';

const DOMAIN = 0x0001;
const TAG = 'CardNote';

export default class EntryAbility extends UIAbility {
  private privacyDialogController: CustomDialogController | null = null;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    // 从偏好中读取深色模式设置
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

    // 初始化背诵设置管理器
    ReviewSettingsManager.getInstance().init(this.context);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    // 确保数据库已初始化（防御性检查，onCreate 中已完成初始化）
    await DatabaseManager.getInstance().init(this.context);

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
              // 不关闭弹窗，直接导航到隐私政策页面
              // 用户返回后，弹窗仍在等待确认
              router.pushUrl({ url: 'pages/PrivacyPolicyPage' })
                .then(() => hilog.info(DOMAIN, TAG, 'Navigated to PrivacyPolicyPage'))
                .catch((err: Error) => hilog.error(DOMAIN, TAG, 'Failed to navigate: %{public}s', err.message));
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
