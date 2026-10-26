import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Api } from '../common/Api';
import { openUrl, PRIVACY_URL } from '../common/Links';
import { ServerConfig } from '../common/Models';
import { Session } from '../common/Session';
import { C } from '../common/Theme';

@Extend(TextInput)
function field() {
  .height(52)
  .backgroundColor(C.CARD)
  .fontColor(C.TEXT)
  .placeholderColor(C.MUTED)
  .caretColor(C.LIME)
  .borderRadius(16)
  .border({ width: 1, color: C.LINE })
  .padding({ left: 16, right: 16 })
}

@Extend(Text)
function fieldLabel() {
  .fontSize(14)
  .fontWeight(FontWeight.Medium)
  .fontColor(C.TEXT)
  .width('100%')
  .margin({ top: 6 })
}

@Entry
@Component
struct Register {
  @State name: string = '';
  @State email: string = '';
  @State password: string = '';
  @State confirm: string = '';
  @State slot: number = 0;
  @State agree: boolean = false;
  @State busy: boolean = false;
  @State error: string = '';
  @State publicDemo: boolean = false;
  private slots: number[] = [1, 2, 3, 4];

  aboutToAppear(): void {
    Api.config().then((c: ServerConfig) => {
      this.publicDemo = c.public_demo;
    });
  }

  validate(): string {
    if (this.name.trim().length === 0) {
      return 'Please enter your name';
    }
    if (this.email.indexOf('@') < 1) {
      return 'Please enter a valid email';
    }
    if (this.password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (this.password !== this.confirm) {
      return "Passwords don't match";
    }
    if (this.slot === 0 && !this.publicDemo) {
      return 'Please choose your button on the device';
    }
    if (!this.agree) {
      return 'Please accept the consent to continue';
    }
    return '';
  }

  async submit(): Promise<void> {
    this.error = this.validate();
    if (this.error.length > 0) {
      return;
    }
    this.busy = true;
    try {
      const acc = await Api.register(this.name.trim(), this.email.trim(), this.password, this.slot > 0 ? `user${this.slot}` : '');
      Session.saveAccount(acc);
      router.clear();
      router.replaceUrl({ url: 'pages/Main' });
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.busy = false;
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
        Text('Create account')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.TEXT)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })

      Scroll() {
        Column({ space: 10 }) {
          Text('Set up PeekaPoo for yourself. Each family member gets their own account and personal baseline.')
            .fontSize(14)
            .fontColor(C.MUTED)
            .width('100%')

          Text('Name').fieldLabel()
          TextInput({ text: this.name, placeholder: 'What should we call you?' })
            .field()
            .onChange((v: string) => {
              this.name = v;
            })

          Text('Email').fieldLabel()
          TextInput({ text: this.email, placeholder: 'you@example.com' })
            .field()
            .type(InputType.Email)
            .onChange((v: string) => {
              this.email = v;
            })

          Text('Password').fieldLabel()
          TextInput({ text: this.password, placeholder: 'At least 8 characters' })
            .field()
            .type(InputType.Password)
            .onChange((v: string) => {
              this.password = v;
            })

          Text('Confirm password').fieldLabel()
          TextInput({ text: this.confirm, placeholder: 'Type it again' })
            .field()
            .type(InputType.Password)
            .onChange((v: string) => {
              this.confirm = v;
            })

          if (!this.publicDemo) {
            Text('Your button on the PeekaPoo device').fieldLabel()
            Text('Press this button before each visit so results go to your account.')
              .fontSize(12)
              .fontColor(C.MUTED)
              .width('100%')
            Row({ space: 10 }) {
              ForEach(this.slots, (s: number) => {
                Text(`${s}`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.slot === s ? C.INK : C.TEXT)
                  .textAlign(TextAlign.Center)
                  .layoutWeight(1)
                  .height(52)
                  .borderRadius(16)
                  .backgroundColor(this.slot === s ? C.LIME : C.CARD)
                  .border({ width: 1, color: this.slot === s ? C.LIME : C.LINE })
                  .onClick(() => {
                    this.slot = s;
                  })
              }, (s: number) => `${s}`)
            }
            .width('100%')
          }

          Row({ space: 10 }) {
            Checkbox()
              .select(this.agree)
              .selectedColor(C.LIME)
              .shape(CheckBoxShape.ROUNDED_SQUARE)
              .onChange((v: boolean) => {
                this.agree = v;
              })
            Column({ space: 6 }) {
              Text('I have read the Privacy Policy. I understand PeekaPoo is a wellness screening aid, not a medical diagnosis, and I agree that my scores (never images) are stored for my personal baseline.')
                .fontSize(12)
                .fontColor(C.MUTED)
              Text('Read the Privacy Policy')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(C.LIME)
                .onClick(() => {
                  openUrl(getContext(this) as common.UIAbilityContext, PRIVACY_URL);
                })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .margin({ top: 10 })

          if (this.error.length > 0) {
            Text(this.error)
              .fontSize(13)
              .fontColor(C.RED)
              .width('100%')
          }

          Button(this.busy ? 'Creating account…' : 'Sign up', { type: ButtonType.Capsule })
            .width('100%')
            .height(52)
            .margin({ top: 8 })
            .backgroundColor(C.LIME)
            .fontColor(C.INK)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .enabled(!this.busy)
            .onClick(() => {
              this.submit();
            })

          Row() {
            Text('Already have an account? ')
              .fontSize(14)
              .fontColor(C.MUTED)
            Text('Log in')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(C.LIME)
              .onClick(() => {
                router.back();
              })
          }
          .margin({ top: 8, bottom: 30 })
        }
        .padding({ left: 24, right: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
  }
}
