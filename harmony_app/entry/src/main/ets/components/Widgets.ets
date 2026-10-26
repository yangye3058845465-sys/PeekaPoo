import { C } from '../common/Theme';
import { TrendDay } from '../common/Models';

@Component
export struct ScoreRing {
  @Prop score: number = -1;
  @Prop ringColor: string = C.INK;

  build() {
    Stack() {
      Progress({ value: this.score < 0 ? 0 : this.score, total: 100, type: ProgressType.Ring })
        .width(88)
        .height(88)
        .color(this.ringColor)
        .backgroundColor('#33000000')
        .style({ strokeWidth: 9 })
      Text(this.score < 0 ? '–' : `${this.score}`)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(C.INK)
    }
  }
}

// One vertical bar with a label and a sub-label underneath
@Component
export struct BarColumn {
  @Prop ratio: number = 0;
  @Prop label: string = '';
  @Prop sub: string = '';
  @Prop highlight: boolean = false;
  @Prop dim: boolean = false;
  @Prop selected: boolean = false;
  @Prop chartHeight: number = 120;

  build() {
    Column({ space: 4 }) {
      Column()
        .width('100%')
        .height(Math.max(6, this.chartHeight * this.ratio))
        .borderRadius(9)
        .backgroundColor(this.highlight ? C.LIME : (this.dim ? '#3a3156' : C.SLATE))
      Text(this.label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selected ? C.LIME : C.TEXT)
      Text(this.sub)
        .fontSize(10)
        .fontColor(C.MUTED)
    }
    .width('100%')
    .height(this.chartHeight + 40)
    .justifyContent(FlexAlign.End)
  }
}

// Horizontal percentage bar: label | track | value
@Component
export struct HBar {
  @Prop label: string = '';
  @Prop pct: number = 0;
  @Prop barColor: string = C.MINT;

  build() {
    Row({ space: 10 }) {
      Text(this.label)
        .fontSize(14)
        .fontColor(C.TEXT)
        .width(104)
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(9)
          .borderRadius(9)
          .backgroundColor('#2a2448')
        Column()
          .width(`${this.pct}%`)
          .height(9)
          .borderRadius(9)
          .backgroundColor(this.barColor)
      }
      .layoutWeight(1)

      Text(`${this.pct}%`)
        .fontSize(13)
        .fontColor(C.MUTED)
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .margin({ top: 5, bottom: 5 })
  }
}

// 7-day digestive / hydration lines drawn on a canvas
@Component
export struct TrendChart {
  @Prop @Watch('onDays') days: TrendDay[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  onDays(): void {
    this.draw();
  }

  private x(i: number, w: number): number {
    const n = this.days.length;
    return n <= 1 ? w / 2 : 8 + i * (w - 16) / (n - 1);
  }

  private y(v: number, h: number): number {
    return 10 + (1 - v / 100) * (h - 34);
  }

  private line(key: string, color: string, w: number, h: number): void {
    const c = this.ctx;
    c.strokeStyle = color;
    c.fillStyle = color;
    c.lineWidth = 2.5;
    c.beginPath();
    let started = false;
    for (let i = 0; i < this.days.length; i++) {
      const v = key === 'digestive' ? this.days[i].digestive : this.days[i].hydration;
      if (v === null || v === undefined) {
        continue;
      }
      if (started) {
        c.lineTo(this.x(i, w), this.y(v, h));
      } else {
        c.moveTo(this.x(i, w), this.y(v, h));
        started = true;
      }
    }
    c.stroke();
    for (let i = 0; i < this.days.length; i++) {
      const v = key === 'digestive' ? this.days[i].digestive : this.days[i].hydration;
      if (v === null || v === undefined) {
        continue;
      }
      c.beginPath();
      c.arc(this.x(i, w), this.y(v, h), 3, 0, Math.PI * 2);
      c.fill();
    }
  }

  draw(): void {
    if (!this.ready) {
      return;
    }
    const c = this.ctx;
    const w = c.width;
    const h = c.height;
    c.clearRect(0, 0, w, h);
    c.strokeStyle = '#2a2448';
    c.lineWidth = 1;
    const grid: number[] = [0, 50, 100];
    for (const g of grid) {
      c.beginPath();
      c.moveTo(8, this.y(g, h));
      c.lineTo(w - 8, this.y(g, h));
      c.stroke();
    }
    this.line('digestive', C.MINT, w, h);
    this.line('hydration', C.LIME, w, h);
    c.fillStyle = C.MUTED;
    c.font = '10vp sans-serif';
    c.textAlign = 'center';
    const names: string[] = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    for (let i = 0; i < this.days.length; i++) {
      const p = this.days[i].day.split('-');
      const d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
      c.fillText(names[d.getDay()], this.x(i, w), h - 6);
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(110)
      .onReady(() => {
        this.ready = true;
        this.draw();
      })
  }
}
