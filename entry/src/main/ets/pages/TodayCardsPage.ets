import { StudyViewModel, DayDetailRecord } from '../viewmodel/StudyViewModel';

@Entry
@Component
struct TodayCardsPage {
  @State cards: DayDetailRecord[] = [];
  @StorageLink('dataVersion') @Watch('onDataVersionChange') dataVersion: number = 0;
  private deckId: number = 0;
  private studyVm: StudyViewModel = new StudyViewModel();

  aboutToAppear() {
    const raw = this.getUIContext().getRouter().getParams();
    if (raw !== undefined && typeof raw === 'object') {
      const params = raw as Record<string, Object>;
      if (params['deckId'] !== undefined) {
        this.deckId = params['deckId'] as number;
      }
    }
    this.loadData();
  }

  onPageShow() {
    this.loadData();
  }

  onDataVersionChange() {
    this.loadData();
  }

  async loadData() {
    try {
      if (this.deckId === 0 || this.deckId === undefined) {
        this.cards = await this.studyVm.getAllTodayCards();
      } else {
        this.cards = await this.studyVm.getAllTodayCardsByDeck(this.deckId);
      }
    } catch (err) {
      console.error('Load today cards failed:' + JSON.stringify(err));
    }
  }

  @Builder
  buildPageHeader(title: string) {
    Row() {
      Text('<')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .width(36)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })

      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 46, bottom: 12 })
    .backgroundColor($r('app.color.surface'))
  }

  build() {
    Column() {
      this.buildPageHeader('今日学习卡片')

      Scroll() {
        Column() {
          if (this.cards.length === 0) {
            Column() {
              Text('今天还没有学习记录')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding({ top: 80, bottom: 80 })
            }
            .width('100%')
          } else {
            ForEach(this.cards, (item: DayDetailRecord, index: number) => {
              Row() {
                Column() {
                  Text(item.cardFront)
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .textAlign(TextAlign.Start)
                    .width('100%')

                  if (item.durationSeconds > 0) {
                    Text('⏱ ' + Math.round(item.durationSeconds / 60).toString() + ' 分钟')
                      .fontSize(11)
                      .fontColor($r('app.color.text_secondary'))
                      .margin({ top: 4 })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(item.resultLabel)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.on_primary'))
                  .backgroundColor(item.resultColor)
                  .borderRadius(4)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              }
              .width('100%')
              .padding({ top: 14, bottom: 14 })
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({
                  url: 'pages/LearningDetailPage',
                  params: { cardId: item.cardId }
                });
              })

              if (index < this.cards.length - 1) {
                Divider()
                  .height(1)
                  .color($r('app.color.outline'))
              }
            }, (item: DayDetailRecord) => 'today_' + item.cardId.toString() + '_' + item.durationSeconds.toString())
          }

          Blank().height(24)
        }
      }
      .align(Alignment.Top)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
