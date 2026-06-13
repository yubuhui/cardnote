import { preferences } from '@kit.ArkData';

const PREF_NAME: string = 'app_settings';
const KEY_DAILY_NEW: string = 'daily_new_cards';
const KEY_DAILY_REVIEW: string = 'daily_review_cards';
const KEY_SM2_FACTOR: string = 'sm2_factor';
const KEY_SKIP_MASTERED: string = 'skip_mastered_cards';

const DEFAULT_DAILY_NEW: number = 20;
const DEFAULT_DAILY_REVIEW: number = 100;
const DEFAULT_SM2_FACTOR: number = 250; // 百分比，如 250 代表 250% = 2.5
const DEFAULT_SKIP_MASTERED: boolean = false;

/** 背诵设置 */
export interface ReviewSettings {
  dailyNewCards: number;
  dailyReviewCards: number;
  /** 倍率百分比，如 250 代表 250% = 2.5 */
  sm2Factor: number;
  skipMasteredCards: boolean;
}

export class ReviewSettingsManager {
  private static instance: ReviewSettingsManager;
  private pref: preferences.Preferences | null = null;

  private constructor() {}

  static getInstance(): ReviewSettingsManager {
    if (!ReviewSettingsManager.instance) {
      ReviewSettingsManager.instance = new ReviewSettingsManager();
    }
    return ReviewSettingsManager.instance;
  }

  /** 初始化（在 Ability 中调用一次，传入 context） */
  init(context: Context): void {
    if (this.pref) {
      return;
    }
    this.pref = preferences.getPreferencesSync(context, { name: PREF_NAME });
  }

  /** 从持久化读取设置 */
  load(): ReviewSettings {
    if (!this.pref) {
      return this.getDefaults();
    }
    try {
      return {
        dailyNewCards: (this.pref.getSync(KEY_DAILY_NEW, DEFAULT_DAILY_NEW) as number),
        dailyReviewCards: (this.pref.getSync(KEY_DAILY_REVIEW, DEFAULT_DAILY_REVIEW) as number),
        sm2Factor: (this.pref.getSync(KEY_SM2_FACTOR, DEFAULT_SM2_FACTOR) as number),
        skipMasteredCards: (this.pref.getSync(KEY_SKIP_MASTERED, DEFAULT_SKIP_MASTERED) as boolean),
      };
    } catch (err) {
      console.error('ReviewSettingsManager load failed:', JSON.stringify(err));
      return this.getDefaults();
    }
  }

  /** 持久化保存设置 */
  save(settings: ReviewSettings): void {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(KEY_DAILY_NEW, settings.dailyNewCards);
      this.pref.putSync(KEY_DAILY_REVIEW, settings.dailyReviewCards);
      this.pref.putSync(KEY_SM2_FACTOR, settings.sm2Factor);
      this.pref.putSync(KEY_SKIP_MASTERED, settings.skipMasteredCards);
      this.pref.flush();
    } catch (err) {
      console.error('ReviewSettingsManager save failed:', JSON.stringify(err));
    }
  }

  /** 获取默认值 */
  getDefaults(): ReviewSettings {
    return {
      dailyNewCards: DEFAULT_DAILY_NEW,
      dailyReviewCards: DEFAULT_DAILY_REVIEW,
      sm2Factor: DEFAULT_SM2_FACTOR,
      skipMasteredCards: DEFAULT_SKIP_MASTERED,
    };
  }
}
