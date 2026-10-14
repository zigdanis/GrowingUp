"""Render real-time native segments; no speed changes, synthetic UI, or device frames."""
import argparse,json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('edit');p.add_argument('output');p.add_argument('--locale',default='en');p.add_argument('--width',type=int,default=886);p.add_argument('--height',type=int,default=1920);a=p.parse_args()
root=Path(__file__).resolve().parent; edit=json.loads(Path(a.edit).read_text()); W,H=a.width,a.height
out=Path(a.output);out.parent.mkdir(parents=True,exist_ok=True)
fontroot=Path.cwd()/'marketing/fonts'
card=Image.new('RGBA',(W,H));d=ImageDraw.Draw(card)
scale=W/886
f=lambda size,bold=False: ImageFont.truetype(str(fontroot/('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf')),round(size*scale))
title='GrowingUp'; subtitle='Они растут. Ты помнишь.' if a.locale=='ru' else 'They grow. You remember.'
y=round(H*.77);left=round(W*.06);right=W-left
# Only copy is composited over the real app, clear of its age and pager.
d.rounded_rectangle((left,y,right,y+round(150*scale)),radius=round(22*scale),fill=(6,15,19,200))
for text,size,bold,yy in [(title,42,True,y+round(21*scale)),(subtitle,30,False,y+round(83*scale))]:
    ft=f(size,bold);box=d.textbbox((0,0),text,font=ft);tw=box[2]-box[0];d.text(((W-tw)/2,yy),text,font=ft,fill='white')
png=out.with_suffix('.intro.png');card.save(png)
native_files=[]
for segment in edit['segments']:
    filename=segment.get('native_file',edit['native_file'])
    if filename not in native_files:native_files.append(filename)
png_index=len(native_files);audio_index=png_index+1
filters=[]
used_frames=0
for i,s in enumerate(edit['segments']):
    source_index=native_files.index(s.get('native_file',edit['native_file']))
    first=round(s['start']*30)
    last=round(s['end']*30)
    if i==len(edit['segments'])-1:
        last=first+(750-used_frames)
    used_frames+=last-first
    # Resample the full native display timeline before cutting, preserving held UI frames.
    # Cuts are snapped to the 30fps grid; source animation speed is never remapped.
    filters.append(f"[{source_index}:v]fps=30,trim=start_frame={first}:end_frame={last},setpts=PTS-STARTPTS,scale={W}:{H}:force_original_aspect_ratio=decrease:force_divisible_by=2:flags=lanczos,pad={W}:{H}:(ow-iw)/2:(oh-ih)/2,setsar=1[v{i}]")
labels=''.join(f'[v{i}]' for i in range(len(edit['segments'])))
filters.append(f'{labels}concat=n={len(edit["segments"])}:v=1:a=0[base]')
filters.append(f"[base][{png_index}:v]overlay=0:0:enable='lt(t,4)'[captioned]")
filters.append("[captioned]fade=t=in:st=0:d=0.18,fade=t=out:st=24.7:d=0.3,format=yuv420p[v]")
filters.append(f'[{audio_index}:a]atrim=duration=25,loudnorm=I=-20:TP=-2:LRA=8,aresample=48000[a]')
native_args=[arg for filename in native_files for arg in ['-i',filename]]
cmd=['ffmpeg','-hide_banner','-y',*native_args,'-loop','1','-i',str(png),'-i',str(root/'music/Little-Days.wav'),'-filter_complex',';'.join(filters),'-map','[v]','-map','[a]','-t','25','-c:v','libx264','-preset','slow','-profile:v','high','-level:v','4.0','-b:v','11M','-minrate','11M','-maxrate','11M','-bufsize','22M','-x264-params','nal-hrd=cbr:force-cfr=1','-pix_fmt','yuv420p','-c:a','aac','-b:a','256k','-ar','48000','-ac','2','-movflags','+faststart',str(out)]
(out.with_suffix('.ffmpeg-command.json')).write_text(json.dumps(cmd,indent=2))
with out.with_suffix('.render.log').open('w') as log:subprocess.run(cmd,stdout=log,stderr=log,check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(out)]))
out.with_suffix('.ffprobe.json').write_text(json.dumps(probe,indent=2))
print(out)
