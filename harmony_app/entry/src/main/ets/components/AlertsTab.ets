import { AppData, Flag, Visit } from '../common/Models';
import { C, levelColor } from '../common/Theme';
import { capitalize, flagTitle, fmtTime, levelText } from '../common/Format';

@Styles
function card() {
  .width('100%')
  .padding(16)
  .borderRadius(20)
  .backgroundColor(C.CARD)
  .border({ width: 1, color: C.LINE })
}

@Component
export struct AlertsTab {
  @Prop data: AppData | null = null;
  private rules: string[][] = [
    ['Personal baseline.', ' Gas readings are compared with your own last 14 days, so your normal is the reference.'],
    ['Persistence rule.', ' A single odd day never alerts. A signal must stay unusual for 3 days in a row.'],
    ['Fixed rules decide the level.', ' Normal / Watch / Consult comes from deterministic rules, and the AI only explains it.']
  ];

  level(): string {
    return this.data === null ? 'normal' : this.data.triage.level;
  }

  flags(): Flag[] {
    return this.data === null ? [] : this.data.triage.flags;
  }

  visits(): Visit[] {
    return this.data === null ? [] : this.data.recent.slice(0, 10);
  }

  visitText(v: Visit): string {
    const bits: string[] = [];
    if (v.has_stool && v.bristol_type !== null) {
      bits.push(`Stool · Type ${v.bristol_type}`);
    }
    if (v.has_urine && v.hydration_score !== null) {
      bits.push(`Hydration ${v.hydration_score}`);
    }
    return bits.length > 0 ? bits.join(' · ') : 'Visit recorded';
  }

  @Builder
  flagCard(color: string, title: string, detail: string) {
    Row({ space: 12 }) {
      Column()
        .width(4)
        .alignSelf(ItemAlign.Stretch)
        .borderRadius(4)
        .backgroundColor(color)
      Column({ space: 4 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.TEXT)
        Text(detail)
          .fontSize(14)
          .fontColor(C.MUTED)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .card()
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('Alerts')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.TEXT)
          .width('100%')
          .margin({ top: 10 })
        Text("Compared with your own baseline, not other people's")
          .fontSize(14)
          .fontColor(C.MUTED)
          .width('100%')

        Row({ space: 14 }) {
          Text(this.level().toUpperCase())
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(C.INK)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(levelColor(this.level()))
          Text(levelText(this.level()))
            .fontSize(15)
            .fontColor(C.TEXT)
            .layoutWeight(1)
        }
        .card()
        .margin({ top: 6 })

        if (this.flags().length === 0) {
          this.flagCard(C.GREEN, 'No active alerts', 'Keep using PeekaPoo as usual; it watches in the background.')
        }
        ForEach(this.flags(), (f: Flag) => {
          this.flagCard(levelColor(f.level), flagTitle(f.code), capitalize(f.detail) + '.')
        }, (f: Flag) => f.code)

        Column({ space: 8 }) {
          Text('How alerts work')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(C.MUTED)
          ForEach(this.rules, (r: string[], i: number) => {
            Text() {
              Span(`${i + 1}. `)
              Span(r[0]).fontWeight(FontWeight.Bold)
              Span(r[1])
            }
            .fontSize(14)
            .lineHeight(20)
            .fontColor('#d7d3ec')
          }, (r: string[]) => r[0])
        }
        .alignItems(HorizontalAlign.Start)
        .card()

        Text('Recent visits')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(C.TEXT)
          .width('100%')
          .margin({ top: 10 })
        Column() {
          ForEach(this.visits(), (v: Visit) => {
            Row({ space: 12 }) {
              Text(fmtTime(v.start_ts))
                .fontSize(14)
                .fontColor(C.MUTED)
                .width(110)
              Text(this.visitText(v))
                .fontSize(14)
                .fontColor(C.TEXT)
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .border({ width: { bottom: 1 }, color: C.LINE })
          }, (v: Visit) => `${v.start_ts}`)
        }
        .margin({ bottom: 96 })
      }
      .padding({ left: 18, right: 18, top: 12 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
