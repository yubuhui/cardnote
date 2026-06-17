/**
 * 首次启动隐私政策确认弹窗
 * 华为应用市场强制要求：首次启动必须弹窗告知隐私政策并获得用户同意
 */
@CustomDialog
export struct PrivacyDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: PrivacyDialog() });
  onAgree?: () => void;
  onDisagree?: () => void;
  onViewDetail?: () => void;
  onViewUserAgreement?: () => void;

  build() {
    Column() {
      // 标题
      Text('隐私政策提示')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 24, bottom: 16 })

      // 概要说明
      Column() {
        Text('欢迎使用卡片笔记！\n\n为了更好地保障您的权益，请阅读我们的')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
        Text('《隐私政策》')
          .fontSize(14)
          .fontColor($r('app.color.primary'))
          .decoration({ type: TextDecorationType.Underline })
          .onClick(() => {
            if (this.onViewDetail) {
              this.onViewDetail();
            }
          })
        Text(' 和 ')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
        Text('《用户协议》')
          .fontSize(14)
          .fontColor($r('app.color.primary'))
          .decoration({ type: TextDecorationType.Underline })
          .onClick(() => {
            if (this.onViewUserAgreement) {
              this.onViewUserAgreement();
            }
          })
        Text('了解我们如何收集、使用和保护您的个人信息。\n\n如您同意，请点击"同意"开始使用；如您不同意，我们将无法为您提供服务。')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
      }
      .padding(12)
      .borderRadius(8)
      .backgroundColor($r('app.color.surface'))
      .margin({ left: 16, right: 16, bottom: 20 })
      .alignItems(HorizontalAlign.Start)

      // 按钮区
      Row() {
        Button('不同意')
          .fontSize(15)
          .flexGrow(1)
          .height(42)
          .backgroundColor($r('app.color.surface'))
          .fontColor($r('app.color.text_secondary'))
          .borderRadius(8)
          .onClick(() => {
            if (this.onDisagree) {
              this.onDisagree();
            }
            this.controller.close();
          })

        Button('同意并继续')
          .fontSize(15)
          .flexGrow(2)
          .height(42)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .borderRadius(8)
          .margin({ left: 12 })
          .onClick(() => {
            if (this.onAgree) {
              this.onAgree();
            }
            this.controller.close();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 20 })
    }
    .width('100%')
    .borderRadius(16)
    .backgroundColor($r('app.color.surface'))
    .padding(0)
  }
}
