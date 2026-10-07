import { fileIo, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';

/** 文件、剪贴板、分享等工具 */
export class FileUtil {
  static exists(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (e) {
      return false;
    }
  }

  static ensureDir(path: string): void {
    try {
      if (!fileIo.accessSync(path)) {
        fileIo.mkdirSync(path, true);
      }
    } catch (e) {
      // ignore
    }
  }

  static writeText(path: string, text: string): void {
    const f = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(f.fd, text);
    } finally {
      fileIo.closeSync(f);
    }
  }

  static readText(path: string): string {
    try {
      return fileIo.readTextSync(path);
    } catch (e) {
      return '';
    }
  }

  static remove(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (e) {
      // ignore
    }
  }

  static list(dir: string): string[] {
    try {
      return fileIo.listFileSync(dir);
    } catch (e) {
      return [];
    }
  }

  /** 从系统选择器返回的 uri 复制到沙箱路径 */
  static copyUriTo(uri: string, dest: string): void {
    const src = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      fileIo.copyFileSync(src.fd, dest);
    } finally {
      fileIo.closeSync(src);
    }
  }

  /** 通过系统文件选择器“另存为”，返回保存的文件名；用户取消返回空串 */
  static async saveTextAs(ctx: common.Context, name: string, text: string): Promise<string> {
    const opts = new picker.DocumentSaveOptions();
    opts.newFileNames = [name];
    opts.fileSuffixChoices = ['文本文件|.txt'];
    const p = new picker.DocumentViewPicker(ctx);
    const uris = await p.save(opts);
    if (uris === undefined || uris.length === 0) {
      return '';
    }
    const f = fileIo.openSync(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(f.fd, text);
    } finally {
      fileIo.closeSync(f);
    }
    return name;
  }

  static copyText(text: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).catch((e: BusinessError) => {
      console.error('pasteboard failed ' + e.code);
    });
  }

  static async shareText(ctx: common.UIAbilityContext, title: string, text: string): Promise<void> {
    const rec: systemShare.SharedRecord = {
      utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
      content: text,
      title: title
    };
    const data = new systemShare.SharedData(rec);
    const controller = new systemShare.ShareController(data);
    await controller.show(ctx, {
      previewMode: systemShare.SharePreviewMode.DEFAULT,
      selectionMode: systemShare.SelectionMode.SINGLE
    });
  }
}
