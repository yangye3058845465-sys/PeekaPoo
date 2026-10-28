import { router } from '@kit.ArkUI';
import { Api, AuthError } from '../common/Api';
import { AppData, ServerConfig } from '../common/Models';
import { Session } from '../common/Session';
import { C } from '../common/Theme';
import { HomeTab } from '../components/HomeTab';
import { DataTab } from '../components/DataTab';
import { AlertsTab } from '../components/AlertsTab';
import { ProfileTab } from '../components/ProfileTab';

@Entry
@Component
struct Main {
  @State data: AppData | null = null;
  @State current: number = 0;
  @State refreshing: boolean = false;
  @State error: string = '';
  @State view: string = Session.get('view', Session.get('member', 'user1'));
  @State publicDemo: boolean = false;
  private tabs: TabsController = new TabsController();

  aboutToAppear(): void {
    Api.config().then((c: ServerConfig) => {
      this.publicDemo = c.public_demo;
    });
    this.load();
  }

  async load(): Promise<void> {
    try {
      this.data = await Api.app(this.view);
      this.error = '';
    } catch (e) {
      if (e instanceof AuthError) {
        this.toLogin();
        return;
      }
      this.error = (e as Error).message;
    } finally {
      this.refreshing = false;
    }
  }

  goto(i: number): void {
    this.current = i;
    this.tabs.changeIndex(i);
  }

  switchMember(m: string): void {
    this.view = m;
    Session.set('view', m);
    this.data = null;
    this.load();
    this.goto(0);
  }

  displayName(): string {
    if (this.view === Session.get('member', '')) {
      return Session.get('name', 'You');
    }
    return `Button ${this.view.substring(4)}`;
  }

  hasAlert(): boolean {
    return this.data !== null && this.data.triage.flags.length > 0;
  }

  toLogin(): void {
    Session.clearAccount();
    router.clear();
    router.replaceUrl({ url: 'pages/Login' });
  }

  async logout(): Promise<void> {
    try {
      await Api.logout();
    } catch (e) {
      // offline: still log out locally
    }
    this.toLogin();
  }

  confirmDelete(): void {
    this.getUIContext().showAlertDialog({
      title: 'Delete your account?',
      message: 'This permanently deletes your account and all your PeekaPoo results. This cannot be undone.',
      autoCancel: true,
      primaryButton: {
        value: 'Cancel',
        action: () => {
        }
      },
      secondaryButton: {
        value: 'Delete',
        fontColor: C.RED,
        action: () => {
          this.deleteAccount();
        }
      }
    });
  }

  async deleteAccount(): Promise<void> {
    try {
      await Api.deleteAccount();
      this.toLogin();
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: (e as Error).message });
    }
  }

  @Builder
  tabItem(i: number, title: string, on: Resource, off: Resource, dot: boolean) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Image(this.current === i ? on : off)
          .width(24)
          .height(24)
        if (dot) {
          Circle()
            .width(8)
            .height(8)
            .fill(C.RED)
            .offset({ x: 4, y: -2 })
        }
      }

      Text(title)
        .fontSize(12)
        .fontColor(this.current === i ? C.LIME : C.MUTED)
        .fontWeight(this.current === i ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Tabs({ barPosition: BarPosition.End, controller: this.tabs }) {
        TabContent() {
          HomeTab({
            data: this.data,
            name: this.displayName(),
            error: this.error,
            refreshing: $refreshing,
            onReload: (): void => {
              this.load();
            },
            onGoto: (i: number): void => {
              this.goto(i);
            }
          })
        }
        .tabBar(this.tabItem(0, 'Home', $r('app.media.tab_home_on'), $r('app.media.tab_home'), false))

        TabContent() {
          DataTab({ data: this.data })
        }
        .tabBar(this.tabItem(1, 'Data', $r('app.media.tab_data_on'), $r('app.media.tab_data'), false))

        TabContent() {
          AlertsTab({ data: this.data })
        }
        .tabBar(this.tabItem(2, 'Alerts', $r('app.media.tab_alerts_on'), $r('app.media.tab_alerts'), this.hasAlert()))

        TabContent() {
          ProfileTab({
            data: this.data,
            view: this.view,
            publicDemo: this.publicDemo,
            onSwitch: (m: string): void => {
              this.switchMember(m);
            },
            onLogout: (): void => {
              this.logout();
            },
            onDelete: (): void => {
              this.confirmDelete();
            }
          })
        }
        .tabBar(this.tabItem(3, 'Profile', $r('app.media.tab_profile_on'), $r('app.media.tab_profile'), false))
      }
      .width('100%')
      .height('100%')
      .backgroundColor(C.BG)
      .barHeight(68)
      .barBackgroundColor(C.BG2)
      .scrollable(false)
      .animationDuration(0)
      .divider({ strokeWidth: 1, color: C.LINE })
      .onChange((i: number) => {
        this.current = i;
      })

      // floating chat button: always reachable above the tab bar
      Row({ space: 8 }) {
        Image($r('app.media.bot'))
          .width(40)
          .height(40)
          .padding(6)
          .borderRadius(20)
          .backgroundColor(C.MINT)
        Text('Ask')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.INK)
      }
      .padding({ left: 6, right: 16, top: 6, bottom: 6 })
      .borderRadius(28)
      .backgroundColor(C.LIME)
      .shadow({ radius: 24, color: '#73000000', offsetY: 8 })
      .margin({ left: 16, bottom: 68 + 14 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/Chat' });
      })
    }
    .width('100%')
    .height('100%')
  }
}
