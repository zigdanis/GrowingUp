"""Render passed native journeys sequentially, with exact metadata and no time remapping."""
from pathlib import Path
import json,subprocess,sys,hashlib
root=Path.home()/'Library/Application Support/GrowingUp/AppStoreMedia/preview-20261013';work=root/'no-confetti';devices=json.loads((work/'devices.json').read_text());index=[];previous=json.loads((work/'exports.json').read_text()) if (work/'exports.json').exists() else []
for kind in ['di','face-id','home-button']:
 for locale in ['en','ru']:
  folder=work/kind/locale
  passes=[p for p in folder.glob('*-timeline.json') if json.loads(p.read_text()).get('test_exit_code')==0]
  assert passes,(kind,locale,'no passed capture')
  path=max(passes,key=lambda p:p.stat().st_mtime);ready=next((x for x in previous if x['kind']==kind and x['locale']==locale and x['timeline']==str(path)),None)
  if ready and Path(ready['file']).exists() and hashlib.sha256(Path(ready['file']).read_bytes()).hexdigest()==ready['sha256']:
   index.append(ready);print('REUSE VERIFIED',kind,locale,flush=True);continue
  t=json.loads(path.read_text());m=t['markers'];base=t['recording_started_epoch'];start=m['mia-start']-base;end=m['end']-base;remove=end-start-25
  if remove<=0:
   assert remove>=-1.5,remove
   segments=[{'start':end-25,'end':end}]
  else:
   available=m['editor-change']-m['editor-open']-.5
   assert remove<=available,(kind,locale,remove,available)
   cut=m['editor-open']-base+.4;segments=[{'start':start,'end':cut},{'start':cut+remove,'end':end}]
  edit={'native_file':t['native_file'],'source_timeline':str(path),'segments':segments,'trim_reason':'Only intro/editor stationary dwell adjusted; all UI actions remain native real time. Production Reduce Motion suppressed confetti. No fake animation or app UI code edits.','duration':25}
  (folder/'edit.json').write_text(json.dumps(edit,indent=2));label={'di':'dynamic-island','face-id':'face-id','home-button':'home-button-se3'}[kind];out=root/'final'/f'{label}-{locale}-no-confetti.mp4';w,h=devices[kind]['export_size']
  print('RENDER',kind,locale,flush=True)
  rendercmd=[str(root/'tools-venv/bin/python'),str(root/'render.py'),str(folder/'edit.json'),str(out),'--locale',locale,'--width',str(w),'--height',str(h)]
  subprocess.run(rendercmd,check=True)
  probe=json.loads(out.with_suffix('.ffprobe.json').read_text());video=next(x for x in probe['streams'] if x['codec_type']=='video')
  audio=next(x for x in probe['streams'] if x['codec_type']=='audio')
  subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
  assert (video['width'],video['height'])==(w,h);assert video['r_frame_rate']=='30/1' and int(video['nb_frames'])==750;assert video['codec_name']=='h264' and video['profile']=='High' and video['level']==40;assert audio['channels']==2 and audio['sample_rate']=='48000';assert float(probe['format']['duration'])==25
  native=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',t['native_file']]))['streams'][0]
  assert [native['width'],native['height']]==devices[kind]['native_size']
  qa=work/'review';qa.mkdir(exist_ok=True)
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(out),'-vf','fps=2,scale=177:384:force_original_aspect_ratio=decrease,pad=177:384:(ow-iw)/2:(oh-ih)/2,tile=10x5','-frames:v','1',str(qa/f'{kind}-{locale}-all.png')],check=True)
  index.append({'kind':kind,'locale':locale,'file':str(out),'size':int(probe['format']['size']),'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'timeline':str(path),'source_native':t['native_file'],'edit':edit,'probe_file':str(out.with_suffix('.ffprobe.json')),'device':devices[kind],'ui_test_passed':True,'full_decode_passed':True,'qa_sheet':str(qa/f'{kind}-{locale}-all.png')})
  (work/'exports.json').write_text(json.dumps(index,indent=2));print('VERIFIED EXPORT',out.name,flush=True)
print('All six exports complete',flush=True)
