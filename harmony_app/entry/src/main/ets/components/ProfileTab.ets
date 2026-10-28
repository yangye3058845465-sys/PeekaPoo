import { common } from '@kit.AbilityKit';
import { openUrl, PRIVACY_URL } from '../common/Links';
import { AppData } from '../common/Models';
import { Session } from '../common/Session';
import { C } from '../common/Theme';

@Styles
function card() {
  .width('100%')
  .padding(16)
  .borderRadius(20)
  .backgroundColor(C.CARD)
  .border({ width: 1, color: C.LINE })
}

@Extend(Text)
function label() {
  .fontSize(15)
  .fontWeight(FontWeight.Medium)
  .fontColor(C.TEXT)
  .width('100%')
  .margin({ top: 18, bottom: 8 })
}

@Component
export struct ProfileTab {
  @Prop data: AppData | null = null;
  @Prop view: string = '';
  @Prop publicDemo: boolean = false;
  onSwitch: (member: string) => void = (member: string) => {
  };
  onLogout: () => void = () => {
  };
  onDelete: () => void = () => {
  };
  @Prop demoStatus: string = '';
  onScenario: (scenario: string, name: string) => void = (scenario: string, name: string) => {
  };
  private scenarios: string[][] = [
    ['healthy', 'Healthy week'],
    ['ammonia_high', 'High ammonia'],
    ['constipation_gas', 'Constipation']
  ];
  private privacy: string[] = [
    'Images are analysed on the device and never uploaded',
    'Only scores and trends sync to the cloud',
    'Each member has their own baseline'
  ];

  name(): string {
    return Session.get('name', 'You');
  }

  me(): string {
    return Session.get('member', '');
  }

  members(): string[] {
    return this.data === null ? [this.me()] : this.data.users;
  }

  memberLabel(m: string): string {
    const slot = m.startsWith('user') ? `Button ${m.substring(4)}` : m;
    return m === this.me() ? `${slot} · You` : slot;
  }

  rows(): string[][] {
    const s = this.data === null ? null : this.data.system;
    return [
      ['Edge AI', 'Atlas 200I DK A2'],
      ['Sensor controller', 'Hi3861 · OpenHarmony'],
      ['Vision models', s === null ? '–' : (s.vision_backend === 'om' ? 'Ascend NPU (.om)' : 'PyTorch (CPU)')],
      ['AI advisor', s === null ? '–' : (s.llm_backend === 'template' ? 'Rule templates' : `Qwen2.5-0.5B (${s.llm_backend})`)],
      ['Huawei Cloud sync', s === null ? '–' : (s.cloud ? 'Connected' : 'Offline (local only)')],
      ['Data source', s === null ? '–' : (s.synthetic ? 'Demo data' : 'Live device')],
      ['Hub address', Session.hub()]
    ];
  }

  build() {
    Scroll() {
      Column() {
        Row({ space: 14 }) {
          Text(this.name().charAt(0).toUpperCase())
            .width(64)
            .height(64)
            .borderRadius(32)
            .textAlign(TextAlign.Center)
            .backgroundColor(C.CREAM)
            .fontColor(C.INK)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
          Column({ space: 2 }) {
            Text(this.name())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(C.TEXT)
            Text(Session.get('email', ''))
              .fontSize(13)
              .fontColor(C.MUTED)
            Text(this.publicDemo ? 'Demo account' : `Device button ${this.me().substring(4)}`)
              .fontSize(13)
              .fontColor(C.MUTED)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 16 })

        if (!this.publicDemo) {
          Text('Household members').label()
          Text('Switch to view a family member’s results on this device.')
            .fontSize(12)
            .fontColor(C.MUTED)
            .width('100%')
            .margin({ bottom: 8 })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.members(), (m: string) => {
              Text(this.memberLabel(m))
                .fontSize(14)
                .fontWeight(m === this.view ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(m === this.view ? C.INK : C.TEXT)
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .margin({ right: 8, bottom: 8 })
                .borderRadius(20)
                .backgroundColor(m === this.view ? C.LIME : C.CARD)
                .border({ width: 1, color: m === this.view ? C.LIME : C.LINE })
                .onClick(() => {
                  this.onSwitch(m);
                })
            }, (m: string) => m)
          }
          .width('100%')
        }

        Text('My PeekaPoo device').label()
        Column() {
          ForEach(this.rows(), (r: string[]) => {
            Row({ space: 10 }) {
              Text(r[0])
                .fontSize(14)
                .fontColor(C.MUTED)
              Blank()
              Text(r[1])
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(C.TEXT)
                .textAlign(TextAlign.End)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ top: 9, bottom: 9 })
          }, (r: string[]) => r[0] + r[1])
        }
        .card()

        if (this.publicDemo) {
          Text('Demo data').label()
          Text('Replace your sample readings with a scenario to see how PeekaPoo reacts.')
            .fontSize(12)
            .fontColor(C.MUTED)
            .width('100%')
            .margin({ bottom: 8 })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.scenarios, (s: string[]) => {
              Text(s[1])
                .fontSize(14)
                .fontColor(C.TEXT)
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .margin({ right: 8, bottom: 8 })
                .borderRadius(20)
                .backgroundColor(C.CARD)
                .border({ width: 1, color: C.LINE })
                .onClick(() => {
                  this.onScenario(s[0], s[1]);
                })
            }, (s: string[]) => s[0])
          }
          .width('100%')
          if (this.demoStatus.length > 0) {
            Text(this.demoStatus)
              .fontSize(12)
              .fontColor(C.MUTED)
              .width('100%')
          }
        }

        Text('Privacy').label()
        Column({ space: 8 }) {
          ForEach(this.privacy, (p: string) => {
            Text('✓  ' + p)
              .fontSize(14)
              .fontColor(C.TEXT)
              .width('100%')
          }, (p: string) => p)
          Text('Read the Privacy Policy →')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(C.LIME)
            .width('100%')
            .onClick(() => {
              openUrl(getContext(this) as common.UIAbilityContext, PRIVACY_URL);
            })
        }
        .card()

        Text(this.data === null ? '' : this.data.disclaimer)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(C.MUTED)
          .width('100%')
          .margin({ top: 18 })

        Button('Log out', { type: ButtonType.Capsule })
          .width('100%')
          .height(48)
          .margin({ top: 20 })
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: C.RED })
          .fontColor(C.RED)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.onLogout();
          })

        Text('Delete my account')
          .fontSize(13)
          .fontColor(C.MUTED)
          .decoration({ type: TextDecorationType.Underline, color: C.MUTED })
          .margin({ top: 16 })
          .onClick(() => {
            this.onDelete();
          })

        Text('PeekaPoo · Team InsideOut · USM')
          .fontSize(12)
          .fontColor(C.MUTED)
          .margin({ top: 16, bottom: 96 })
      }
      .padding({ left: 18, right: 18, top: 12 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
