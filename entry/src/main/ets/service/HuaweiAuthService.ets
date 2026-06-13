import { authentication } from '@kit.AccountKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME: string = 'huawei_auth';
const KEY_UNION_ID: string = 'union_id';
const KEY_OPEN_ID: string = 'open_id';
const KEY_IS_LOGGED_IN: string = 'is_logged_in';

/**
 * 华为账号用户信息
 */
export class HuaweiUserInfo {
  unionID: string = '';
  openID: string = '';
  authorizationCode: string = '';
  idToken: string = '';
}

/**
 * 华为账号认证服务
 * 使用 Account Kit 的 authentication 模块实现华为账号登录
 */
export class HuaweiAuthService {
  private static instance: HuaweiAuthService;

  private authPref: preferences.Preferences | null = null;

  static getInstance(): HuaweiAuthService {
    if (!HuaweiAuthService.instance) {
      HuaweiAuthService.instance = new HuaweiAuthService();
    }
    return HuaweiAuthService.instance;
  }

  /**
   * 初始化偏好存储
   */
  async init(context: common.Context): Promise<void> {
    if (!this.authPref) {
      this.authPref = preferences.getPreferencesSync(context, { name: PREF_NAME });
    }
  }

  /**
   * 检查是否已登录
   */
  isLoggedIn(): boolean {
    if (!this.authPref) {
      return false;
    }
    return this.authPref.getSync(KEY_IS_LOGGED_IN, false) as boolean;
  }

  /**
   * 获取存储的 UnionID
   */
  getUnionID(): string {
    if (!this.authPref) {
      return '';
    }
    return this.authPref.getSync(KEY_UNION_ID, '') as string;
  }

  /**
   * 华为账号登录
   * @param context UIAbilityContext
   * @returns Promise<HuaweiUserInfo>
   */
  async login(context: common.UIAbilityContext): Promise<HuaweiUserInfo> {
    return new Promise<HuaweiUserInfo>((resolve, reject) => {
      try {
        const loginRequest = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
        // forceLogin=true: 未登录华为账号时强制拉起登录页面
        loginRequest.forceLogin = true;
        loginRequest.state = util.generateRandomUUID();

        const controller = new authentication.AuthenticationController(context);
        controller.executeRequest(loginRequest).then((data) => {
          const response = data as authentication.LoginWithHuaweiIDResponse;
          const credential = response.data;
          if (!credential) {
            reject(new Error('登录失败：未获取到凭据'));
            return;
          }

          const userInfo = new HuaweiUserInfo();
          userInfo.unionID = credential.unionID ?? '';
          userInfo.openID = credential.openID ?? '';
          userInfo.authorizationCode = credential.authorizationCode ?? '';
          userInfo.idToken = credential.idToken ?? '';

          // 持久化保存登录状态
          this.saveLoginState(userInfo);
          resolve(userInfo);
        }).catch((error: BusinessError) => {
          reject(new Error(`登录失败 [${error.code}]: ${error.message}`));
        });
      } catch (error) {
        const err = error as BusinessError;
        reject(new Error(`登录失败 [${err.code}]: ${err.message}`));
      }
    });
  }

  /**
   * 退出登录（清除本地登录状态）
   */
  async logout(): Promise<void> {
    try {
      if (this.authPref) {
        this.authPref.putSync(KEY_IS_LOGGED_IN, false);
        this.authPref.putSync(KEY_UNION_ID, '');
        this.authPref.putSync(KEY_OPEN_ID, '');
        this.authPref.flush();
      }
    } catch (err) {
      console.error('清除登录状态失败:', JSON.stringify(err));
    }
  }

  /**
   * 静默登录（不拉起登录页，检查当前华为账号状态）
   */
  async silentLogin(context: common.UIAbilityContext): Promise<HuaweiUserInfo | null> {
    return new Promise<HuaweiUserInfo | null>((resolve) => {
      try {
        const loginRequest = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
        loginRequest.forceLogin = false;
        loginRequest.state = util.generateRandomUUID();

        const controller = new authentication.AuthenticationController(context);
        controller.executeRequest(loginRequest).then((data) => {
          const response = data as authentication.LoginWithHuaweiIDResponse;
          const credential = response.data;
          if (!credential) {
            resolve(null);
            return;
          }
          const userInfo = new HuaweiUserInfo();
          userInfo.unionID = credential.unionID ?? '';
          userInfo.openID = credential.openID ?? '';
          this.saveLoginState(userInfo);
          resolve(userInfo);
        }).catch(() => {
          resolve(null);
        });
      } catch (_err) {
        resolve(null);
      }
    });
  }

  /**
   * 持久化保存登录状态
   */
  private saveLoginState(userInfo: HuaweiUserInfo): void {
    try {
      if (this.authPref) {
        this.authPref.putSync(KEY_IS_LOGGED_IN, true);
        this.authPref.putSync(KEY_UNION_ID, userInfo.unionID);
        this.authPref.putSync(KEY_OPEN_ID, userInfo.openID);
        this.authPref.flush();
      }
    } catch (err) {
      console.error('保存登录状态失败:', JSON.stringify(err));
    }
  }
}
