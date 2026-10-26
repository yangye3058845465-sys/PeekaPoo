import { router } from '@kit.ArkUI';
import { Api } from '../common/Api';
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
struct Login {
  @State email: string = Session.get('email', '');
  @State password: string = '';
  @State hub: string = Session.hub();
  @State showHub: boolean = false;
  @State busy: boolean = false;
  @State error: string = '';

  async submit(): Promise<void> {
    if (this.email.trim().length === 0 || this.password.length === 0) {
      this.error = 'Please enter your email and password';
      return;
    }
    this.busy = true;
    this.error = '';
    try {
      Session.setHub(this.hub);
      const acc = await Api.login(this.email.trim(), this.password);
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
    Scroll() {
      Column({ space: 10 }) {
        Image($r('app.media.app_icon'))
          .width(84)
          .height(84)
          .borderRadius(24)
          .margin({ top: 56 })
        Text('PeekaPoo')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.TEXT)
        Text('Know your gut. Own your health.')
          .fontSize(15)
          .fontColor(C.MUTED)

        Text('Welcome back')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.TEXT)
          .width('100%')
          .margin({ top: 30 })
        Text('Log in to see your gut health index')
          .fontSize(14)
          .fontColor(C.MUTED)
          .width('100%')

        Text('Email').fieldLabel()
        TextInput({ text: this.email, placeholder: 'you@example.com' })
          .field()
          .type(InputType.Email)
          .enterKeyType(EnterKeyType.Next)
          .onChange((v: string) => {
            this.email = v;
          })

        Text('Password').fieldLabel()
        TextInput({ text: this.password, placeholder: 'Your password' })
          .field()
          .type(InputType.Password)
          .enterKeyType(EnterKeyType.Go)
          .onChange((v: string) => {
            this.password = v;
          })
          .onSubmit(() => {
            this.submit();
          })

        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(13)
            .fontColor(C.RED)
            .width('100%')
        }

        Button(this.busy ? 'Logging in…' : 'Log in', { type: ButtonType.Capsule })
          .width('100%')
          .height(52)
          .margin({ top: 12 })
          .backgroundColor(C.LIME)
          .fontColor(C.INK)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .enabled(!this.busy)
          .onClick(() => {
            this.submit();
          })

        Row() {
          Text("Don't have an account? ")
            .fontSize(14)
            .fontColor(C.MUTED)
          Text('Sign up')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(C.LIME)
            .onClick(() => {
              Session.setHub(this.hub);
              router.pushUrl({ url: 'pages/Register' });
            })
        }
        .margin({ top: 8 })

        Column({ space: 8 }) {
          Row() {
            Text(`Hub: ${this.hub}`)
              .fontSize(12)
              .fontColor(C.MUTED)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.showHub ? 'Done' : 'Change')
              .fontSize(12)
              .fontColor(C.LIME)
              .onClick(() => {
                this.showHub = !this.showHub;
                Session.setHub(this.hub);
                this.hub = Session.hub();
              })
          }
          .width('100%')

          if (this.showHub) {
            TextInput({ text: this.hub, placeholder: 'http://192.168.x.x:8000' })
              .field()
              .type(InputType.URL)
              .onChange((v: string) => {
                this.hub = v;
              })
          }
        }
        .margin({ top: 36 })

        Text('PeekaPoo is a wellness screening aid, not a medical diagnosis.')
          .fontSize(11)
          .fontColor(C.MUTED)
          .textAlign(TextAlign.Center)
          .margin({ top: 12, bottom: 24 })
      }
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
    .scrollBar(BarState.Off)
  }
}
