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
    try {
      const pref = preferences.getPreferencesSync(this.context, { name: 'app_settings' });
      const followSystem = pref.getSync('follow_system', true) as boolean;
      const darkMode = pref.getSync('dark_mode', false) as boolean;
      if (!followSystem) {
        if (darkMode) {
          this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
        } else {
          this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
        }
      }
      AppStorage.setOrCreate('currentColorMode',
        followSystem ? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
          : (darkMode ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/HomePage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });

    const pref = preferences.getPreferencesSync(this.context, { name: 'app_settings' });
    const hasAgreed: boolean = pref.getSync('privacy_agreed', false) as boolean;

    if (hasAgreed) {
      this.initServices();
    } else {
      this.showPrivacyDialogIfNeeded();
    }
  }

  private async initServices(): Promise<void> {
    const dbManager = DatabaseManager.getInstance();
    await dbManager.init(this.context);
    await dbManager.fillMissingUuids();
    await dbManager.setupCloudSync();
    hilog.info(DOMAIN, TAG, 'Database initialized with cloud sync.');

    WebDAVSyncService.getInstance().initOnce(this.context);
    hilog.info(DOMAIN, TAG, 'WebDAVSyncService initialized.');

    ReviewSettingsManager.getInstance().init(this.context);
  }

  private showPrivacyDialogIfNeeded(): void {
    try {
      this.privacyDialogController = new CustomDialogController({
        builder: PrivacyDialog({
          onAgree: async () => {
            try {
              const pref = preferences.getPreferencesSync(this.context, { name: 'app_settings' });
              pref.putSync('privacy_agreed', true);
              pref.flush();
            } catch (err) {
              hilog.error(DOMAIN, TAG, 'Failed to save privacy consent: %{public}s', JSON.stringify(err));
            }
            hilog.info(DOMAIN, TAG, 'User agreed to privacy policy.');
            await this.initServices();
          },
          onDisagree: () => {
            hilog.info(DOMAIN, TAG, 'User disagreed to privacy policy, exiting.');
            this.context.terminateSelf();
          }
        }),
        autoCancel: false,
        customStyle: true,
        alignment: DialogAlignment.Center
      });
      this.privacyDialogController.open();
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
