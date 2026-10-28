import { AppData, Flag, TrendDay } from '../common/Models';
import { C } from '../common/Theme';
import { capitalize, digestiveLabel, fmtTime, greeting, hydrationLabel } from '../common/Format';
import { ScoreRing, TrendChart } from './Widgets';

const STOOL_HEX: Record<string, string> = {
  'Brown': '#8a5a3b',
  'Light brown': '#c08a5c',
  'Dark brown': '#4f3020',
  'Green-ish': '#6f7d3c',
  'Yellow': '#d4b44a',
  'Black': '#1d1714',
  'Red-tinged': '#9b3b32'
};
const QTY_LEVEL: Record<string, number> = { 'Small': 1, 'Medium': 2, 'Large': 3 };

@Styles
function card() {
  .width('100%')
  .padding(16)
  .borderRadius(20)
  .backgroundColor(C.CARD)
  .border({ width: 1, color: C.LINE })
}

@Component
export struct HomeTab {
  @Prop data: AppData | null = null;
  @Prop name: string = '';
  @Prop error: string = '';
  @Link refreshing: boolean;
  onReload: () => void = () => {
  };
  onGoto: (i: number) => void = (i: number) => {
  };
  private qtyBars: number[] = [10, 17, 24];

  stoolWhen(): string {
    return this.data !== null && this.data.stool !== null ? fmtTime(this.data.stool.ts) : 'No stool visit yet';
  }

  stoolColour(): string {
    return this.data !== null && this.data.stool !== null && this.data.stool.colour !== null ? this.data.stool.colour : 'Not measured';
  }

  stoolHex(): string {
    return STOOL_HEX[this.stoolColour()] ?? '#3a3156';
  }

  stoolType(): string {
    return this.data !== null && this.data.stool !== null ? `T${this.data.stool.bristol_type}` : '–';
  }

  stoolConsistency(): string {
    return this.data !== null && this.data.stool !== null ? this.data.stool.consistency : '–';
  }

  stoolQuantity(): string {
    return this.data !== null && this.data.stool !== null && this.data.stool.quantity !== null ? this.data.stool.quantity : 'Not measured';
  }

  qtyLevel(): number {
    return QTY_LEVEL[this.stoolQuantity()] ?? 0;
  }

  digScore(): number {
    return this.data !== null && this.data.digestive !== null ? this.data.digestive.score : -1;
  }

  hydScore(): number {
    return this.data !== null && this.data.hydration !== null ? this.data.hydration.score : -1;
  }

  digSub(): string {
    return this.data !== null && this.data.digestive !== null ? digestiveLabel(this.data.digestive.bristol_type) : 'No stool visit yet';
  }

  hydSub(): string {
    return this.data !== null && this.data.hydration !== null ? hydrationLabel(this.data.hydration.score) : 'No urine visit yet';
  }

  insight(): string {
    if (this.data === null) {
      return 'Loading your latest results…';
    }
    return this.data.insight ?? 'Your first toilet visit will appear here.';
  }

  flags(): Flag[] {
    return this.data === null ? [] : this.data.triage.flags;
  }

  level(): string {
    return this.data === null ? 'normal' : this.data.triage.level;
  }

  week(): TrendDay[] {
    return this.data === null ? [] : this.data.trend.slice(-7);
  }

  lastVisit(): string {
    if (this.data === null || this.data.last_ts === null) {
      return 'No visits recorded yet';
    }
    return `Last visit ${fmtTime(this.data.last_ts)} · ${this.data.visits} visits in 30 days`;
  }

