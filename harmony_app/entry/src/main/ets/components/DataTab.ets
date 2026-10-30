import { AppData, GasDay, GasRef, LookRow } from '../common/Models';
import { C, LEVEL_TUBE, STOOL_HEX, UNUSUAL_URINE, URINE_HEX, URINE_TUBES, UrineColour } from '../common/Theme';
import { weekday } from '../common/Format';
import { BSS, BSS_IMG, BSS_NOTE } from '../common/Bristol';
import { BarColumn, HBar } from './Widgets';

// bar area of a gas card, in vp
const GAS_PLOT: number = 104;

const LOOK_EMPTY: Record<string, string> = {
  'colour': "Colour isn't measured for your visits yet.",
  'consistency': 'No stool visits yet in the last 30 days.',
  'quantity': "Quantity isn't measured for your visits yet."
};

@Styles
function card() {
  .width('100%')
  .padding(14)
  .borderRadius(18)
  .backgroundColor(C.CARD)
  .border({ width: 1, color: C.LINE })
}

@Extend(Text)
function label() {
  .fontSize(15)
  .fontWeight(FontWeight.Medium)
  .fontColor(C.TEXT)
  .width('100%')
  .margin({ top: 22, bottom: 10 })
}

@Extend(Text)
function note() {
  .fontSize(14)
  .lineHeight(21)
  .fontColor(C.TEXT)
  .width('100%')
  .padding(14)
  .margin({ top: 12 })
  .borderRadius(18)
  .backgroundColor(C.CARD)
  .border({ width: 1, color: C.LINE })
}

@Extend(Text)
function arrowLabel() {
  .fontSize(10.5)
  .fontStyle(FontStyle.Italic)
  .fontColor(C.MUTED)
  .textAlign(TextAlign.Center)
}

