import { router } from '@kit.ArkUI';
import { ReviewSettingsManager, ReviewSettings } from '../data/ReviewSettingsManager';

/**
 * 背诵设置项
 */
interface ReviewSettingItem {
  label: string;
  key: string;
  value: number;
  unit?: string;
  min?: number;
  max?: number;
  step?: number;
}

@Entry
@Component
struct ReviewSettingsPage {
  @State dailyNewCards: number = 20;
  @State dailyReviewCards: number = 100;
  @State sm2Factor: number = 250;
  @State skipMasteredCards: boolean = false;
  private newCardRange: string[] = [];
  private reviewCardRange: string[] = [];
  private sm2Range: string[] = [];
  private settingsManager: ReviewSettingsManager = ReviewSettingsManager.getInstance();

  @State settings: ReviewSettingItem[] = [
    { label: '每日新卡数量', key: 'daily_new_cards', value: 20, unit: '张', min: 5, max: 200, step: 5 },
    { label: '每日复习卡数量', key: 'daily_review_cards', value: 100, unit: '张', min: 50, max: 1000, step: 50 },
    { label: 'SM-2算法倍率', key: 'sm2_factor', value: 250, unit: '%', min: 50, max: 400, step: 25 },
  ];

  aboutToAppear(): void {
    // 从持久化加载设置
    const saved: ReviewSettings = this.settingsManager.load();
    this.dailyNewCards = saved.dailyNewCards;
    this.dailyReviewCards = saved.dailyReviewCards;
    this.sm2Factor = saved.sm2Factor;
    this.skipMasteredCards = saved.skipMasteredCards;

    // 每日新卡范围: 5, 10, 15, ..., 200
    for (let i = 5; i <= 200; i += 5) {
      this.newCardRange.push(i.toString());
    }
    // 每日复习范围: 50, 100, 150, ..., 1000
    for (let i = 50; i <= 1000; i += 50) {
      this.reviewCardRange.push(i.toString());
    }
    // SM-2 倍率范围: 50, 75, 100, ..., 400
    for (let i = 50; i <= 400; i += 25) {
      this.sm2Range.push(i.toString());
    }
  }

  /** 持久化当前设置 */
  private persist(): void {
    this.settingsManager.save({
      dailyNewCards: this.dailyNewCards,
      dailyReviewCards: this.dailyReviewCards,
      sm2Factor: this.sm2Factor,
      skipMasteredCards: this.skipMasteredCards,
    });
  }

  /** 计算新卡当前值在 range 中的索引 */
  private getIndexForValue(val: number): number {
    let idx = Math.round((val - 5) / 5);
    if (idx < 0) { idx = 0; }
    if (idx >= this.newCardRange.length) { idx = this.newCardRange.length - 1; }
    return idx;
  }

  /** 弹出每日新卡数量选择器 */
  private showNewCardPicker(): void {
    TextPickerDialog.show({
      range: this.newCardRange,
      selected: this.getIndexForValue(this.dailyNewCards),
      onAccept: (result: TextPickerResult) => {
        this.dailyNewCards = parseInt(result.value as string);
        this.persist();
      }
    });
  }

  /** 计算复习卡当前值在 range 中的索引 */
  private getReviewIndexForValue(val: number): number {
    let idx = Math.round((val - 50) / 50);
    if (idx < 0) { idx = 0; }
    if (idx >= this.reviewCardRange.length) { idx = this.reviewCardRange.length - 1; }
    return idx;
  }

  /** 弹出每日复习卡数量选择器 */
  private showReviewCardPicker(): void {
    TextPickerDialog.show({
      range: this.reviewCardRange,
      selected: this.getReviewIndexForValue(this.dailyReviewCards),
      onAccept: (result: TextPickerResult) => {
        this.dailyReviewCards = parseInt(result.value as string);
        this.persist();
      }
    });
  }