  @Builder
  scoreCard(bg: string, score: number, ringColor: string, title: string, sub: string) {
    Column({ space: 4 }) {
      ScoreRing({ score: score, ringColor: ringColor })
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(C.INK)
        .margin({ top: 8 })
      Text(sub)
        .fontSize(12)
        .fontColor('#55607a')
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .padding({ top: 18, bottom: 14, left: 6, right: 6 })
    .borderRadius(22)
    .backgroundColor(bg)
  }

  @Builder
  stoolStat(label: string, value: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(12)
        .fontColor(C.MUTED)
        .margin({ top: 6 })
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(C.TEXT)
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  stoolCard() {
    Column({ space: 10 }) {
      Row() {
        Text('Last stool')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(C.MUTED)
        Blank()
        Text(this.stoolWhen())
          .fontSize(12)
          .fontColor(C.MUTED)
      }
      .width('100%')

      Row({ space: 8 }) {
        Column() {
          Stack() {
            Circle()
              .width(18)
              .height(18)
              .fill(this.stoolHex())
          }
          .width(30)
          .height(30)
          .borderRadius(10)
          .backgroundColor(C.MINT)

          this.stoolStat('Colour', this.stoolColour())
        }
        .layoutWeight(1)
        .padding({ top: 12, bottom: 12 })
        .borderRadius(16)
        .backgroundColor('#262046')

        Column() {
          Text(this.stoolType())
            .height(30)
            .padding({ left: 6, right: 6 })
            .borderRadius(10)
            .backgroundColor(C.MINT)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(C.INK)
          this.stoolStat('Consistency', this.stoolConsistency())
        }
        .layoutWeight(1)
        .padding({ top: 12, bottom: 12 })
        .borderRadius(16)
        .backgroundColor('#262046')

        Column() {
          Row({ space: 3 }) {
            ForEach(this.qtyBars, (h: number, i: number) => {
              Column()
                .width(8)
                .height(h)
                .borderRadius(3)
                .backgroundColor(i < this.qtyLevel() ? C.LIME : '#3a3156')
            }, (h: number) => `${h}`)
          }
          .height(30)
          .alignItems(VerticalAlign.Bottom)

          this.stoolStat('Quantity', this.stoolQuantity())
        }
        .layoutWeight(1)
        .padding({ top: 12, bottom: 12 })
        .borderRadius(16)
        .backgroundColor('#262046')
      }
      .width('100%')
    }
    .card()
  }

  build() {
    Refresh({ refreshing: $$this.refreshing }) {
      Scroll() {
        Column({ space: 14 }) {
          Row() {
            Column({ space: 2 }) {
              Text(greeting())
                .fontSize(15)
                .fontColor(C.MUTED)
              Text(this.name)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(C.TEXT)
            }
            .alignItems(HorizontalAlign.Start)

            Blank()
            Text(this.name.length > 0 ? this.name.charAt(0).toUpperCase() : '·')
              .width(40)
              .height(40)
              .borderRadius(20)
              .textAlign(TextAlign.Center)
              .backgroundColor(C.CREAM)
              .fontColor(C.INK)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .onClick(() => {
                this.onGoto(3);
              })
          }
          .width('100%')
          .margin({ top: 6, bottom: 4 })

          if (this.error.length > 0) {
            Text(this.error)
              .fontSize(13)
              .fontColor(C.RED)
              .card()
          }

          Row({ space: 12 }) {
            this.scoreCard(C.MINT, this.digScore(), C.INK, 'Digestive Score', this.digSub())
            this.scoreCard(C.CREAM, this.hydScore(), C.BLUE, 'Hydration Score', this.hydSub())
          }
          .width('100%')

          Column({ space: 6 }) {
            Text("Today's insight")
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#a7d63c')
            Text(this.insight())
              .fontSize(16)
              .lineHeight(24)
              .fontColor(C.TEXT)
          }
          .alignItems(HorizontalAlign.Start)
          .card()

          this.stoolCard()

          if (this.flags().length > 0) {
            Column({ space: 6 }) {
              Text(this.level() === 'consult' ? 'ALERT! Unusual pattern detected' : 'Heads up: something changed')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.level() === 'consult' ? C.RED : C.AMBER)
              ForEach(this.flags(), (f: Flag) => {
                Text('• ' + capitalize(f.detail))
                  .fontSize(15)
                  .lineHeight(22)
                  .fontColor(C.TEXT)
              }, (f: Flag) => f.code)
              Text('See details →')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(C.LIME)
                .margin({ top: 4 })
                .onClick(() => {
                  this.onGoto(2);
                })
            }
            .alignItems(HorizontalAlign.Start)
            .card()
            .backgroundColor('#2a1730')
            .border({ width: 1, color: '#5a2a3a' })
          }

          Column({ space: 4 }) {
            Row() {
              Text('Last 7 days')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(C.MUTED)
              Blank()
              Circle().width(8).height(8).fill(C.MINT)
              Text(' Digestive  ')
                .fontSize(12)
                .fontColor(C.MUTED)
              Circle().width(8).height(8).fill(C.LIME)
              Text(' Hydration')
                .fontSize(12)
                .fontColor(C.MUTED)
            }
            .width('100%')

            TrendChart({ days: this.week() })
          }
          .card()

          Text(this.lastVisit())
            .fontSize(12)
            .fontColor(C.MUTED)
            .margin({ top: 4, bottom: 96 })
        }
        .padding({ left: 18, right: 18, top: 12 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .onRefreshing(() => {
      this.onReload();
    })
  }
}
