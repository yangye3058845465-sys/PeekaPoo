import { router } from '@kit.ArkUI';
import { Api, AuthError } from '../common/Api';
import { AppData } from '../common/Models';
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
  private tabs: TabsController = new TabsController();

  aboutToAppear(): void {
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
          },
          onChat: (): void => {
            router.pushUrl({ url: 'pages/Chat' });
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
          onSwitch: (m: string): void => {
            this.switchMember(m);
          },
          onLogout: (): void => {
            this.logout();
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
  }
}