@Component
export struct DataTab {
  @Prop data: AppData | null = null;
  @State selected: string = '';
  @State view: string = 'colour';
  @State sheetOpen: boolean = false;
  @State sheetType: number = 1;
  private keys: string[] = ['All', 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
  private types: number[] = [1, 2, 3, 4, 5, 6, 7];
  private views: string[] = ['colour', 'consistency', 'quantity'];
  private viewNames: string[] = ['Colour', 'Consistency', 'Quantity'];
  @State ucolSel: number = 0;

  /* ---------- bristol ---------- */
  n(): number {
    return this.data === null ? 0 : (this.data.bristol.n ?? 0);
  }

  share(k: string): number {
    if (k === 'All') {
      return this.n() > 0 ? 100 : 0;
    }
    return this.data === null ? 0 : (this.data.bristol.share[k] ?? 0);
  }

  top(): string {
    if (this.data === null || this.n() === 0) {
      return '';
    }
    let best = 'T1';
    for (let i = 1; i <= 7; i++) {
      const k = `T${i}`;
      if ((this.data.bristol.counts[k] ?? 0) > (this.data.bristol.counts[best] ?? 0)) {
        best = k;
      }
    }
    return best;
  }

  sel(): string {
    if (this.selected.length > 0) {
      return this.selected;
    }
    const t = this.top();
    return t.length > 0 ? t : 'All';
  }

  ratio(k: string): number {
    if (k === 'All') {
      return 1;
    }
    let max = 1;
    for (let i = 1; i <= 7; i++) {
      max = Math.max(max, this.share(`T${i}`));
    }
    return 0.06 + 0.94 * this.share(k) / max;
  }

  bristolNote(): string {
    const n = this.n();
    if (n === 0) {
      return 'No stool visits yet in the last 30 days.';
    }
    const s = this.sel();
    const top = this.top();
    if (s === 'All') {
      return `${n} stool visits analysed. Your most common is Type ${top.substring(1)} (${this.share(top)}%).`;
    }
    const t = Number(s.substring(1));
    const mine = s === top ? ', your most common type' : '';
    return `Type ${t}${mine}: ${BSS[t - 1].short.toLowerCase()}. Logged ${this.share(s)}% of the time this month.`;
  }

  /* ---------- chips: colour / consistency / quantity ---------- */
  lookRows(): LookRow[] {
    if (this.data === null) {
      return [];
    }
    const look = this.data.look;
    if (this.view === 'colour') {
      return look.colour.rows;
    }
    return this.view === 'quantity' ? look.quantity.rows : look.consistency.rows;
  }

  /* ---------- urine & gas ---------- */
  urine(k: string): number {
    return this.data === null ? 0 : (this.data.urine.share[k] ?? 0);
  }

  urineNote(): string {
    if (this.data === null || (this.data.urine.n ?? 0) === 0) {
      return 'No urine visits yet.';
    }
    const dark = this.urine('Amber') + this.urine('Brown');
    if (dark >= 30) {
      return `Amber or brown on ${dark}% of visits: drinking a little more water through the day may help.`;
    }
    return 'Mostly clear to yellow this month, consistent with a well-hydrated baseline.';
  }

  // tube index of the latest urine visit, -1 if none
  latestTube(): number {
    return this.data === null || this.data.hydration === null ? -1 : (LEVEL_TUBE[this.data.hydration.level] ?? -1);
  }

  @Builder
  urineScale() {
    Row() {
      ForEach(URINE_TUBES, (name: string, i: number) => {
        Column({ space: 6 }) {
          Text(name)
            .fontSize(10.5)
            .lineHeight(13)
            .fontColor(i === this.latestTube() ? C.LIME : C.MUTED)
            .fontWeight(i === this.latestTube() ? FontWeight.Bold : FontWeight.Normal)
            .textAlign(TextAlign.Center)
            .align(Alignment.Bottom)
            .height(28)
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width('100%')
              .height('80%')
              .backgroundColor(URINE_HEX[i])
          }
          .width(26)
          .height(78)
          .border({ width: { left: 2, right: 2, bottom: 2, top: 0 },
            color: i === this.latestTube() ? C.LIME : '#8d86ad' })
          .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 13, bottomRight: 13 })
          .clip(true)
          Text(i === this.latestTube() ? 'Latest' : ' ')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(C.LIME)
        }
        .layoutWeight(1)
      }, (name: string) => name)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)

    // hydrated -> dehydrated arrow under the tubes
    Row() {
      Column()
        .layoutWeight(1)
        .height(4)
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [['#f4f2ea', 0], ['#f9ea6b', 0.35], ['#f2a528', 0.7], ['#c8642e', 1]]
        })
      Polygon({ width: 12, height: 12 })
        .points([[0, 0], [12, 6], [0, 12]])
        .fill('#c8642e')
    }
    .width('100%')
    .margin({ top: 8 })
    Row() {
      Text('Hydrated').arrowLabel().layoutWeight(3)
      Text('Light dehydrated').arrowLabel().layoutWeight(1)
      Text('Dehydrated').arrowLabel().layoutWeight(1)
      Text('Severe').arrowLabel().layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ top: 4 })
  }

  @Builder
  unusualUrine() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(UNUSUAL_URINE, (c: UrineColour, i: number) => {
        Row({ space: 8 }) {
          Circle({ width: 16, height: 16 })
            .fill(c.hex)
            .stroke('#55507a')
          Text(c.name)
            .fontSize(13)
            .fontColor(C.TEXT)
            .layoutWeight(1)
        }
        .padding({ left: 10, right: 8, top: 9, bottom: 9 })
        .borderRadius(14)
        .backgroundColor(C.CARD)
        .border({ width: 1, color: i === this.ucolSel ? C.LIME : C.LINE })
        .width('31.5%')
        .margin({ right: '1.8%', bottom: 8 })
        .onClick(() => {
          this.ucolSel = i;
        })
      }, (c: UrineColour) => c.name)
    }
    .width('100%')

    Column({ space: 6 }) {
      Text() {
        Span(UNUSUAL_URINE[this.ucolSel].name)
          .fontColor(C.LIME)
          .fontWeight(FontWeight.Medium)
        Span(`: often from food. ${UNUSUAL_URINE[this.ucolSel].food}`)
          .fontColor(C.TEXT)
      }
      .fontSize(14)
      .lineHeight(21)
      .width('100%')
      Text(UNUSUAL_URINE[this.ucolSel].doctor)
        .fontSize(14)
        .lineHeight(21)
        .fontColor(C.TEXT)
        .width('100%')
      Text("Reference guide. PeekaPoo's camera grades the hydration scale above, not these colours.")
        .fontSize(11)
        .fontColor(C.MUTED)
        .width('100%')
    }
    .card()
    .margin({ top: 4 })
  }

  gas(): GasDay[] {
    return this.data === null ? [] : this.data.gas7;
  }

  gasValue(g: GasDay, nh3: boolean): number | null {
    return nh3 ? g.NH3 : g.VOC;
  }

  gasHigh(g: GasDay, nh3: boolean): boolean {
    const z = nh3 ? g.z_NH3 : g.z_VOC;
    return this.data !== null && z !== null && z > this.data.z_threshold;
  }

  gasRef(nh3: boolean): GasRef | null {
    if (this.data === null || this.data.gas_ref === undefined) {
      return null;
    }
    return nh3 ? this.data.gas_ref.NH3 : this.data.gas_ref.VOC;
  }

  // bars start from zero; the scale also leaves room for the alert line
  gasPx(v: number, nh3: boolean): number {
    let top = 1;
    for (const d of this.gas()) {
      const x = this.gasValue(d, nh3);
      if (x !== null) {
        top = Math.max(top, x);
      }
    }
    const ref = this.gasRef(nh3);
    if (ref !== null) {
      top = Math.max(top, ref.alert);
    }
    return Math.round(GAS_PLOT * v / (top * 1.12));
  }

  gasBarPx(g: GasDay, nh3: boolean): number {
    const v = this.gasValue(g, nh3);
    return v === null ? 3 : Math.max(6, this.gasPx(v, nh3));
  }

  isLatest(g: GasDay): boolean {
    const days = this.gas();
    return days.length > 0 && days[days.length - 1].day === g.day;
  }

  gasLatest(nh3: boolean): string {
    const days = this.gas();
    const v = days.length > 0 ? this.gasValue(days[days.length - 1], nh3) : null;
    return v === null ? '–' : `${Math.round(v)}`;
  }

  // 0 learning, 1 within baseline, 2 above baseline (latest day)
  gasState(nh3: boolean): number {
    const days = this.gas();
    if (this.data === null || this.data.gas_warming_up || this.gasRef(nh3) === null) {
      return 0;
    }
    return days.length > 0 && this.gasHigh(days[days.length - 1], nh3) ? 2 : 1;
  }

  gasSub(g: GasDay, nh3: boolean): string {
    const v = this.gasValue(g, nh3);
    return v === null ? '–' : `${Math.round(v)}`;
  }

  gasNote(nh3: boolean): string {
    if (this.data === null) {
      return '';
    }
    if (this.data.gas_warming_up || this.gasRef(nh3) === null) {
      return 'Still building your personal baseline (needs at least 5 days).';
    }
    const high: string[] = [];
    for (const g of this.data.gas7) {
      if (this.gasHigh(g, nh3)) {
        high.push(weekday(g.day));
      }
    }
    if (high.length === 0) {
      return 'Within your personal baseline all week.';
    }
    return `Above your baseline on ${high.join(', ')}. An alert is raised only after 3 days in a row.`;
  }

  /* ---------- builders ---------- */
  @Builder
  legendItem(color: string, text: string, value: number) {
    Row({ space: 6 }) {
      Column()
        .width(16)
        .height(0)
        .border({ width: { top: 1.5 }, color: color, style: BorderStyle.Dashed })
      Text() {
        Span(`${text} `)
          .fontColor(C.MUTED)
        Span(`${Math.round(value)}`)
          .fontColor(C.TEXT)
          .fontWeight(FontWeight.Medium)
      }
      .fontSize(11)
    }
  }

  // one gas channel: latest reading and status, 7 bars from zero, personal baseline and alert line across
  @Builder
  gasCard(nh3: boolean, title: string, sub: string) {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text(title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(C.TEXT)
          Text(sub)
            .fontSize(12)
            .fontColor(C.MUTED)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 6 }) {
          Row({ space: 4 }) {
            Text(this.gasLatest(nh3))
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor(C.TEXT)
            Text('latest')
              .fontSize(11)
              .fontColor(C.MUTED)
              .margin({ bottom: 4 })
          }
          .alignItems(VerticalAlign.Bottom)
          Text(['Learning', 'Within baseline', 'Above baseline'][this.gasState(nh3)])
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor([C.MUTED, C.GREEN, C.RED][this.gasState(nh3)])
            .backgroundColor(['#299a94b8', '#295ee0a0', '#2eff6b6b'][this.gasState(nh3)])
            .padding({ left: 10, right: 10, top: 3, bottom: 3 })
            .borderRadius(999)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.gasRef(nh3) !== null) {
        Row({ space: 16 }) {
          this.legendItem(C.MINT, 'Your baseline', (this.gasRef(nh3) as GasRef).median)
          this.legendItem(C.RED, 'Alert line', (this.gasRef(nh3) as GasRef).alert)
        }
        .width('100%')
        .margin({ top: 8, bottom: 12 })
      }

      Stack({ alignContent: Alignment.Bottom }) {
        if (this.gasRef(nh3) !== null) {
          Column()
            .width('100%')
            .height(this.gasPx((this.gasRef(nh3) as GasRef).alert, nh3))
            .borderRadius({ bottomLeft: 10, bottomRight: 10 })
            .linearGradient({ direction: GradientDirection.Top, colors: [['#1a5ee0a0', 0], ['#085ee0a0', 1]] })
          Column()
            .width('100%')
            .height(0)
            .border({ width: { top: 1 }, color: '#99ff6b6b', style: BorderStyle.Dashed })
            .position({ x: 0, y: GAS_PLOT + 6 - this.gasPx((this.gasRef(nh3) as GasRef).alert, nh3) })
          Column()
            .width('100%')
            .height(0)
            .border({ width: { top: 1 }, color: '#8cbfe0d4', style: BorderStyle.Dashed })
            .position({ x: 0, y: GAS_PLOT + 6 - this.gasPx((this.gasRef(nh3) as GasRef).median, nh3) })
        }
        Row() {
          ForEach(this.gas(), (g: GasDay) => {
            Column() {
              Column()
                .width('58%')
                .constraintSize({ maxWidth: 24 })
                .height(this.gasBarPx(g, nh3))
                .borderRadius({ topLeft: 8, topRight: 8, bottomLeft: 3, bottomRight: 3 })
                .linearGradient({
                  direction: GradientDirection.Bottom,
                  colors: this.gasHigh(g, nh3) ? [['#ff8a7a', 0], ['#8cffb547', 1]] : [['#bfe0d4', 0], ['#47bfe0d4', 1]]
                })
                .border(this.isLatest(g) ? { width: 2, color: '#b3f4f2ff' } : { width: 0 })
                .shadow(this.gasHigh(g, nh3) ? { radius: 14, color: '#59ff6b6b' } : { radius: 0, color: Color.Transparent })
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.End)
          }, (g: GasDay) => g.day + (nh3 ? 'n' : 'v'))
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height(GAS_PLOT + 6)

      Row() {
        ForEach(this.gas(), (g: GasDay) => {
          Column({ space: 2 }) {
            Text(weekday(g.day))
              .fontSize(11)
              .fontColor(this.isLatest(g) ? C.TEXT : C.MUTED)
              .fontWeight(this.isLatest(g) ? FontWeight.Bold : FontWeight.Normal)
            Text(this.gasSub(g, nh3))
              .fontSize(10)
              .fontColor(this.gasHigh(g, nh3) ? C.RED : (this.isLatest(g) ? C.TEXT : C.MUTED))
              .fontWeight(this.gasHigh(g, nh3) || this.isLatest(g) ? FontWeight.Bold : FontWeight.Normal)
          }
          .layoutWeight(1)
        }, (g: GasDay) => g.day + (nh3 ? 'nl' : 'vl'))
      }
      .width('100%')
      .padding({ top: 6 })
      .margin({ top: 8 })
      .border({ width: { top: 1 }, color: C.LINE })

      Text(this.gasNote(nh3))
        .fontSize(13)
        .lineHeight(19)
        .fontColor('#d6d2ea')
        .width('100%')
        .margin({ top: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 14 })
    .margin({ bottom: 14 })
    .borderRadius(22)
    .linearGradient({ direction: GradientDirection.Bottom, colors: [['#221b44', 0], [C.CARD, 1]] })
    .border({ width: 1, color: C.LINE })
  }

  @Builder
  sheetSection(title: string, lines: string[], bullet: boolean) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1d1d27')
      ForEach(lines, (l: string) => {
        Text(bullet ? '•  ' + l : l)
          .fontSize(14)
          .lineHeight(20)
          .fontColor('#1d1d27')
      }, (l: string) => l)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor('#dfdee7')
  }

  @Builder
  sheet() {
    Scroll() {
      Column({ space: 10 }) {
        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            Image(BSS_IMG[this.sheetType - 1])
              .width('80%')
              .objectFit(ImageFit.Contain)
          }
          .width(150)
          .height(150)
          .borderRadius(75)
          .backgroundColor(Color.White)
          .border({ width: 2, color: '#222222' })
          .justifyContent(FlexAlign.Center)

          Text(`TYPE ${this.sheetType}`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor('#3f6a8f')
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .margin({ top: 8 })
        }

        Text(BSS[this.sheetType - 1].title)
          .fontSize(17)
          .fontColor('#1d1d27')
          .textAlign(TextAlign.Center)
          .margin({ top: 6, bottom: 6 })
        this.sheetSection('WHAT THIS REPRESENTS', [BSS[this.sheetType - 1].means], false)
        this.sheetSection('POSSIBLE CAUSES', BSS[this.sheetType - 1].causes, true)
        this.sheetSection('WHAT MAY HELP', BSS[this.sheetType - 1].help, true)
        Text(BSS_NOTE)
          .fontSize(12)
          .fontColor('#6a6878')
          .margin({ top: 6, bottom: 30 })
      }
      .padding({ left: 18, right: 18, top: 8 })
    }
    .scrollBar(BarState.Off)
  }

  build() {
    Scroll() {
      Column() {
        Text('Your Gut Health Index')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.TEXT)
          .width('100%')
          .margin({ top: 10 })
        Text(`${this.data === null ? 0 : this.data.visits} logged visits in the last 30 days · your own history only`)
          .fontSize(14)
          .fontColor(C.MUTED)
          .width('100%')
          .margin({ top: 4 })

        Text('Explore by Bristol type').label()
        Row({ space: 6 }) {
          ForEach(this.keys, (k: string) => {
            Column() {
              BarColumn({
                ratio: this.ratio(k),
                label: k,
                sub: `${this.share(k)}%`,
                highlight: k === this.top(),
                dim: k === 'All',
                selected: k === this.sel(),
                chartHeight: 110
              })
            }
            .layoutWeight(1)
            .onClick(() => {
              this.selected = k;
            })
          }, (k: string) => k)
        }
        .width('100%')

        Text(this.bristolNote()).note()

        Row({ space: 8 }) {
          ForEach(this.views, (v: string, i: number) => {
            Text(this.viewNames[i])
              .fontSize(14)
              .fontWeight(this.view === v ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.view === v ? C.INK : C.TEXT)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .borderRadius(18)
              .backgroundColor(this.view === v ? C.LIME : C.CARD)
              .border({ width: 1, color: this.view === v ? C.LIME : C.LINE })
              .onClick(() => {
                this.view = v;
              })
          }, (v: string) => v)
        }
        .width('100%')
        .margin({ top: 22, bottom: 12 })

        if (this.lookRows().length === 0) {
          Text(LOOK_EMPTY[this.view] ?? '')
            .fontSize(14)
            .fontColor(C.MUTED)
            .width('100%')
        } else {
          Column() {
            ForEach(this.lookRows(), (r: LookRow) => {
              HBar({ label: r.label, pct: r.pct, barColor: this.view === 'colour' ? (STOOL_HEX[r.label] ?? C.MINT) : C.MINT })
            }, (r: LookRow) => this.view + r.label + r.pct)
          }
        }

        Row() {
          Text('Bristol Stool Scale')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(C.TEXT)
          Text(' · tap to learn')
            .fontSize(14)
            .fontColor(C.MUTED)
        }
        .width('100%')
        .margin({ top: 22, bottom: 10 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.types, (t: number) => {
            Column({ space: 6 }) {
              Stack({ alignContent: Alignment.TopStart }) {
                Column() {
                  Image(BSS_IMG[t - 1])
                    .width('80%')
                    .objectFit(ImageFit.Contain)
                }
                .width('100%')
                .aspectRatio(1)
                .borderRadius(1000)
                .backgroundColor('#f3f1ec')
                .justifyContent(FlexAlign.Center)
                .border({ width: `T${t}` === this.top() ? 3 : 0, color: C.LIME })

                Text(`TYPE ${t}`)
                  .fontSize(9)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .backgroundColor('#3f6a8f')
                  .borderRadius(4)
                  .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              }
              .width('100%')

              Text(BSS[t - 1].short)
                .fontSize(11)
                .fontColor(C.MUTED)
                .textAlign(TextAlign.Center)
            }
            .width('25%')
            .padding(5)
            .onClick(() => {
              this.sheetType = t;
              this.sheetOpen = true;
            })
          }, (t: number) => `${t}`)
        }
        .width('100%')

        Text('Urine & Gas Signals')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.TEXT)
          .width('100%')
          .margin({ top: 32 })
        Text('Same personal-history basis as your stool data above')
          .fontSize(14)
          .fontColor(C.MUTED)
          .width('100%')

        Text('Urine colour scale').label()
        this.urineScale()

        Text('Urine colour, this month').label()
        ForEach(URINE_TUBES, (k: string, i: number) => {
          HBar({ label: k, pct: this.urine(k), barColor: URINE_HEX[i] })
        }, (k: string) => k)
        Text(this.urineNote()).note()

        Text('Unusual colours · tap to learn').label()
        this.unusualUrine()

        Text('Gas signals, past 7 days').label()
        this.gasCard(true, 'Ammonia', 'NH₃ · from protein breakdown')
        this.gasCard(false, 'VOC signal', 'Volatile organic compounds')
        Column()
          .height(82)
      }
      .padding({ left: 18, right: 18, top: 12 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .bindSheet(this.sheetOpen, this.sheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      backgroundColor: '#f1f0f4',
      onDisappear: () => {
        this.sheetOpen = false;
      }
    })
  }
}