  /** 计算 SM-2 倍率当前值在 range 中的索引 */
  private getSm2IndexForValue(val: number): number {
    let idx = Math.round((val - 50) / 25);
    if (idx < 0) { idx = 0; }
    if (idx >= this.sm2Range.length) { idx = this.sm2Range.length - 1; }
    return idx;
  }

  /** 弹出 SM-2 算法倍率选择器 */
  private showSm2Picker(): void {
    TextPickerDialog.show({
      range: this.sm2Range,
      selected: this.getSm2IndexForValue(this.sm2Factor),
      onAccept: (result: TextPickerResult) => {
        this.sm2Factor = parseInt(result.value as string);
        this.persist();
      }
    });
  }

  /** 恢复默认设置 */
  private resetDefaults(): void {
    this.dailyNewCards = 20;
    this.dailyReviewCards = 100;
    this.sm2Factor = 250;
    this.skipMasteredCards = false;
    this.persist();
  }

  build() {
    Column() {
      // 第一层：返回 + 标题
      Row() {
        Row() {
          Text('‹')
            .fontSize(22)
            .fontColor('#1A1A1A')
            .textAlign(TextAlign.Center)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('#E0E0E0')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => router.back())

        Text('背诵设置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 右侧占位，保证标题居中
        Row()
          .width(36)
          .height(36)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 46, bottom: 12 })
      .backgroundColor(Color.White)

      // 第二层：内容区
      Scroll() {
        Column() {
          ForEach(this.settings, (item: ReviewSettingItem, index: number) => {
            Row() {
              Column() {
                Text(item.label)
                  .fontSize(14)
                  .fontColor('#333')
              }

              Blank()

              Row() {
                Text(index === 0 ? this.dailyNewCards.toString() :
                     index === 1 ? this.dailyReviewCards.toString() :
                     index === 2 ? this.sm2Factor.toString() :
                     item.value.toString())
                  .fontSize(14)
                  .fontColor('#4A90D9')
                  .fontWeight(FontWeight.Medium)
                if (item.unit) {
                  Text(item.unit)
                    .fontSize(12)
                    .fontColor('#999')
                    .margin({ left: 4 })
                }
                Text('›')
                  .fontSize(16)
                  .fontColor('#CCC')
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .padding({ top: 14, bottom: 14 })
            .border({ width: { bottom: 1 }, color: '#f5f5f5' })
            .onClick(() => {
              if (index === 0) {
                this.showNewCardPicker();
              } else if (index === 1) {
                this.showReviewCardPicker();
              } else if (index === 2) {
                this.showSm2Picker();
              }
            })

            // 在「每日复习卡数量」后插入开关
            if (index === 1) {
              Row() {
                Text('不背诵已掌握的卡片')
                  .fontSize(14)
                  .fontColor('#333')
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.skipMasteredCards })
                  .onChange((value: boolean) => {
                    this.skipMasteredCards = value;
                    this.persist();
                  })
              }
              .width('100%')
              .padding({ top: 14, bottom: 14 })
              .border({ width: { bottom: 1 }, color: '#f5f5f5' })
            }

            // SM-2 倍率说明（跟随该行）
            if (index === 2) {
              Text('倍率越高，答对后的复习间隔增长越快，卡片出现频率越低；倍率越低，间隔增长越慢，卡片复习更频繁。默认为 250%，建议范围 150%~300%。')
                .fontSize(12)
                .fontColor('#999')
                .lineHeight(18)
                .padding({ top: 0, bottom: 12, left: 4, right: 4 })
            }
          }, (item: ReviewSettingItem) => item.key)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .borderRadius(12)
        .margin({ top: 12 })
      }
      .align(Alignment.Top)
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 12, right: 12 })

      // 底部恢复默认按钮
      Column() {
        Button('恢复默认')
          .fontSize(14)
          .fontColor('#4A90D9')
          .backgroundColor(Color.White)
          .width('100%')
          .height(44)
          .borderRadius(12)
          .onClick(() => this.resetDefaults())
      }
      .padding({ left: 12, right: 12, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }
}
