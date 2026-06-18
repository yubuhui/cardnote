import { StudyViewModel, DifficultCard } from '../viewmodel/StudyViewModel';

@Entry
@Component
struct CardDifficultyPage {
  @State cards: DifficultCard[] = [];
  @StorageLink('dataVersion') @Watch('onDataVersionChange') dataVersion: number = 0;
  private deckId: number = 0;
  private studyVm: StudyViewModel = new StudyViewModel();

  aboutToAppear() {
    const params: Record<string, Object> | undefined = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params && params['deckId'] !== undefined) {
      this.deckId = params['deckId'] as number;
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
        this.cards = await this.studyVm.getAllDifficultCards();
      } else {
        this.cards = await this.studyVm.getAllDifficultCardsByDeck(this.deckId);
      }
    } catch (err) {
      console.error('Load difficulty cards failed:', err);
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .width(36)
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })

        Text('卡片难度排行')
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

      Scroll() {
        Column() {
          if (this.cards.length === 0) {
            Column() {
              Text('暂无难度数据，需要更多复习记录')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding({ top: 80, bottom: 80 })
            }
            .width('100%')
          } else {
            ForEach(this.cards, (item: DifficultCard, index: number) => {
              Column() {
                Row() {
                  Text((index + 1).toString())
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(index < 3 ? $r('app.color.warning') : $r('app.color.text_secondary'))
                    .width(28)
                    .textAlign(TextAlign.Center)

                  Column() {
                    Text(item.cardFront)
                      .fontSize(14)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.Start)
                      .width('100%')

                    Text('忘记 ' + item.forgetCount.toString() + ' 次 / 总复习 ' + item.totalReviews.toString() + ' 次')
                      .fontSize(11)
                      .fontColor($r('app.color.text_secondary'))
                      .margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(Math.round(item.forgetRate * 100).toString() + '%')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.danger'))
                    .width(46)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
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
              }
              .width('100%')
              .padding({ left: 14, right: 14 })
            }, (item: DifficultCard) => 'rank_' + item.cardId.toString())
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
