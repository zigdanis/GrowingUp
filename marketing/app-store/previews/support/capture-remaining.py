"""Own simulator captures, strictly one booted device, no cloud jobs or production UI changes."""
import json,plistlib,subprocess,sys
from pathlib import Path
root=Path.home()/'Library/Application Support/GrowingUp/AppStoreMedia/preview-20261013';work=root/'no-confetti';devices=json.loads((work/'devices.json').read_text());cwd=Path.cwd()
forbidden={'ED72CBAC-470D-460C-98C5-7D65236D2E22','1358FC89-2E2B-46AB-8C74-741A7E6B33AE','8F1F3EB7-4247-41C9-85AD-9238318F69B0'}
assert not forbidden & {x['uuid'] for x in devices.values()}
def run(cmd,log=None):
 if log:
  with log.open('w') as stream:subprocess.run(cmd,stdout=stream,stderr=subprocess.STDOUT,check=True)
 else:subprocess.run(cmd,check=True)
def booted():
 j=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']));return [x['udid'] for ds in j['devices'].values() for x in ds if x['state']=='Booted']
def reduce_motion(udid,enabled,backup=False):
 p=Path.home()/f'Library/Developer/CoreSimulator/Devices/{udid}/data/Library/Preferences/com.apple.Accessibility.plist'
 p.parent.mkdir(parents=True,exist_ok=True);d=plistlib.loads(p.read_bytes()) if p.exists() else {}
 if backup and not (work/(udid+'-reduce-motion-before.json')).exists():(work/(udid+'-reduce-motion-before.json')).write_text(json.dumps({'value':d.get('ReduceMotionEnabled')}))
 if enabled is None:d.pop('ReduceMotionEnabled',None)
 else:d['ReduceMotionEnabled']=enabled
 p.write_bytes(plistlib.dumps(d,fmt=plistlib.FMT_BINARY))
di=devices['di']['uuid']
if di in booted():run(['xcrun','simctl','shutdown',di])
reduce_motion(di,False)
for kind in ['face-id','home-button']:
 udid=devices[kind]['uuid'];assert not booted(),booted()
 initialized=work/(udid+'-initialized.json')
 if not initialized.exists():
  print('INITIALIZE DEVICE',kind,flush=True);run(['xcrun','simctl','boot',udid]);run(['xcrun','simctl','bootstatus',udid,'-b']);run(['xcrun','simctl','shutdown',udid]);initialized.write_text(json.dumps({'initialized':True}))
 reduce_motion(udid,True,True)
 try:
  print('START DEVICE',kind,udid,flush=True);run(['xcrun','simctl','boot',udid]);run(['xcrun','simctl','bootstatus',udid,'-b'])
  run(['xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100'])
  for locale in ['en','ru']:
   folder=work/kind/locale;folder.mkdir(parents=True,exist_ok=True)
   passed=[p for p in folder.glob('*-timeline.json') if json.loads(p.read_text()).get('test_exit_code')==0]
   if passed:
    print('REUSE EXISTING',kind,locale,flush=True);continue
   take='capture';n=1
   while (folder/(take+'-native.mp4')).exists():
    n+=1;take='capture'+str(n)
   assert booted()==[udid],booted()
   run([sys.executable,str(root/'seed.py'),udid,locale])
   run(['xcodebuild','build-for-testing','-project','GrowingUp.xcodeproj','-scheme','GrowingUpUI','-destination','id='+udid,'-derivedDataPath',str(root/'DerivedData'),'-parallel-testing-enabled','NO','GROWINGUP_APP_STORE_CAPTURE=1','GROWINGUP_APP_STORE_LOCALE='+locale,'GROWINGUP_APP_STORE_PHOTOS='+str(cwd/'docs/app-store-demo-photos'),'GROWINGUP_VISUAL_CHECKS=0','GROWINGUP_RECORD_SNAPSHOTS=0','CODE_SIGNING_ALLOWED=NO'],folder/'build.log')
   print('CAPTURE',kind,locale,flush=True)
   run([sys.executable,str(root/'record-no-confetti.py'),udid,str(folder),'--locale',locale,'--take',take])
   print('PASSED',kind,locale,flush=True)
 finally:
  if udid in booted():run(['xcrun','simctl','shutdown',udid])
  prior=json.loads((work/(udid+'-reduce-motion-before.json')).read_text())['value'];reduce_motion(udid,prior)
  print('SHUTDOWN DEVICE',kind,flush=True)
print('ALL NATIVE CAPTURES COMPLETE. Booted devices:',booted(),flush=True)
