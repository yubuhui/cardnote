@CustomDialog
export struct WebdavEnableDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: WebdavEnableDialog() });
  onConfirm?: () => void;
  onCancel?: () => void;

  build() {
    Column() {
      Text('启用 WebDAV 同步')
        .fontSize($r('sys.float.ohos_id_text_size_body1'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 24, bottom: 16, left: 16, right: 16 })

      Text('WebDAV 同步将把您的牌组、卡片和学习记录上传至您指定的 WebDAV 服务器，实现跨设备数据备份与恢复。\n\n请确保：\n• 您已拥有可用的 WebDAV 服务器\n• 服务器使用 HTTPS 加密连接\n• 您妥善保管服务器访问凭证\n\n卡片笔记不会获取或存储您的服务器凭证及同步数据。使用本功能即表示您自愿承担相关风险。')
        .fontSize($r('sys.float.ohos_id_text_size_body2'))
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .lineHeight(22)
        .textAlign(TextAlign.Start)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })

      Divider().color($r('sys.color.ohos_id_color_list_separator')).strokeWidth(0.5)

      Row() {
        Button('取消')
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .flexGrow(1)
          .height(44)
          .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .borderRadius(0)
          .onClick(() => {
            if (this.onCancel) {
              this.onCancel();
            }
            this.controller.close();
          })

        Divider()
          .vertical(true)
          .color($r('sys.color.ohos_id_color_list_separator'))
          .strokeWidth(0.5)
          .height(44)

        Button('确认启用')
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .flexGrow(1)
          .height(44)
          .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .borderRadius(0)
          .onClick(() => {
            if (this.onConfirm) {
              this.onConfirm();
            }
            this.controller.close();
          })
      }
      .width('100%')
      .height(44)
    }
    .width('100%')
    .constraintSize({ maxWidth: 400 })
    .borderRadius($r('sys.float.padding_level10'))
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
    .clip(true)
    .padding(0)
  }
}
