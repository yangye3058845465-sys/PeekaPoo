import { router } from '@kit.ArkUI';
import { Api } from '../common/Api';
import { ChatMsg } from '../common/Models';
import { Session } from '../common/Session';
import { C } from '../common/Theme';
import { sourceText } from '../common/Format';

@Entry
@Component
struct Chat {
  @State msgs: ChatMsg[] = [];
  @State input: string = '';
  @State busy: boolean = false;
  private nextId: number = 0;
  private scroller: Scroller = new Scroller();
  private member: string = Session.get('view', Session.get('member', 'user1'));
  private suggestions: string[] = [
    'Currently is my gut health okay?',
    "How's my stool pattern this week?",
    'Why is my hydration score low?'
  ];

  aboutToAppear(): void {
    const name = this.member === Session.get('member', '') ? Session.get('name', '') : '';
    this.push('bot', `Hi${name.length > 0 ? ' ' + name : ''}! I can help explain your scores, trends, or anything unusual I've spotted. What would you like to know?`, '');
  }

  push(role: string, text: string, note: string): void {
    this.msgs.push(new ChatMsg(this.nextId++, role, text, note));
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 50);
  }

  async ask(q: string): Promise<void> {
    const question = q.trim();
    if (question.length === 0 || this.busy) {
      return;
    }
    this.input = '';
    this.busy = true;
    this.push('user', question, '');
    this.push('bot', 'Thinking…', '');
    let reply: ChatMsg;
    try {
      const r = await Api.ask(this.member, question);
      reply = new ChatMsg(this.nextId++, 'bot', r.text, `Answered by ${sourceText(r.source)} · not a diagnosis`);
    } catch (e) {
      reply = new ChatMsg(this.nextId++, 'bot', (e as Error).message, '');
    }
    this.msgs = this.msgs.slice(0, this.msgs.length - 1).concat([reply]);
    this.busy = false;
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 50);
  }

  @Builder
  bubble(m: ChatMsg) {
    if (m.role === 'bot') {
      Row({ space: 8 }) {
        Image($r('app.media.bot'))
          .width(30)
          .height(30)
          .padding(4)
          .borderRadius(10)
          .backgroundColor(C.MINT)
        Column({ space: 6 }) {
          Text(m.text)
            .fontSize(15)
            .lineHeight(22)
            .fontColor(m.text === 'Thinking…' ? C.MUTED : C.TEXT)
          if (m.note.length > 0) {
            Text(m.note)
              .fontSize(11)
              .fontColor(C.MUTED)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .borderRadius({ topLeft: 6, topRight: 18, bottomLeft: 18, bottomRight: 18 })
        .backgroundColor(C.CARD)
        .border({ width: 1, color: C.LINE })
        .constraintSize({ maxWidth: '82%' })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else {
      Row() {
        Blank()
        Text(m.text)
          .fontSize(15)
          .lineHeight(22)
          .fontWeight(FontWeight.Medium)
          .fontColor(C.INK)
          .padding(12)
          .borderRadius({ topLeft: 18, topRight: 18, bottomLeft: 18, bottomRight: 6 })
          .backgroundColor(C.LIME)
          .constraintSize({ maxWidth: '80%' })
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('←')
          .fontSize(18)
          .fontColor(C.TEXT)
          .width(38)
          .height(38)
          .textAlign(TextAlign.Center)
          .borderRadius(19)
          .backgroundColor(C.CARD)
          .border({ width: 1, color: C.LINE })
          .onClick(() => {
            router.back();
          })
        Column({ space: 2 }) {
          Text('PeekaPoo Assistant')
            .fontSize(21)
            .fontWeight(FontWeight.Bold)
            .fontColor(C.TEXT)
          Text('Ask anything about your gut health')
            .fontSize(13)
            .fontColor(C.MUTED)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      List({ space: 12, scroller: this.scroller }) {
        ForEach(this.msgs, (m: ChatMsg) => {
          ListItem() {
            this.bubble(m)
          }
        }, (m: ChatMsg) => `${m.id}`)
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)

      if (this.msgs.length < 2) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.suggestions, (s: string) => {
              Text(s)
                .fontSize(13)
                .fontColor(C.TEXT)
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .borderRadius(16)
                .backgroundColor(C.CARD)
                .border({ width: 1, color: C.LINE })
                .onClick(() => {
                  this.ask(s);
                })
            }, (s: string) => s)
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .margin({ bottom: 8 })
      }

      Row({ space: 10 }) {
        TextInput({ text: this.input, placeholder: 'Ask PeekaPoo anything...' })
          .layoutWeight(1)
          .height(48)
          .backgroundColor(C.CARD)
          .fontColor(C.TEXT)
          .placeholderColor(C.MUTED)
          .caretColor(C.LIME)
          .borderRadius(24)
          .border({ width: 1, color: C.LINE })
          .enterKeyType(EnterKeyType.Send)
          .onChange((v: string) => {
            this.input = v;
          })
          .onSubmit(() => {
            this.ask(this.input);
          })
        Text('↑')
          .width(48)
          .height(48)
          .borderRadius(24)
          .textAlign(TextAlign.Center)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.INK)
          .backgroundColor(this.busy ? C.SLATE : C.LIME)
          .onClick(() => {
            this.ask(this.input);
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 14 })
      .border({ width: { top: 1 }, color: C.LINE })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
  }
}
