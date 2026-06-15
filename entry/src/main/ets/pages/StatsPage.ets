import { router } from '@kit.ArkUI';
import { StudyViewModel, TodayStats, DayDetail, DayDetailRecord } from '../viewmodel/StudyViewModel';
import { DailyDuration } from '../data/MemoryRecordDao';

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
  @Consume('statsRefreshSignal') @Watch('onStatsRefresh') remoteRefreshSignal: number = 0;
  private studyVm: StudyViewModel = new StudyViewModel();

  aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    try {
      this.reviewDates = await this.studyVm.getReviewDatesForMonth(this.currentYear, this.currentMonth);
      const stats: TodayStats = await this.studyVm.getTodayStats();
      this.todayForget = stats.forget;
      this.todayHard = stats.hard;
      this.todayGood = stats.good;
      this.todayEasy = stats.easy;
      this.dailyDurations = await this.studyVm.getDailyDurations(7);

      // 加载今日学习卡片列表
      const today: Date = new Date();
      const dayDetail: DayDetail = await this.studyVm.getDayDetail(
        today.getFullYear(), today.getMonth() + 1, today.getDate()
      );
      this.todayCards = dayDetail.records;
    } catch (err) {
      console.error('Load stats failed:', err);
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
  }

  // 外部刷新信号触发
  onStatsRefresh() {
    this.loadData();
  }

  async selectDay(day: number) {
    if (!this.reviewDates.has(day)) {
      return;
    }
    this.selectedDay = day;
    this.dayDetail = null;
    try {
      this.dayDetail = await this.studyVm.getDayDetail(this.currentYear, this.currentMonth, day);
    } catch (err) {
      console.error('Load day detail failed:', JSON.stringify(err));
    }
  }

  build() {
    Column() {
      // 顶部标题
      Text('学习统计')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 46, bottom: 12 })
        .backgroundColor(Color.White)

      Scroll() {
        Column() {
          // 月份导航
          Row() {
            Text('◀')
              .fontSize(16)
              .fontColor('#4A90D9')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick(() => { this.prevMonth() })

            Text(`${this.currentYear}年${this.currentMonth}月`)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)

            Text('▶')
              .fontSize(16)
              .fontColor('#4A90D9')
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
                  .fontColor('#999')
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
                      .fontColor(this.reviewDates.has(day) ? Color.White : '#333')
                  }
                  .width('14.28%')
                  .height(42)
                  .justifyContent(FlexAlign.Center)
                  .borderRadius(21)
                  .backgroundColor(
                    this.selectedDay === day
                      ? '#FF9800'
                      : (this.reviewDates.has(day) ? '#4A90D9' : Color.Transparent)
                  )
                  .border(
                    this.isToday(day) && !this.reviewDates.has(day)
                      ? { width: 1.5, color: '#4A90D9', style: BorderStyle.Solid }
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
          .backgroundColor(Color.White)
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
                .fontColor('#E74C3C')
              Text('忘记')
                .fontSize(11)
                .fontColor('#999')
                .margin({ top: 2 })
            }
            .width('25%')
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text(`${this.todayHard}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F39C12')
              Text('困难')
                .fontSize(11)
                .fontColor('#999')
                .margin({ top: 2 })
            }
            .width('25%')
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text(`${this.todayGood}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#2ECC71')
              Text('良好')
                .fontSize(11)
                .fontColor('#999')
                .margin({ top: 2 })
            }
            .width('25%')
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text(`${this.todayEasy}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#27AE60')
              Text('容易')
                .fontSize(11)
                .fontColor('#999')
                .margin({ top: 2 })
            }
            .width('25%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding({ top: 18, bottom: 18 })
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ left: 14, right: 14, top: 12 })

          // 学习时长柱状图
          this.buildDurationChart()

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
    .backgroundColor('#F5F6FA')
  }

  @Builder
  buildDurationChart() {
    Column() {
      Text('近 7 天学习时长（分钟）')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
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
              .backgroundColor(item.totalSeconds > 0 ? '#4A90D9' : '#E0E0E0')
              .borderRadius(4)

            Text(item.dateLabel)
              .fontSize(9)
              .fontColor('#999')
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
            .fontColor(item.totalSeconds > 0 ? '#4A90D9' : '#CCC')
            .width('14.28%')
            .textAlign(TextAlign.Center)
        }, (item: DailyDuration, index: number) => item.dateLabel + '_num_' + index.toString())
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ left: 14, right: 14, top: 12 })
  }

  @Builder
  buildTodayCardList() {
    Column() {
      Text('今日学习卡片')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333')
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 10 })

      if (this.todayCards.length === 0) {
        Text('今天还没有学习记录')
          .fontSize(12)
          .fontColor('#999')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
      } else {
        ForEach(this.todayCards, (item: DayDetailRecord, index: number) => {
          Row() {
            Column() {
              Text(item.cardFront)
                .fontSize(13)
                .fontColor('#333')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Start)
                .width('100%')

              if (item.durationSeconds > 0) {
                Text(`⏱ ${Math.round(item.durationSeconds / 60)} 分钟`)
                  .fontSize(10)
                  .fontColor('#999')
                  .margin({ top: 2 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(item.resultLabel)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor(item.resultColor)
              .borderRadius(4)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .onClick(() => {
            router.pushUrl({
              url: 'pages/LearningDetailPage',
              params: { cardId: item.cardId }
            });
          })

          if (index < this.todayCards.length - 1) {
            Divider()
              .height(1)
              .color('#F5F5F5')
          }
        }, (item: DayDetailRecord, index: number) => `today_${item.cardId}_${index}`)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
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
            .fontColor('#333')
          Text(`${this.dayDetail!.totalReviews} 次复习 · 忘${this.dayDetail!.forgetCount} 难${this.dayDetail!.hardCount} 良${this.dayDetail!.goodCount} 易${this.dayDetail!.easyCount} · ${Math.round(this.dayDetail!.totalDurationSeconds / 60)} 分钟`)
            .fontSize(12)
            .fontColor('#666')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('✕')
          .fontSize(16)
          .fontColor('#999')
          .padding({ left: 8, right: 4, top: 4, bottom: 4 })
          .onClick(() => { this.clearSelection() })
      }
      .width('100%')
      .margin({ bottom: 8 })

      Divider()
        .height(1)
        .color('#F0F0F0')
        .margin({ bottom: 6 })

      // 卡片列表
      ForEach(this.dayDetail!.records, (item: DayDetailRecord, index: number) => {
        Row() {
          Column() {
            Text(item.cardFront)
              .fontSize(13)
              .fontColor('#333')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .width('100%')

            if (item.durationSeconds > 0) {
              Text(`⏱ ${Math.round(item.durationSeconds / 60)} 分钟`)
                .fontSize(10)
                .fontColor('#999')
                .margin({ top: 2 })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(item.resultLabel)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor(item.resultColor)
            .borderRadius(4)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })

        if (index < this.dayDetail!.records.length - 1) {
          Divider()
            .height(1)
            .color('#F5F5F5')
        }
      }, (item: DayDetailRecord, index: number) => `${item.cardId}_${index}`)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ top: 12 })
  }
}
