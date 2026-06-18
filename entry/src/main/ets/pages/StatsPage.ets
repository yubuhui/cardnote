import { StudyViewModel, TodayStats, DayDetail, DayDetailRecord, OverviewStats, RatingDistribution, StreakInfo, MasteryProgress, DailyAccuracy, DifficultCard, DueForecast, DurationStats } from '../viewmodel/StudyViewModel';
import { DailyDuration } from '../data/MemoryRecordDao';
import { Deck } from '../model/Deck';

interface SegmentData {
  count: number;
  color: string;
}

@Component
export struct StatsPage {
  @State reviewDates: Set<number> = new Set();
  @State currentYear: number = new Date().getFullYear();
  @State currentMonth: number = new Date().getMonth() + 1;
  @State todayForget: number = 0;
  @State todayHard: number = 0;
  @State todayGood: number = 0;
  @State todayEasy: number = 0;
  @State dailyDurations: DailyDuration[] = [];
  @State selectedDay: number = 0;
  @State dayDetail: DayDetail | null = null;
  @State todayCards: DayDetailRecord[] = [];
  @StorageLink('dataVersion') @Watch('onDataVersionChange') dataVersion: number = 0;
  @State overview: OverviewStats | null = null;
  @State ratingDist: RatingDistribution | null = null;
  @State streak: StreakInfo | null = null;
  @State mastery: MasteryProgress | null = null;
  @State accuracyTrend: DailyAccuracy[] = [];
  @State difficultCards: DifficultCard[] = [];
  @State dueForecast: DueForecast | null = null;
  @State selectedDeckId: number = 0;
  @State decks: Deck[] = [];
  @State durationStats: DurationStats | null = null;
  private studyVm: StudyViewModel = new StudyViewModel();
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);

  aboutToAppear() {
    this.loadDecks();
    this.loadData();
    this.loadExtraStats();
  }

  async loadDecks() {
    try {
      this.decks = await this.studyVm.getAllDecks();
    } catch (err) {
      console.error('Load decks failed:', err);
    }
  }

  async loadData() {
    try {
      this.reviewDates = await this.studyVm.getReviewDatesForMonth(this.currentYear, this.currentMonth);
      const stats: TodayStats = await this.studyVm.getTodayStats();
      this.todayForget = stats.forget;
      this.todayHard = stats.hard;
      this.todayGood = stats.good;
      this.todayEasy = stats.easy;

      const today: Date = new Date();
      const dayDetail: DayDetail = await this.studyVm.getDayDetail(
        today.getFullYear(), today.getMonth() + 1, today.getDate()
      );
      this.todayCards = dayDetail.records;

      if (this.selectedDeckId === 0) {
        this.dailyDurations = await this.studyVm.getDailyDurations(7);
        this.overview = await this.studyVm.getOverviewStats();
      } else {
        this.dailyDurations = await this.studyVm.getDailyDurationsByDeck(7, this.selectedDeckId);
        this.overview = await this.studyVm.getOverviewStatsByDeck(this.selectedDeckId);
      }
    } catch (err) {
      console.error('Load stats failed:', err);
    }
  }

  async loadExtraStats() {
    try {
      if (this.selectedDeckId === 0) {
        this.ratingDist = await this.studyVm.getRatingDistribution();
        this.streak = await this.studyVm.getStreakInfo();
        this.mastery = await this.studyVm.getMasteryProgress();
        this.accuracyTrend = await this.studyVm.getDailyAccuracyTrend(7);
        this.difficultCards = await this.studyVm.getDifficultCards(10);
        this.dueForecast = await this.studyVm.getDueForecast();
        this.durationStats = await this.studyVm.getDurationStats();
      } else {
        this.ratingDist = await this.studyVm.getRatingDistributionByDeck(this.selectedDeckId);
        this.streak = await this.studyVm.getStreakInfo();
        this.mastery = await this.studyVm.getMasteryProgressByDeck(this.selectedDeckId);
        this.accuracyTrend = await this.studyVm.getDailyAccuracyTrendByDeck(7, this.selectedDeckId);
        this.difficultCards = await this.studyVm.getDifficultCardsByDeck(this.selectedDeckId, 10);
        this.dueForecast = await this.studyVm.getDueForecastByDeck(this.selectedDeckId);
        this.durationStats = await this.studyVm.getDurationStatsByDeck(this.selectedDeckId);
      }
    } catch (err) {
      console.error('Load extra stats failed:', err);
    }
  }

  private getDaysInMonth(year: number, month: number): number {
    return new Date(year, month, 0).getDate();
  }

  private getFirstDayOfWeek(year: number, month: number): number {
    return new Date(year, month - 1, 1).getDay();
  }

  private getCalendarDays(): number[] {
    const daysInMonth: number = this.getDaysInMonth(this.currentYear, this.currentMonth);
    const firstDay: number = this.getFirstDayOfWeek(this.currentYear, this.currentMonth);
    const totalCells: number = firstDay + daysInMonth;
    const rows: number = Math.ceil(totalCells / 7);
    const cells: number[] = [];

    for (let i: number = 0; i < rows * 7; i++) {
      if (i < firstDay || i >= firstDay + daysInMonth) {
        cells.push(0);
      } else {
        cells.push(i - firstDay + 1);
      }
    }
    return cells;
  }

  private isToday(day: number): boolean {
    const today: Date = new Date();
    return today.getFullYear() === this.currentYear &&
      today.getMonth() + 1 === this.currentMonth &&
      today.getDate() === day;
  }

  private prevMonth() {
    if (this.currentMonth === 1) {
      this.currentYear--;
      this.currentMonth = 12;
    } else {
      this.currentMonth--;
    }
    this.clearSelection();
    this.loadData();
  }

  private nextMonth() {
    if (this.currentMonth === 12) {
      this.currentYear++;
      this.currentMonth = 1;
    } else {
      this.currentMonth++;
    }
    this.clearSelection();
    this.loadData();
  }

  private clearSelection() {
    this.selectedDay = 0;
    this.dayDetail = null;
    this.loadTodayCards();
  }

  private async loadTodayCards(): Promise<void> {
    try {
      const today: Date = new Date();
      const dayDetail: DayDetail = await this.studyVm.getDayDetail(
        today.getFullYear(), today.getMonth() + 1, today.getDate()
      );
      this.todayCards = dayDetail.records;
    } catch (err) {
      console.error('Load today cards failed:', JSON.stringify(err));
    }
  }

  // 外部刷新信号触发
  onDataVersionChange() {
    this.loadDecks();
    this.loadData();
    this.loadExtraStats();
  }

  selectDeck(deckId: number) {
    if (this.selectedDeckId === deckId) {
      return;
    }
    this.selectedDeckId = deckId;
    this.loadData();
    this.loadExtraStats();
  }

  async selectDay(day: number) {
    if (!this.reviewDates.has(day)) {
      return;
    }
    this.selectedDay = day;
    this.dayDetail = null;
    try {
      this.dayDetail = await this.studyVm.getDayDetail(this.currentYear, this.currentMonth, day);
      this.todayCards = this.dayDetail.records;
    } catch (err) {
      console.error('Load day detail failed:', JSON.stringify(err));
    }
  }

  build() {
    Column() {
      // 顶部标题
      Row() {
        Text('学习统计')
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

      // ===== 牌组选择器 =====
      if (this.decks.length > 0) {
        this.buildDeckSelector()
      }

      Scroll() {
        Column() {
          // ===== 概览仪表盘 =====
          if (this.overview) {
            this.buildOverviewCards()
          }
          // ===== 进度与连续 =====
          if (this.mastery) {
            this.buildMasteryBar()
          }
          if (this.streak) {
            this.buildStreakInfo()
          }

          // 月份导航
          Row() {
            Text('◀')
              .fontSize(16)
              .fontColor($r('app.color.primary'))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick(() => { this.prevMonth() })

            Text(`${this.currentYear}年${this.currentMonth}月`)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
              .textAlign(TextAlign.Center)

            Text('▶')
              .fontSize(16)
              .fontColor($r('app.color.primary'))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick(() => { this.nextMonth() })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 10, bottom: 6 })

          // 日历主体
          Column() {
            // 星期标题行
            Row() {
              ForEach(['日', '一', '二', '三', '四', '五', '六'], (label: string) => {
                Text(label)
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .width('14.28%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 8, bottom: 6 })
              })
            }
            .width('100%')

            // 日期网格
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.getCalendarDays(), (day: number, index: number) => {
                if (day === 0) {
                  Column()
                    .width('14.28%')
                    .height(42)
                } else {
                  Column() {
                    Text(`${day}`)
                      .fontSize(14)
                      .fontColor(this.reviewDates.has(day) ? $r('app.color.on_primary') : $r('app.color.text_primary'))
                  }
                  .width('14.28%')
                  .height(42)
                  .justifyContent(FlexAlign.Center)
                  .borderRadius(21)
                  .backgroundColor(
                    this.selectedDay === day
                      ? $r('app.color.warning')
                      : (this.reviewDates.has(day) ? $r('app.color.primary') : $r('app.color.transparent'))
                  )
                  .border(
                    this.isToday(day) && !this.reviewDates.has(day)
                      ? { width: 1.5, color: $r('app.color.primary'), style: BorderStyle.Solid }
                      : {}
                  )
                  .onClick(() => { this.selectDay(day) })
                }
              }, (day: number, index: number) => index.toString())
            }
            .width('100%')
            .padding({ left: 2, right: 2, top: 4, bottom: 8 })
          }
          .width('100%')
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)
          .padding({ left: 6, right: 6, bottom: 6 })
          .margin({ left: 14, right: 14 })

          // 日详情面板
          if (this.dayDetail) {
            this.buildDayDetail()
          }

          // 今日评分统计
          Row() {
            Column() {
              Text(`${this.todayForget}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.danger'))
              Text('忘记')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
            .width('25%')
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text(`${this.todayHard}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.warning'))
              Text('困难')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
            .width('25%')
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text(`${this.todayGood}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.success'))
              Text('良好')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
            .width('25%')
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text(`${this.todayEasy}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.success'))
              Text('容易')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
            .width('25%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding({ top: 18, bottom: 18 })
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)
          .margin({ left: 14, right: 14, top: 12 })

          // ===== 评分分布圆环图 =====
          if (this.ratingDist && this.ratingDist.total > 0) {
            this.buildRatingDonut()
          }

          // ===== 待复习预报 =====
          if (this.dueForecast) {
            this.buildDueForecast()
          }

          // ===== 正确率趋势 =====
          if (this.accuracyTrend.length > 0) {
            this.buildAccuracyTrend()
          }

          // 学习时长柱状图
          this.buildDurationChart()

          // ===== 学习时长累计 =====
          if (this.durationStats) {
            this.buildDurationSummary()
          }

          // ===== 高难度卡片 =====
          if (this.difficultCards.length > 0) {
            this.buildDifficultCards()
          }

          // 今日学习卡片列表
          this.buildTodayCardList()

          // 底部留白，避免被悬浮Tab遮挡
          Blank().height(72)
        }
      }
      .align(Alignment.Top)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  buildDeckSelector() {
    Scroll() {
      Row() {
        Column() {
          Text('全部')
            .fontSize(12)
            .fontColor(this.selectedDeckId === 0 ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
        }
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor(this.selectedDeckId === 0 ? $r('app.color.primary') : $r('app.color.outline'))
        .onClick(() => { this.selectDeck(0) })
        .margin({ right: 8 })

        ForEach(this.decks, (deck: Deck, index: number) => {
          Column() {
            Text(deck.name)
              .fontSize(12)
              .fontColor(this.selectedDeckId === deck.id ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
          }
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .borderRadius(16)
          .backgroundColor(this.selectedDeckId === deck.id ? deck.color : $r('app.color.outline'))
          .onClick(() => { this.selectDeck(deck.id) })
          .margin({ right: 8 })
        }, (deck: Deck) => 'deck_' + deck.id.toString())
      }
      .padding({ left: 14, right: 14 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .margin({ top: 8, bottom: 4 })
  }

  @Builder
  buildDurationSummary() {
    Row() {
      Column() {
        Text(this.formatHours(this.durationStats!.totalHours))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary'))
        Text('总学习')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .width('33%')
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text(this.formatHours(this.durationStats!.weekHours))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.warning'))
        Text('本周')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .width('33%')
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text(this.formatHours(this.durationStats!.monthHours))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.success'))
        Text('本月')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .width('33%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 4 })
  }

  private formatHours(hours: number): string {
    return (Math.round(hours * 10) / 10).toString() + 'h';
  }

  @Builder
  buildOverviewCards() {
    Column() {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        Column() {
          Text(this.overview!.totalCards.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
          Text('总卡片')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .width('48%')
        .height(72)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(10)

        Column() {
          Text(this.overview!.masteredCards.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.success'))
          Text('已掌握')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .width('48%')
        .height(72)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(10)

        Column() {
          Text(this.overview!.dueToday.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.warning'))
          Text('今日待复习')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .width('48%')
        .height(72)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(10)
        .margin({ top: 10 })

        Column() {
          Text(this.overview!.totalReviews.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
          Text('累计复习')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .width('48%')
        .height(72)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(10)
        .margin({ top: 10 })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 4 })
  }

  @Builder
  buildMasteryBar() {
    Column() {
      Text('掌握进度')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 8 })

      Row() {
        if (this.mastery!.unlearned > 0) {
          Row()
            .width(this.calcPct(this.mastery!.unlearned) + '%')
            .height(20)
            .backgroundColor($r('app.color.outline'))
            .borderRadius({ topLeft: 4, bottomLeft: 4 })
        }
        if (this.mastery!.reviewing > 0) {
          Row()
            .width(this.calcPct(this.mastery!.reviewing) + '%')
            .height(20)
            .backgroundColor($r('app.color.warning'))
        }
        if (this.mastery!.mastered > 0) {
          Row()
            .width(this.calcPct(this.mastery!.mastered) + '%')
            .height(20)
            .backgroundColor($r('app.color.success'))
            .borderRadius({ topRight: 4, bottomRight: 4 })
        }
      }
      .width('100%')
      .height(20)
      .borderRadius(4)
      .backgroundColor($r('app.color.outline'))

      Row() {
        Text('未学习 ' + this.mastery!.unlearned.toString())
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
        Text('学习中 ' + this.mastery!.reviewing.toString())
          .fontSize(10)
          .fontColor($r('app.color.warning'))
        Text('已掌握 ' + this.mastery!.mastered.toString())
          .fontSize(10)
          .fontColor($r('app.color.success'))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 6 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 4 })
  }

  private calcPct(count: number): string {
    if (!this.mastery || this.mastery.total === 0) {
      return '0';
    }
    return Math.max(4, Math.round(count / this.mastery.total * 100)).toString();
  }

  @Builder
  buildStreakInfo() {
    Row() {
      Text('连续学习')
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
      Text(this.streak!.currentStreak.toString() + ' 天')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.warning'))
        .margin({ left: 8 })
      Text(' · 最长 ' + this.streak!.longestStreak.toString() + ' 天')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 10 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 4 })
  }

  @Builder
  buildRatingDonut() {
    Column() {
      Text('历史评分分布')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 10 })

      Row() {
        Canvas(this.canvasCtx)
          .width(100)
          .height(100)
          .onReady(() => {
            this.drawDonut();
          })

        Column() {
          this.donutLegendItem($r('app.color.danger'), '忘记', this.ratingDist!.forget, this.ratingDist!.total)
          this.donutLegendItem($r('app.color.warning'), '困难', this.ratingDist!.hard, this.ratingDist!.total)
          this.donutLegendItem($r('app.color.success'), '良好', this.ratingDist!.good, this.ratingDist!.total)
          this.donutLegendItem($r('app.color.primary'), '容易', this.ratingDist!.easy, this.ratingDist!.total)
        }
        .margin({ left: 20 })
        .layoutWeight(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 4 })
  }

  @Builder
  buildDueForecast() {
    Column() {
      Text('待复习预报')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 10 })

      Row() {
        Column() {
          Text(this.dueForecast!.day1.toString())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.warning'))
          Text('今天')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .width('33%')
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(this.dueForecast!.day3.toString())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
          Text('3 天内')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .width('33%')
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(this.dueForecast!.day7.toString())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.success'))
          Text('7 天内')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .width('33%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 4 })
  }

  @Builder
  buildAccuracyTrend() {
    Column() {
      Text('近 7 天正确率趋势（%）')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 10 })

      Row() {
        ForEach(this.accuracyTrend, (item: DailyAccuracy, index: number) => {
          Column() {
            Text(item.accuracy.toString())
              .fontSize(9)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 4 })

            Row()
              .width(22)
              .height(
                item.totalReviews > 0
                  ? Math.max(4, Math.min(100, item.accuracy))
                  : 4
              )
              .backgroundColor(
                item.totalReviews > 0
                  ? (item.accuracy >= 60 ? $r('app.color.success') : (item.accuracy >= 30 ? $r('app.color.warning') : $r('app.color.danger')))
                  : $r('app.color.outline')
              )
              .borderRadius(4)

            Text(item.dateLabel)
              .fontSize(9)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 6 })
              .maxLines(1)
          }
          .width('14.28%')
          .height(130)
          .justifyContent(FlexAlign.End)
          .alignItems(HorizontalAlign.Center)
        }, (item: DailyAccuracy, index: number) => item.dateLabel + '_acc_' + index.toString())
      }
      .width('100%')
      .height(130)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 4 })
  }

  @Builder
  buildDifficultCards() {
    Column() {
      Text('高难度卡片 Top 10')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 10 })

      ForEach(this.difficultCards, (item: DifficultCard, index: number) => {
        Row() {
          Text((index + 1).toString())
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_secondary'))
            .width(24)

          Column() {
            Text(item.cardFront)
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .width('100%')

            Row() {
              Row()
                .width(Math.round(item.forgetRate * 100).toString() + '%')
                .height(6)
                .backgroundColor($r('app.color.danger'))
                .borderRadius(3)
            }
            .width('100%')
            .height(6)
            .borderRadius(3)
            .backgroundColor($r('app.color.outline'))
            .margin({ top: 4 })
          }
          .layoutWeight(1)

          Text(Math.round(item.forgetRate * 100).toString() + '%')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.danger'))
            .width(40)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/LearningDetailPage',
            params: { cardId: item.cardId }
          });
        })

        if (index < this.difficultCards.length - 1) {
          Divider()
            .height(1)
            .color($r('app.color.outline'))
        }
      }, (item: DifficultCard) => 'diff_' + item.cardId.toString())
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 12 })
  }

  @Builder
  donutLegendItem(color: ResourceColor, label: string, count: number, total: number) {
    Row() {
      Row()
        .width(10)
        .height(10)
        .borderRadius(5)
        .backgroundColor(color)
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 6 })
      Text(Math.round(count / total * 100).toString() + '%')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ top: 3, bottom: 3 })
  }

  private drawDonut(): void {
    if (!this.ratingDist || this.ratingDist.total === 0) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.canvasCtx;
    const centerX: number = 50;
    const centerY: number = 50;
    const radius: number = 40;
    const lineWidth: number = 16;

    ctx.clearRect(0, 0, 100, 100);

    const seg0: SegmentData = { count: this.ratingDist.forget, color: '#E74C3C' };
    const seg1: SegmentData = { count: this.ratingDist.hard, color: '#F39C12' };
    const seg2: SegmentData = { count: this.ratingDist.good, color: '#2ECC71' };
    const seg3: SegmentData = { count: this.ratingDist.easy, color: '#4A90D9' };
    const segments: SegmentData[] = [seg0, seg1, seg2, seg3];

    let startAngle: number = -Math.PI / 2;
    const total: number = this.ratingDist.total;

    for (let i: number = 0; i < segments.length; i++) {
      const seg: SegmentData = segments[i];
      if (seg.count === 0) {
        continue;
      }
      const sweepAngle: number = (seg.count / total) * 2 * Math.PI;
      ctx.beginPath();
      ctx.arc(centerX, centerY, radius, startAngle, startAngle + sweepAngle);
      ctx.strokeStyle = seg.color;
      ctx.lineWidth = lineWidth;
      ctx.lineCap = 'butt';
      ctx.stroke();
      startAngle += sweepAngle;
    }
  }

  @Builder
  buildDurationChart() {
    Column() {
      Text('近 7 天学习时长（分钟）')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 10 })

      // 柱状图
      Row() {
        ForEach(this.dailyDurations, (item: DailyDuration, index: number) => {
          Column() {
            Row()
              .width(22)
              .height(
                item.totalSeconds > 0
                  ? Math.max(4, Math.min(100, (item.totalSeconds / 60) * 1.5))
                  : 4
              )
              .backgroundColor(item.totalSeconds > 0 ? $r('app.color.primary') : $r('app.color.outline'))
              .borderRadius(4)

            Text(item.dateLabel)
              .fontSize(9)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 6 })
              .maxLines(1)
          }
          .width('14.28%')
          .height(120)
          .justifyContent(FlexAlign.End)
          .alignItems(HorizontalAlign.Center)
        }, (item: DailyDuration, index: number) => item.dateLabel + index.toString())
      }
      .width('100%')
      .height(120)

      Row() {
        ForEach(this.dailyDurations, (item: DailyDuration, index: number) => {
          Text(
            item.totalSeconds > 0
              ? `${Math.round(item.totalSeconds / 60)}`
              : '-'
          )
            .fontSize(9)
            .fontColor(item.totalSeconds > 0 ? $r('app.color.primary') : $r('app.color.text_secondary'))
            .width('14.28%')
            .textAlign(TextAlign.Center)
        }, (item: DailyDuration, index: number) => item.dateLabel + '_num_' + index.toString())
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 12 })
  }

  @Builder
  buildTodayCardList() {
    Column() {
      Text('今日学习卡片')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 10 })

      if (this.todayCards.length === 0) {
        Text('今天还没有学习记录')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
      } else {
        ForEach(this.todayCards, (item: DayDetailRecord, index: number) => {
          Row() {
            Column() {
              Text(item.cardFront)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Start)
                .width('100%')

              if (item.durationSeconds > 0) {
                Text(`⏱ ${Math.round(item.durationSeconds / 60)} 分钟`)
                  .fontSize(10)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(item.resultLabel)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_primary'))
              .backgroundColor(item.resultColor)
              .borderRadius(4)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({
              url: 'pages/LearningDetailPage',
              params: { cardId: item.cardId }
            });
          })

          if (index < this.todayCards.length - 1) {
            Divider()
              .height(1)
              .color($r('app.color.outline'))
          }
        }, (item: DayDetailRecord) => `today_${item.cardId}_${item.durationSeconds}`)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 12 })
  }

  @Builder
  buildDayDetail() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Text(`${this.dayDetail!.dateLabel}`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(`${this.dayDetail!.totalReviews} 次复习 · 忘${this.dayDetail!.forgetCount} 难${this.dayDetail!.hardCount} 良${this.dayDetail!.goodCount} 易${this.dayDetail!.easyCount} · ${Math.round(this.dayDetail!.totalDurationSeconds / 60)} 分钟`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('✕')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 8, right: 4, top: 4, bottom: 4 })
          .onClick(() => { this.clearSelection() })
      }
      .width('100%')
      .margin({ bottom: 8 })

      Divider()
        .height(1)
        .color($r('app.color.outline'))
        .margin({ bottom: 6 })

      // 卡片列表
      ForEach(this.dayDetail!.records, (item: DayDetailRecord, index: number) => {
        Row() {
          Column() {
            Text(item.cardFront)
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .width('100%')

            if (item.durationSeconds > 0) {
              Text(`⏱ ${Math.round(item.durationSeconds / 60)} 分钟`)
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(item.resultLabel)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_primary'))
            .backgroundColor(item.resultColor)
            .borderRadius(4)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })

        if (index < this.dayDetail!.records.length - 1) {
          Divider()
            .height(1)
            .color($r('app.color.outline'))
        }
      }, (item: DayDetailRecord) => `${item.cardId}_${item.durationSeconds}`)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .margin({ top: 12 })
  }
}
