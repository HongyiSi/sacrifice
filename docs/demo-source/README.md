# 演示复现源文件

本目录被 `.gdignore` 和导出排除项隔离，不进入游戏资源包。录制采用预设输入；棋盘、规则、卡面与动画仍来自正式工程。

需要 Godot 4.7.1、Python 3（安装 Pillow 和 NumPy）、FFmpeg。先在 Godot 中导入工程。下例在工程根目录运行；将可执行文件路径替换为自己的安装位置。

```powershell
& 'D:\path\Godot.exe' --path . --resolution 1440x960 `
  --script docs/demo-source/capture.gd `
  --log-file test-results/gameplay-capture.log `
  -- --output=D:/capture-work/frames

python docs/demo-source/encode.py `
  --project . --work D:/capture-work --output D:/gameplay-output `
  --ffmpeg D:/path/ffmpeg.exe
```

`capture.gd` 在输出目录生成逐帧 JPEG 与 `timeline.json`，并断言两个取义分支的结局。时间线包含正式 `attack_audio.gd` 调度器提供的音效文件、延迟、增益、阶段截断标记和局面切换边界；出牌落点也沿用正式卡牌移动音效。追加 `--preview` 只采样关键时点，输出目录追加 `-preview`，用于快速检查，不能直接作为 30 FPS 成片输入。

`encode.py` 生成 1080p MP4、封面、游戏截图与清单，并调用 `mix_audio.py` 合成配乐及游戏音效。没有声音时间线时会报错，避免再次产生只有配乐的成片。检查成片后，可将三份媒体复制到工程的 `docs/media`；或重跑编码命令并增加 `--install`。包装默认使用 Windows 的 Microsoft YaHei；其他平台可通过 `--font`、`--bold-font` 指定可用的中文字体。不随仓库分发该字体。

保留正式的完整效果时长，只把等待人工输入的时间固定为短停留。先更新卡牌位置，再调用正式 Cinema 特效的 `present(seconds)`；不要把 `clock_started` 清成 -1 再调用其 `_process`，否则真实时钟会使动画直接结束。时间线记录逐帧的飞剑 / 魔法弹位置和采样时间，便于对照检查。编码添加章节解释侧栏、4 秒片头和片尾，以及混合音轨；素材来源和修改说明见[视频说明](../demo.md)。

## 只补声音、保留原视频画面

给录制命令追加 `--audio-only`（可使用 Godot `--headless`）会只导出完整的声音与结算时间线，不生成图片。必须先核对新旧时间线的帧数、每段起止帧、阶段、生命值与徽章完全相同，才能为已有视频替换音轨；如不相同，应重新录制完整视频。

```powershell
python docs/demo-source/mix_audio.py `
  --project . --timeline D:/capture-work/frames/timeline.json `
  --output D:/gameplay-output/demo-mix.wav --ffmpeg D:/path/ffmpeg.exe `
  --video docs/media/sacrifice-gameplay-demo.mp4 `
  --output-video D:/gameplay-output/sacrifice-gameplay-demo.mp4
```

混音使用 48 kHz 双声道，保留原音效的相对增益与释放尾音；阶段截断使用 5 毫秒淡出以避免爆音。配乐在声音事件前后平滑降低，且只在混合峰值超限时整体衰减。输出还包含独立配乐、音效 WAV 与音效文件散列，供复核；这些制作中间文件无需提交到仓库。已有视频使用 `-c:v copy` 保留原画面流。

画面来自 2026-10-21 的录制，音轨于 2026-10-22 按 0.20.72 的正式声音调度补齐；已核对全部画面时间线和结局仍一致。之后若修改规则或素材，重新录制的结果可能变化，不能拿旧时间线替代新一次验证。
