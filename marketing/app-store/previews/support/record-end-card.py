import base64,json,os,signal,subprocess,time,plistlib
from pathlib import Path
root=Path.home()/'Library/Application Support/GrowingUp/AppStoreMedia/preview-20261013';folder=root/'no-confetti/home-button/en';udid='F5581E72-B8D2-41EB-89D3-EA7B2939871B'
assert not (folder/'end-card-native.mp4').exists()
env=os.environ.copy();cfg={'identifier':'D11D2026-1013-4000-8000-000000000001','resetStore':False,'seed':'empty','failNextSave':False,'appearance':'dark'}
for k,v in {'GROWINGUP_UI_TEST_CONFIGURATION':base64.b64encode(json.dumps(cfg).encode()).decode(),'GROWINGUP_APP_STORE_CAPTURE':'1','GROWINGUP_APP_STORE_PHOTOS':str(Path.cwd()/'docs/app-store-demo-photos'),'GROWINGUP_BIRTHDAY_NOW':'2027-01-16T08:24:42Z','GROWINGUP_BIRTHDAY_CLOCK_RUNNING':'1','TZ':'UTC'}.items():env['SIMCTL_CHILD_'+k]=v
subprocess.run(['xcrun','simctl','terminate',udid,'pro.ziganshin.GrowingUp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
subprocess.run(['xcrun','simctl','launch',udid,'pro.ziganshin.GrowingUp','-AppleLanguages','(en)','-AppleLocale','en_US','-AppleInterfaceStyle','Dark'],env=env,check=True)
time.sleep(1)
with (folder/'end-card-record.log').open('w') as log:
 rec=subprocess.Popen(['xcrun','simctl','io',udid,'recordVideo','--codec=hevc',str(folder/'end-card-native.mp4')],stderr=subprocess.PIPE,text=True)
 try:
  for line in rec.stderr:
   log.write(line);log.flush()
   if 'Recording started' in line:break
  begun=time.time();print('Native end-card recording started',flush=True);time.sleep(7)
 finally:rec.send_signal(signal.SIGINT);rec.wait(timeout=20)
(folder/'end-card-clock.json').write_text(json.dumps({'clock':'2027-01-16T08:24:42Z','running':True,'recording_started_epoch':begun,'duration_requested':7,'device':udid,'purpose':'Native final Mia card on same SE3, same persisted EN data; no XCTest teardown during capture.'},indent=2))
subprocess.run(['xcrun','simctl','shutdown',udid],check=True)
p=Path.home()/f'Library/Developer/CoreSimulator/Devices/{udid}/data/Library/Preferences/com.apple.Accessibility.plist';d=plistlib.loads(p.read_bytes());prior=json.loads((root/'no-confetti'/f'{udid}-reduce-motion-before.json').read_text())['value']
if prior is None:d.pop('ReduceMotionEnabled',None)
else:d['ReduceMotionEnabled']=prior
p.write_bytes(plistlib.dumps(d,fmt=plistlib.FMT_BINARY));print('Own SE shut down; preference restored',flush=True)
