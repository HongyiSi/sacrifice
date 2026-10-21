from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, subprocess, shutil, hashlib
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--work',required=True,type=Path,help='Directory containing frames/timeline.json')
parser.add_argument('--project',required=True,type=Path)
parser.add_argument('--output',required=True,type=Path)
parser.add_argument('--ffmpeg',required=True,type=Path)
parser.add_argument('--font',default='C:/Windows/Fonts/msyh.ttc')
parser.add_argument('--bold-font',default='C:/Windows/Fonts/msyhbd.ttc')
args=parser.parse_args()
W=args.work.resolve();P=args.project.resolve();OUT=args.output.resolve();OUT.mkdir(parents=True,exist_ok=True)
MEDIA=P/'docs/media';MEDIA.mkdir(parents=True,exist_ok=True)
FF=args.ffmpeg.resolve()
FPS=30; SIZE=(1920,1080)
FONT=args.font; BOLD=args.bold_font
def font(n,bold=False):return ImageFont.truetype(BOLD if bold else FONT,n)
gold='#dcb67a';cream='#f3e6ce';muted='#b6aaa0';ink='#201d21'
spec={
'planning':('01 / 同时决策','三枚棋子\n三份手牌','每个棋子独立持牌。\n同时选牌，确认后结算。','目标','击败敌方全队，\n或集齐四枚胜利徽章。'),
'priority':('02 / 结算顺序','行动快慢\n也是资源','主优先级决定翻牌批次，\n次优先级决定批次内顺序。','观察','打击先于魔法打击结算；\n更高的伤害需要等待。'),
'death-risk':('03 / 核心取舍','这一刀\n真的该砍吗？','对方已有两枚胜利徽章，\n濒死棋子持有「取义」，\n并且还有存活的队友。','结果','击杀 → 亡语触发\n对方集齐四枚徽章获胜。'),
'alternative':('04 / 对照选择','留它活着\n改换目标','回到相同的预设局面，\n这次攻击另一个棋子。','结果','取义暂不触发。\n对方仍只有两枚徽章，\n对局继续。')}
def lines(d,xy,text,size=26,fill=cream,bold=False,gap=1.55):
 x,y=xy
 for line in text.split('\n'):
  d.text((x,y),line,font=font(size,bold),fill=fill);y+=int(size*gap)
 return y
def panel(key):
 im=Image.new('RGB',SIZE,ink);d=ImageDraw.Draw(im)
 d.rectangle((0,0,7,1080),fill=gold)
 lines(d,(42,50),'SACRIFICE',25,gold,True)
 lines(d,(40,92),'牺牲',48,cream,True)
 d.line((42,176,378,176),fill='#695842',width=2)
 no,title,body,tag,result=spec[key]
 lines(d,(42,211),no,23,gold)
 lines(d,(38,276),title,45,cream,True,gap=1.4)
 lines(d,(42,448),body,24,cream)
 lines(d,(42,638),tag,23,gold,True)
 lines(d,(42,684),result,24,cream)
 lines(d,(42,925),'系统策划作品 · 开发中',21,gold)
 lines(d,(42,967),'预设局面 / 正式规则结算\n画面来自当前游戏引擎',18,muted,gap=1.5)
 d.rectangle((438,58,1882,1022),outline='#92734b',width=2)
 return im
def title(end=False):
 im=Image.new('RGB',SIZE,ink);d=ImageDraw.Draw(im)
 shot=Image.open(W/'frames/frame-00001.jpg').convert('RGB').resize((1152,768))
 im.paste(shot,(728,155));d=ImageDraw.Draw(im)
 d.rectangle((0,0,7,1080),fill=gold)
 lines(d,(64,83),'SACRIFICE  /  DEVELOPMENT SHOWCASE',25,gold)
 lines(d,(57,203),'牺牲',104,cream,True)
 lines(d,(64,373),'死亡，是另一种行动。' if not end else '把设计问题\n变成可验证的局面。',43,cream,True)
 lines(d,(64,550),'双人卡牌策略游戏\n游戏策划 / 系统策划作品',29,cream)
 lines(d,(64,710),'同时选牌 · 优先级结算 · 亡语博弈' if not end else '规则设计 · 对照测试 · 体验迭代',25,gold)
 lines(d,(64,813),'演示使用预设局面与正式游戏逻辑。\n当前版本仍在打磨，不提供稳定试玩承诺。',22,muted)
 lines(d,(64,953),'HongyiSi / sacrifice   ·   2026.10',25,gold)
 lines(d,(730,957),'音乐：Woodland Fantasy — Matthew Pablo · CC BY 3.0',19,muted)
 return im

info=json.loads((W/'frames/timeline.json').read_text(encoding='utf8'))
intro_n=150;end_n=180;total=intro_n+info['frames']+end_n
output=OUT/'sacrifice-system-design-demo.mp4'
cmd=[str(FF),'-y','-v','warning','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r',str(FPS),'-i','pipe:0','-stream_loop','-1','-i',str(P/'assets/music/woodland_fantasy.mp3'),'-map','0:v:0','-map','1:a:0','-c:v','libx264','-preset','fast','-crf','21','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-af',f'volume=0.24,afade=t=in:d=1.5,afade=t=out:st={total/FPS-3}:d=3','-t',str(total/FPS),'-movflags','+faststart',str(output)]
with (W/'encode.log').open('wb') as log:
 proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stderr=log,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 def write(im):proc.stdin.write(im.tobytes())
 cover=title();cover.save(OUT/'portfolio-cover.jpg',quality=94);cover.save(MEDIA/'portfolio-cover.jpg',quality=94)
 for i in range(intro_n):write(cover)
 panels={k:panel(k) for k in spec}
 for seg in info['segments']:
  for idx in range(seg['first'],seg['last']+1):
   im=panels[seg['chapter']].copy();im.paste(Image.open(W/'frames'/f'frame-{idx:05}.jpg'),(440,60))
   d=ImageDraw.Draw(im);d.rectangle((440,1044,1880,1047),fill='#4a3e33');d.rectangle((440,1044,440+1440*(idx+1)/info['frames'],1047),fill=gold)
   write(im)
 final=title(True)
 for i in range(end_n):write(final)
 proc.stdin.close();result=proc.wait(timeout=120)
 if result:raise RuntimeError('encoding failed; see encode.log')
shutil.copy2(output,MEDIA/output.name)
shutil.copy2(W/'frames/frame-00001.jpg',MEDIA/'gameplay.jpg')
manifest={'video':output.name,'size_bytes':output.stat().st_size,'duration_seconds':total/FPS,'fps':FPS,'resolution':SIZE,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'rendered_gameplay_frames':info['frames'],'music':'Woodland Fantasy — Matthew Pablo, CC BY 3.0; excerpt, gain and fades','segments':info['segments'],'assertions':info['assertions']}
(OUT/'video-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
(W/'video-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({k:v for k,v in manifest.items() if k not in ['segments']},ensure_ascii=False),flush=True)
