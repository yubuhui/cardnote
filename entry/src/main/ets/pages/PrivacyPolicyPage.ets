
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
          Text(`更新日期：2026年6月13日

生效日期：2026年6月13日

CardNote（以下简称"我们"）深知个人信息对您的重要性，我们将按照法律法规的规定，保护您的个人信息及隐私安全。本隐私政策适用于CardNote应用程序（以下简称"本应用"）所提供的服务。

1. 我们收集的信息
为提供云端数据同步服务，我们会在您主动登录华为账号后收集以下信息：
• 华为账号OpenID：用于标识您的账号身份，实现跨设备数据同步。
• 应用数据（牌组、卡片、学习记录）：通过华为云空间进行端云同步，数据仅存储在您的个人华为云空间中，我们不会将数据上传至任何第三方服务器。

2. 我们如何使用信息
• 华为账号OpenID：仅用于华为账号认证与云同步账号关联。
• 应用数据：仅用于实现您在多个华为设备间的牌组、卡片及学习记录同步功能。

3. 信息的存储与安全
• 应用数据通过HarmonyOS端云同步能力加密存储于您的华为云空间，我们不会在自有服务器上存储您的任何个人信息。
• 我们采取了数据加密传输及存储等安全措施保护您的信息安全。

4. 第三方服务
本应用集成了华为账号服务（Account Kit）和华为云空间服务（CloudData），以提供登录认证与数据同步功能。上述服务的隐私政策请参阅华为官方隐私声明。

5. 您的权利
• 您可以在应用"设置"页面随时登录或退出华为账号，退出后云同步功能将停止。
• 您可以通过系统设置管理本应用对云空间的访问权限。
• 您可以通过应用"设置"中的"联系我们"获取数据删除等相关支持。

6. 未成年人保护
本应用面向所有年龄段用户。如您是未成年人，请在监护人的陪同下阅读本隐私政策并征得同意后使用本应用。

7. 隐私政策的更新
我们可能会适时更新本隐私政策。当政策发生重大变更时，我们会在应用内以显著的方式通知您。

8. 联系我们
如您对本隐私政策有任何疑问、意见或建议，请通过以下方式联系我们：
• 邮箱：请在个人中心设置中查看联系邮箱（如有）
• 应用内：设置页面 → 关于 → 联系我们

本政策最终解释权归CardNote开发者所有。`)
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(22)
            .padding(16)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('app.color.background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }
}
