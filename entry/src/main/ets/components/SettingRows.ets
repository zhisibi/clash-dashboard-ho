import { Store } from '../common/Store';
import { Palette } from '../common/Theme';
import { SectionTitle } from './Widgets';

/** Settings group: title + card */
@ComponentV2
export struct Group {
  @Param pal: Palette = new Palette();
  @Param title: string = '';
  @BuilderParam content: () => void = this.none;

  @Builder
  none() {
  }

  build() {
    Column() {
      if (this.title.length > 0) {
        SectionTitle({ pal: this.pal, text: this.title })
      } else {
        Blank().height(14)
      }
      Column() {
        this.content()
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })
      .borderRadius(18)
      .attributeModifier(Store.get().glass('card'))
    }
    .width('100%')
  }
}

/** A settings row: title/description + trailing control */
@ComponentV2
export struct RowItem {
  @Param pal: Palette = new Palette();
  @Param title: string = '';
  @Param desc: string = '';
  @Param descColor: string = '';
  @Param clickable: boolean = false;
  @Event onTap: () => void = () => {
  };
  @BuilderParam trailing: () => void = this.none;

  @Builder
  none() {
  }

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor(this.pal.text)
        if (this.desc.length > 0) {
          Text(this.desc)
            .fontSize(13)
            .fontColor(this.descColor.length > 0 ? this.descColor : this.pal.subtle)
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.trailing()
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      if (this.clickable) {
        this.onTap();
      }
    })
  }
}

/** Switch row */
@ComponentV2
export struct SwitchRow {
  @Param pal: Palette = new Palette();
  @Param title: string = '';
  @Param desc: string = '';
  @Param checked: boolean = false;
  @Event onChange: (v: boolean) => void = (v: boolean) => {
  };

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor(this.pal.text)
        if (this.desc.length > 0) {
          Text(this.desc).fontSize(13).fontColor(this.pal.subtle).margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .selectedColor(this.pal.accentUi)
        .onChange((on: boolean) => {
          if (on !== this.checked) {
            this.onChange(on);
          }
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
  }
}

/** Number input row */
@ComponentV2
export struct NumberRow {
  @Param pal: Palette = new Palette();
  @Param title: string = '';
  @Param value: number = 0;
  @Param suffix: string = '';
  @Param placeholder: string = '';
  @Param zeroAsEmpty: boolean = false;
  /** true: applies while typing; false: shows a confirm button that applies on tap */
  @Param live: boolean = true;
  @Local text: string = '';
  @Event onValue: (v: number) => void = (v: number) => {
  };

  aboutToAppear(): void {
    this.text = (this.zeroAsEmpty && this.value === 0) ? '' : this.value.toString();
  }

  @Monitor('value')
  onExternal(): void {
    this.text = (this.zeroAsEmpty && this.value === 0) ? '' : this.value.toString();
  }

  parsed(): number {
    const n = parseInt(this.text);
    return isNaN(n) ? 0 : n;
  }

  build() {
    Row() {
      Text(this.title).fontSize(16).fontColor(this.pal.text).layoutWeight(1)
      TextInput({ text: this.text, placeholder: this.placeholder })
        .type(InputType.Number)
        .maxLength(6)
        .width(110)
        .height(40)
        .fontSize(15)
        .fontColor(this.pal.text)
        .placeholderColor(this.pal.subtle)
        .backgroundColor(this.pal.chip)
        .onChange((v: string) => {
          this.text = v;
          if (this.live && v.length > 0) {
            this.onValue(this.parsed());
          }
        })
      if (this.suffix.length > 0) {
        Text(this.suffix).fontSize(14).fontColor(this.pal.subtle).margin({ left: 6 })
      }
      if (!this.live && this.parsed() !== this.value) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(22)
          .fontColor([this.pal.good])
          .margin({ left: 8 })
          .onClick(() => {
            this.onValue(this.parsed());
          })
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
  }
}

/** Slider row */
@ComponentV2
export struct SliderRow {
  @Param pal: Palette = new Palette();
  @Param title: string = '';
  @Param value: number = 0;
  @Param min: number = 0;
  @Param max: number = 1;
  @Param step: number = 0.01;
  @Param label: string = '';
  @Event onValue: (v: number) => void = (v: number) => {
  };

  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(16).fontColor(this.pal.text).layoutWeight(1)
        Text(this.label).fontSize(13).fontColor(this.pal.subtle)
      }
      .width('100%')

      Slider({ value: this.value, min: this.min, max: this.max, step: this.step })
        .width('100%')
        .selectedColor(this.pal.accentUi)
        .onChange((v: number, mode: SliderChangeMode) => {
          this.onValue(v);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
  }
}
