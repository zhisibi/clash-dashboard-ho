/**
 * Gentle review prompt soft card (1.3.0, same spec as MimiFTP 1.3.0 / MimiSSH 1.5.11).
 *
 * Not a dialog: the card floats above the bottom bar on the main screen, does not cover the content or block
 * the UI, and the user can ignore it and keep working. Triggering and rate limiting live in
 * ReviewLogic / ReviewPrompt (installed >= 3 days + >= 5 launches + >= 3 successful connections; at most once
 * per 90 days, 3 times in the app's lifetime); this component only renders and reports the choice:
 * - "Rate" -> ReviewPrompt.chooseRate() (automatic prompts off for good) + opens the AppGallery detail page;
 * - "Later" and the top-right close button -> chooseLater(), snooze 60 days;
 * - "Don't remind me" -> chooseNever(), automatic prompts off for good (the permanent Settings > About entry stays);
 * - the feedback entry in the body -> chooseFeedback() (same snooze) + copies the feedback group number, so
 *   complaints are routed away first instead of being asked for a rating on the spot.
 * The wording stays neutral: it only invites "leaving a review", never "five stars" or similar inducement.
 */
import { Store } from '../common/Store';
import { ReviewPrompt } from '../common/ReviewPrompt';
import { FileUtil } from '../common/FileUtil';
import { Motion } from '../common/Motion';
import { t } from '../common/I18n';

/** Same QQ feedback group as Settings > About (1.2.9) */
const FEEDBACK_GROUP: string = '1127250124';

@ComponentV2
export struct ReviewCard {
  private store: Store = Store.get();
  private rp: ReviewPrompt = ReviewPrompt.get();

  /** "Rate": save the state first, then jump; if the jump fails, hint at a manual store search. */
  async rate(): Promise<void> {
    this.rp.chooseRate();
    const ok = await ReviewPrompt.openListing(this.store.ctx);
    if (!ok) {
      this.store.toast(t('rate_open_failed'));
    }
  }

  /** Feedback diversion: copy the group number and snooze, same as the About page's feedback row. */
  feedback(): void {
    this.rp.chooseFeedback();
    FileUtil.copyText(FEEDBACK_GROUP);
    this.store.toast(t('copied'));
  }

  build() {
    if (this.rp.showCard) {
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.star'))
            .fontSize(22)
            .fontColor([this.store.palette().accentUi])
          Text(t('review_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.store.palette().text)
            .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.xmark_circle'))
            .fontSize(20)
            .fontColor([this.store.palette().subtle])
            .accessibilityText(t('close_btn'))
            .onClick(() => {
              this.rp.chooseLater();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(t('review_body'))
          .fontSize(13)
          .lineHeight(19)
          .fontColor(this.store.palette().subtle)
          .width('100%')

        Row() {
          Text(t('review_feedback'))
            .fontSize(13)
            .fontColor(this.store.palette().accent)
            .accessibilityText(t('review_feedback'))
            .onClick(() => {
              this.feedback();
            })
          Blank()
          Text(t('review_never'))
            .fontSize(13)
            .fontColor(this.store.palette().subtle)
            .accessibilityText(t('review_never'))
            .onClick(() => {
              this.rp.chooseNever();
            })
        }
        .width('100%')

        Row({ space: 10 }) {
          Button(t('review_later'), { type: ButtonType.Capsule })
            .layoutWeight(1)
            .height(40)
            .fontColor(this.store.palette().text)
            .backgroundColor(this.store.palette().chip)
            .onClick(() => {
              this.rp.chooseLater();
            })
          Button(t('review_rate'), { type: ButtonType.Capsule })
            .layoutWeight(1)
            .height(40)
            .fontColor(this.store.palette().onPrimary)
            .backgroundColor(this.store.palette().primary)
            .onClick(() => {
              this.rate();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .borderRadius(18)
      .attributeModifier(Store.get().glass('card'))
      .margin({ bottom: 8 })
      .transition(Motion.reveal())
    }
  }
}
