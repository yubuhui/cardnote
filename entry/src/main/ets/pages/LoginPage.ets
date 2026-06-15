import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { HuaweiAuthService, HuaweiUserInfo } from '../service/HuaweiAuthService';
import { common } from '@kit.AbilityKit';

@Entry
@Component
export struct LoginPage {
  @State isLoading: boolean = false;
  @State unionID: string = '';
  @State openID: string = '';
  @State loginText: string = '未登录';
  @StorageLink('hwIsLoggedIn') isLoggedIn: boolean = false;
  private authService: HuaweiAuthService = HuaweiAuthService.getInstance();

  async aboutToAppear(): Promise<void> {
    const context: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    await this.authService.init(context);

    const loggedIn: boolean = this.authService.isLoggedIn();
    AppStorage.setOrCreate('hwIsLoggedIn', loggedIn);
    if (loggedIn) {
      this.loginText = '已登录';
      this.unionID = this.authService.getUnionID();
    }
  }

  private async handleLogin(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    const context: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;

    try {
      await this.authService.init(context);
      const userInfo: HuaweiUserInfo = await this.authService.login(context);

      if (userInfo.unionID) {
        AppStorage.setOrCreate('hwIsLoggedIn', true);
        this.unionID = userInfo.unionID;
        this.openID = userInfo.openID;
        this.loginText = '已登录';

        promptAction.showToast({ message: '华为账号登录成功' });
      }
    } catch (err) {
      const message: string = (err as Error).message;
      promptAction.showToast({ message: message });
    } finally {
      this.isLoading = false;
    }
  }

  private async handleLogout(): Promise<void> {
    try {
      await this.authService.logout();
      AppStorage.setOrCreate('hwIsLoggedIn', false);
      this.unionID = '';
      this.openID = '';
      this.loginText = '未登录';
      promptAction.showToast({ message: '已退出登录' });
    } catch (err) {
      console.error('退出登录失败:', JSON.stringify(err));
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Row() {
          Text('‹')
            .fontSize(22)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('#E0E0E0')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.back();
        })

        Text('华为账号')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 右侧占位，保证标题居中
        Row()
          .width(36)
          .height(36)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor($r('app.color.card_background'))

      Scroll() {
        Column() {
          // 账号状态区
          Column() {
            if (this.isLoggedIn) {
              // 已登录状态：显示账号信息
              Column() {
                Text('华为账号')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .margin({ bottom: 8 })

                Text('UnionID')
                  .fontSize(12)
                  .fontColor('#999')
                  .margin({ bottom: 4 })
                Text(this.unionID ? this.maskUnionID(this.unionID) : '')
                  .fontSize(13)
                  .fontColor('#666')
                  .margin({ bottom: 12 })

                Button('退出登录')
                  .fontSize(14)
                  .fontColor('#CE0E2D')
                  .backgroundColor('#FFEBEE')
                  .borderRadius(8)
                  .height(40)
                  .padding({ left: 20, right: 20 })
                  .onClick(() => {
                    this.handleLogout();
                  })
              }
              .width('100%')
              .padding(20)
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
            } else {
              // 未登录状态：显示登录入口
              Column() {
                Text('华为账号登录')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .margin({ bottom: 8 })

                Text('使用华为账号登录，同步您的背诵数据')
                  .fontSize(13)
                  .fontColor('#999')
                  .margin({ bottom: 16 })

                Button(this.isLoading ? '正在登录...' : '华为账号登录')
                  .fontSize(15)
                  .fontColor(Color.White)
                  .backgroundColor('#CE0E2D')
                  .borderRadius(8)
                  .width('100%')
                  .height(44)
                  .enabled(!this.isLoading)
                  .onClick(() => {
                    this.handleLogin();
                  })
              }
              .width('100%')
              .padding(20)
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
            }
          }
          .margin({ top: 10 })

          // 说明区域
          Column() {
            Text('说明')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 8 })

            Text('• 登录华为账号后，可获得用户唯一标识（UnionID），用于数据同步与备份。\n• 本功能仅获取账号标识，不会获取您的手机号、头像等隐私信息。\n• 登录后可在设置中随时退出。')
              .fontSize(12)
              .fontColor('#999')
              .lineHeight(20)
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(12)
          .margin({ top: 10 })
        }
        .padding({ left: 14, right: 14 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  /**
   * 对 UnionID 进行脱敏显示
   */
  private maskUnionID(id: string): string {
    if (id.length <= 8) {
      return id;
    }
    return id.substring(0, 4) + '****' + id.substring(id.length - 4);
  }
}
