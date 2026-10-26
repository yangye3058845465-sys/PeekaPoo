import { common, Want } from '@kit.AbilityKit';

export const PRIVACY_URL: string = 'https://yangye3058845465-sys.github.io/peekapoo-website/privacy.html';

// Open a web page in the system browser
export function openUrl(ctx: common.UIAbilityContext, url: string): void {
  const want: Want = {
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: url
  };
  ctx.startAbility(want).catch(() => {
  });
}
