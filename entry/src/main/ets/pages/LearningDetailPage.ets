import { Card } from '../model/Card';
import { CardType, CardStatus } from '../model/CardTypeEnum';
import { CardViewModel } from '../viewmodel/CardViewModel';
import { StudyViewModel, CardReviewRecord } from '../viewmodel/StudyViewModel';
import { parseFillBlanks, TextSegment } from '../utils/FillBlankParser';
import { TreeDiagramView } from '../components/TreeDiagramView';

@Entry
@Component
struct LearningDetailPage {
  @State card: Card | null = null;
  @State reviewHistory: CardReviewRecord[] = [];
  @State showMenu: boolean = false;
  @StorageLink('dataVersion') @Watch('onDataVersionChange') dataVersion: number = 0;
  private cardId: number = 0;
  private cardVm: CardViewModel = new CardViewModel();
  private studyVm: StudyViewModel = new StudyViewModel();

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params && params['cardId'] !== undefined) {
      this.cardId = params['cardId'] as number;
    }
    this.loadCard();
  }

  onPageShow() {
    this.loadCard();
  }

  onDataVersionChange() {
    this.loadCard();
  }

  async loadCard() {
    try {
      this.card = await this.cardVm.getById(this.cardId);
      this.reviewHistory = await this.studyVm.getCardReviewHistory(this.cardId);
    } catch (err) {
      console.error('Load card failed:', err);
    }
  }

  build() {
    Column() {
      // 顶部标题栏
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
        .backgroundColor($r('app.color.surface'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })

        Text('学习详情')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('⋮')
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 4, right: 4 })
          .onClick(() => {
            this.showMenu = !this.showMenu;
          })
          .bindPopup(this.showMenu, {
            builder: this.buildDropdownMenu,
            placement: Placement.BottomRight,
            maskColor: $r('app.color.transparent'),
            popupColor: $r('app.color.surface'),
            enableArrow: false,
            radius: 10,
            onStateChange: (e) => {
              if (!e.isVisible) {
                this.showMenu = false;
              }
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 18, right: 18, top: 46, bottom: 10 })
      .backgroundColor($r('app.color.surface'))

      if (this.card) {
        Scroll() {
          Column() {
            this.buildCardDetail()
            this.buildReviewHistory()
          }
        }
        .align(Alignment.Top)
        .layoutWeight(1)
      } else {
        Column()
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  buildDropdownMenu() {
    Column() {
      Row() {
        Text('编辑卡片')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .onClick(() => {
        this.showMenu = false;
        this.goToEditCard();
      })

      Divider()
        .height(1)
        .color($r('app.color.outline'))
        .margin({ left: 14, right: 14 })

      Row() {
        Text('清除数据')
          .fontSize(13)
          .fontColor($r('app.color.danger'))
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .onClick(() => {
        this.showMenu = false;
        this.confirmClearData();
      })
    }
    .width(140)
    .padding({ top: 4, bottom: 4 })
  }

  goToEditCard() {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/EditorPage',
      params: { cardId: this.cardId }
    });
  }

  confirmClearData() {
    this.getUIContext().showAlertDialog({
      title: '清除学习数据',
      message: '将删除该卡片的所有记忆记录，并重置学习进度。确定继续吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '确定',
        fontColor: $r('app.color.danger'),
        action: async () => {
          await this.studyVm.resetCardData(this.cardId);
          await this.loadCard();
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: $r('app.color.text_secondary'),
        action: () => {}
      }
     });
   }

  @Builder
  buildCardDetail() {
    Column() {
      Text('卡片详情')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      if (this.card!.type === CardType.essay) {
        this.buildEssayCard()
      } else if (this.card!.type === CardType.choice) {
        this.buildChoiceCard()
      } else if (this.card!.type === CardType.fillBlank) {
        this.buildFillBlankCard()
      }
    }
    .width('100%')
    .margin({ left: 14, right: 14, top: 12 })
  }

  // ===== 问答题 =====
  @Builder
  buildEssayCard() {
    Column({ space: 12 }) {
      // 问题
      Column() {
        Text('问题')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')
          .margin({ bottom: 6 })
        Text(this.card!.front)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(24)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.background'))
      .borderRadius(10)

      // 答案
      Column() {
        Text('答案')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')
          .margin({ bottom: 6 })
        TreeDiagramView({
          content: this.card!.correctAnswer,
          fontSize: 15,
          fontWeight: FontWeight.Medium,
          fontColor: $r('app.color.text_primary'),
          lineHeight: 24,

        })
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.success_bg'))
      .borderRadius(10)

      // 解析（可选）
      if (this.card!.analysis) {
        this.buildAnalysis()
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.shadow'), offsetX: 0, offsetY: 4 })
  }

  // ===== 选择题 =====
  @Builder
  buildChoiceCard() {
    Column({ space: 12 }) {
      // 题干
      Column() {
        Text('选择题')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')
          .margin({ bottom: 6 })
        Text(this.card!.front)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(24)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.background'))
      .borderRadius(10)

      // 答案
      Column() {
        Text('答案')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')
          .margin({ bottom: 6 })
        Text(this.getChoiceAnswerText())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(24)
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.success_bg'))
      .borderRadius(10)

      // 选项列表（正确答案高亮为绿色）
      if (this.card!.options && this.card!.options.length > 0) {
        Column({ space: 8 }) {
          Text('选项')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Start)
            .width('100%')
            .margin({ bottom: 2 })

          ForEach(this.getOrderedOptions(), (opt: string, idx: number) => {
            this.buildChoiceOption(opt, idx)
          }, (ignored: string, idx: number): string => `${this.card!.id}_${idx}`)
        }
        .width('100%')
      }

      // 解析（可选）
      if (this.card!.analysis) {
        this.buildAnalysis()
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.shadow'), offsetX: 0, offsetY: 4 })
  }

  @Builder
  buildChoiceOption(opt: string, idx: number) {
    Row() {
      Text(String.fromCharCode(65 + idx) + '.')
        .fontSize(13)
        .fontColor(this.isOptionCorrect(idx) ? $r('app.color.success') : $r('app.color.text_secondary'))
        .fontWeight(this.isOptionCorrect(idx) ? FontWeight.Bold : FontWeight.Normal)
        .width(28)
        .textAlign(TextAlign.Start)

      Text(opt)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .borderRadius(8)
    .border({
      width: this.isOptionCorrect(idx) ? 1.5 : 0.5,
      color: this.isOptionCorrect(idx) ? $r('app.color.outline') : $r('app.color.outline')
    })
    .backgroundColor(this.isOptionCorrect(idx) ? $r('app.color.success_bg') : $r('app.color.surface'))
  }

  // ===== 填空题 =====
  @Builder
  buildFillBlankCard() {
    Column({ space: 12 }) {
      // 题干（含挖空 - 已填充答案）
      Column() {
        Text('填空题')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')
          .margin({ bottom: 6 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(
            parseFillBlanks(this.card!.front),
            (seg: TextSegment, index: number) => {
              if (seg.isBlank) {
                Text(seg.text)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.primary'))
                  .backgroundColor($r('app.color.surface'))
                  .borderRadius(4)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .margin({ left: 2, right: 2 })
              } else {
                Text(seg.text)
                  .fontSize(15)
                  .fontColor($r('app.color.text_primary'))
                  .lineHeight(24)
              }
            },
            (ignoredSeg: TextSegment, index: number): string => index.toString()
          )
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.background'))
      .borderRadius(10)

      // 答案
      Column() {
        Text('答案')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')
          .margin({ bottom: 6 })
        TreeDiagramView({
          content: this.card!.correctAnswer,
          fontSize: 15,
          fontWeight: FontWeight.Medium,
          fontColor: $r('app.color.text_primary'),
          lineHeight: 24,

        })
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.success_bg'))
      .borderRadius(10)

      // 解析（可选）
      if (this.card!.analysis) {
        this.buildAnalysis()
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.shadow'), offsetX: 0, offsetY: 4 })
  }

  // ===== 共享：解析板块 =====
  @Builder
  buildAnalysis() {
    Column() {
      Text('解析')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Start)
        .width('100%')
        .margin({ bottom: 6 })
      TreeDiagramView({
        content: this.card!.analysis,
        fontSize: 13,
        fontWeight: FontWeight.Normal,
        fontColor: $r('app.color.text_secondary'),
        lineHeight: 20
      })
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.warning_bg'))
    .borderRadius(10)
  }

  // ===== 复习历史板块 =====
  @Builder
  buildReviewHistory() {
    Column() {
      Text('复习历史')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      if (this.reviewHistory.length === 0) {
        Text('暂无复习记录')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
      } else {
        // 统计概览
        Row() {
          this.buildStatItem('开始学习', this.getFirstStudyDate(), $r('app.color.text_secondary'))
          this.buildStatItem('已掌握', this.getMasteredDate(), $r('app.color.success'))
          this.buildStatItem('间隔', this.getStudyDuration(), $r('app.color.primary'))
          this.buildStatItem('总时长', this.getTotalStudyTime(), $r('app.color.warning'))
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 8, right: 8, top: 4, bottom: 12 })

        Divider()
          .height(1)
          .color($r('app.color.outline'))
          .margin({ bottom: 4 })

        // 历史列表
        ForEach(this.reviewHistory, (record: CardReviewRecord, index: number) => {
          Column() {
            Row() {
              // 左侧：时间
              Column() {
                Text(this.formatDate(record.date))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .textAlign(TextAlign.Start)

                if (record.durationSeconds > 0) {
                  Text(`⏱ ${Math.round(record.durationSeconds / 60)} 分钟`)
                    .fontSize(10)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 2 })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              // 右侧：评分标签
              Text(record.resultLabel)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.surface'))
                .backgroundColor(record.resultColor)
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })

            if (index < this.reviewHistory.length - 1) {
              Divider()
                .height(1)
                .color($r('app.color.outline'))
            }
          }
          .width('100%')
        }, (record: CardReviewRecord) => `${record.date}`)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 12, bottom: 20 })
  }

  /** 统计指标项 */
  @Builder
  buildStatItem(label: string, value: string, color: ResourceColor) {
    Column() {
      Text(label)
        .fontSize(10)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ bottom: 3 })
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
        .textAlign(TextAlign.Center)
    }
  }

  // ===== 历史统计方法 =====

  /** 最早学习日期 */
  private getFirstStudyDate(): string {
    if (this.reviewHistory.length === 0) {
      return '暂无数据';
    }
    const first: CardReviewRecord = this.reviewHistory[this.reviewHistory.length - 1];
    const d: Date = new Date(first.date);
    return `${d.getMonth() + 1}/${d.getDate()}`;
  }

  /** 掌握日期（若已掌握则显示最后记录日期，否则显示 -） */
  private getMasteredDate(): string {
    if (this.reviewHistory.length === 0) {
      return '未掌握';
    }
    if (this.card!.status !== CardStatus.mastered) return '未掌握';
    const latest: CardReviewRecord = this.reviewHistory[0];
    const d: Date = new Date(latest.date);
    return `${d.getMonth() + 1}/${d.getDate()}`;
  }

  /** 从首学到掌握的日历间隔 */
  private getStudyDuration(): string {
    if (this.reviewHistory.length === 0) {
      return '暂无数据';
    }
    const first: number = this.reviewHistory[this.reviewHistory.length - 1].date;
    if (this.card!.status === CardStatus.mastered) {
      const mastered: number = this.reviewHistory[0].date;
      const days: number = Math.round((mastered - first) / 86400000);
      return `${days} 天`;
    }
    const elapsedDays: number = Math.floor((Date.now() - first) / 86400000);
    return `${elapsedDays} 天`;
  }

  /** 累计学习总时长 */
  private getTotalStudyTime(): string {
    let total: number = 0;
    for (const r of this.reviewHistory) {
      total += r.durationSeconds;
    }
    if (total < 60) return `${total} 秒`;
    return `${Math.round(total / 60)} 分钟`;
  }

  /** 格式化时间戳为 yyyy/MM/dd HH:mm */
  private formatDate(timestamp: number): string {
    const d: Date = new Date(timestamp);
    const year: number = d.getFullYear();
    const month: string = (d.getMonth() + 1).toString().padStart(2, '0');
    const day: string = d.getDate().toString().padStart(2, '0');
    const hours: string = d.getHours().toString().padStart(2, '0');
    const minutes: string = d.getMinutes().toString().padStart(2, '0');
    return `${year}/${month}/${day} ${hours}:${minutes}`;
  }

  // ===== 选择题工具方法 =====

  /** 按 displayOrder 排序的选项数组 */
  private getOrderedOptions(): string[] {
    if (!this.card) return [];
    if (!this.card.displayOrder || this.card.displayOrder.length === 0) {
      return this.card.options || [];
    }
    const ordered: string[] = [];
    for (let i = 0; i < this.card.displayOrder.length; i++) {
      const originalIdx: number = this.card.displayOrder[i];
      if (originalIdx < this.card.options.length) {
        ordered.push(this.card.options[originalIdx]);
      }
    }
    return ordered;
  }

  /** 正确答案的原始索引数组 */
  private getCorrectIndices(): number[] {
    const ca: string = this.card!.correctAnswer;
    if (!ca || ca.trim().length === 0) return [];
    const result: number[] = [];
    const parts: string[] = ca.split(',');
    for (let i = 0; i < parts.length; i++) {
      const n: number = parseInt(parts[i].trim());
      if (!isNaN(n)) result.push(n);
    }
    return result;
  }

  /** 指定位置的选项是否为正确答案 */
  private isOptionCorrect(idx: number): boolean {
    const displayOrder: number[] = this.card!.displayOrder;
    let originalIdx: number = idx;
    if (displayOrder && displayOrder.length > 0 && idx < displayOrder.length) {
      originalIdx = displayOrder[idx];
    }
    const correctIndices: number[] = this.getCorrectIndices();
    for (let i = 0; i < correctIndices.length; i++) {
      if (correctIndices[i] === originalIdx) return true;
    }
    return false;
  }

  /** 获取选择题答案的显示文本 */
  private getChoiceAnswerText(): string {
    const correctIndices: number[] = this.getCorrectIndices();
    if (correctIndices.length === 0) {
      return this.card!.correctAnswer;
    }
    const options: string[] = this.card!.options || [];
    const texts: string[] = [];
    for (let i = 0; i < correctIndices.length; i++) {
      const origIdx: number = correctIndices[i];
      if (origIdx < options.length) {
        texts.push(options[origIdx]);
      }
    }
    return texts.length > 0 ? texts.join('；') : this.card!.correctAnswer;
  }
}
