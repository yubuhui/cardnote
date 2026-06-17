
@Entry
@Component
struct PrivacyPolicyPage {
  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('‹')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .width(36)
          .onClick(() => {
          this.getUIContext().getRouter().back();
        })
        Text('隐私政策')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        // 占位保持居中
        Row().width(36)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 46, bottom: 12 })
      .backgroundColor($r('app.color.surface'))

      // 正文区域
      Scroll() {
        Column() {
          Text() {
            Span('更新日期：2026年6月17日\n')
            Span('生效日期：2026年6月17日\n\n')
            Span('卡片笔记')
              .fontWeight(FontWeight.Bold)
            Span('（以下简称"我们"）深知个人信息对您的重要性，我们将按照法律法规的规定，保护您的个人信息及隐私安全。本隐私政策适用于卡片笔记应用程序（以下简称"本应用"）所提供的服务。\n\n')
            Span('1. 我们收集的信息\n')
              .fontWeight(FontWeight.Bold)
              .decoration({ type: TextDecorationType.Underline })
            Span('本应用是一款本地优先的卡片背诵工具，所有数据默认存储在您的设备本地。我们不会主动收集、上传或分享您的任何个人信息。\n\n')
            Span('当您主动使用以下可选功能时，相关数据将遵循对应隐私规则：\n')
            Span('• WebDAV 同步：')
              .fontWeight(FontWeight.Bold)
            Span('您通过自建或第三方 WebDAV 服务器进行数据备份与同步时，数据仅在您的设备与您指定的服务器之间传输，我们不会接触或存储这些数据。\n\n')
            Span('2. 我们如何使用信息\n')
              .fontWeight(FontWeight.Bold)
              .decoration({ type: TextDecorationType.Underline })
            Span('本应用无需联网即可完整使用，不依赖任何云端服务进行数据收集。您在使用 WebDAV 同步功能时产生的网络通信仅用于数据传输，不包含任何额外的数据采集行为。\n\n')
            Span('3. 信息的存储与安全\n')
              .fontWeight(FontWeight.Bold)
              .decoration({ type: TextDecorationType.Underline })
            Span('• 所有背诵数据（牌组、卡片、学习记录等）均存储于您的设备本地。\n')
            Span('• 我们不运营任何自有服务器，不会在第三方服务器上存储您的个人信息。\n')
            Span('• 设备本地数据受 HarmonyOS 系统安全机制保护。\n\n')
            Span('4. 第三方服务\n')
              .fontWeight(FontWeight.Bold)
              .decoration({ type: TextDecorationType.Underline })
            Span('本应用本身不集成任何第三方 SDK 或服务。WebDAV 同步功能依赖您自行提供的 WebDAV 服务器，该服务器由您或第三方运营，其隐私政策请参阅对应服务提供方的说明。\n\n')
            Span('5. 您的权利\n')
              .fontWeight(FontWeight.Bold)
              .decoration({ type: TextDecorationType.Underline })
            Span('• 您可以随时通过应用内的删除功能清理您的本地数据。\n')
            Span('• 您可以通过系统设置管理本应用的存储权限。\n\n')
            Span('6. 未成年人保护\n')
              .fontWeight(FontWeight.Bold)
              .decoration({ type: TextDecorationType.Underline })
            Span('本应用面向所有年龄段用户。如您是未成年人，请在监护人的陪同下阅读')
            Span('《隐私政策》')
              .fontWeight(FontWeight.Bold)
            Span('并征得同意后使用本应用。\n\n')
            Span('7. 隐私政策的更新\n')
              .fontWeight(FontWeight.Bold)
              .decoration({ type: TextDecorationType.Underline })
            Span('我们可能会适时更新本隐私政策。当政策发生重大变更时，我们会在应用内以显著的方式通知您。\n\n')
            Span('8. 联系我们\n')
              .fontWeight(FontWeight.Bold)
              .decoration({ type: TextDecorationType.Underline })
            Span('如您对本隐私政策有任何疑问、意见或建议，请通过以下方式联系我们：\n')
            Span('• 应用内：设置页面 → 关于 → 联系我们\n\n')
            Span('本政策最终解释权归')
            Span('卡片笔记')
              .fontWeight(FontWeight.Bold)
            Span('开发者所有。')
          }
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(22)
          .padding(16)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .width('100%')
      .backgroundColor($r('app.color.background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }
}
