import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Session } from '../common/Session';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Session.init(this.context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const page = Session.loggedIn() ? 'pages/Main' : 'pages/Login';
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(0x0000, 'PeekaPoo', 'loadContent failed: %{public}s', JSON.stringify(err));
      }
    });
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowSystemBarProperties({
        statusBarColor: '#120d2b',
        statusBarContentColor: '#FFFFFF',
        navigationBarColor: '#0d0921',
        navigationBarContentColor: '#FFFFFF'
      });
    }).catch(() => {
    });
  }
}
