# 演示复现源文件

本目录被 `.gdignore` 和导出排除项隔离，不进入游戏资源包。录制采用预设输入；棋盘、规则、卡面与动画仍来自正式工程。

需要 Godot 4.7.1、Python 3（安装 Pillow）、FFmpeg。先在 Godot 中导入工程。下例在工程根目录运行；将可执行文件路径替换为自己的安装位置。

```powershell
& 'D:\path\Godot.exe' --path . --resolution 1440x960 `
  --script docs/demo-source/capture.gd `
  --log-file test-results/portfolio-capture.log `
  -- --output=D:/capture-work/frames

python docs/demo-source/encode.py `
  --project . --work D:/capture-work --output D:/portfolio-output `
  --ffmpeg D:/path/ffmpeg.exe
```

`capture.gd` 在输出目录生成逐帧 JPEG 与 `timeline.json`，并断言两个取义分支的结局。追加 `--preview` 只采样关键时点，输出目录追加 `-preview`，用于快速检查，不能直接作为 30 FPS 成片输入。

`encode.py` 生成 1080p MP4、封面与清单，并把成片复制到工程的 `docs/media`。包装默认使用 Windows 的 Microsoft YaHei；其他平台可通过 `--font`、`--bold-font` 指定可用的中文字体。不随仓库分发该字体。

保留正式的完整效果时长，只把等待人工输入的时间固定为短停留。编码添加章节解释侧栏、片头片尾与背景音乐；背景音乐的来源和修改说明见[视频说明](../demo.md)。

本次输出对应 2026-10-21 的本地开发版本。之后若修改规则或素材，重新录制的结果可能变化，不能拿旧时间线替代新一次验证。
