import argparse,json,os,signal,subprocess,time,plistlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('device');p.add_argument('directory');p.add_argument('--locale',default='en');p.add_argument('--take',default='take1');a=p.parse_args()
root=Path.home()/'Library/Application Support/GrowingUp/AppStoreMedia/preview-20261013'
out=Path(a.directory);out.mkdir(parents=True,exist_ok=True)
video=out/(a.take+'-native.mp4');log=out/(a.take+'-journey.log')
assert not video.exists()
record_log=open(out/(a.take+'-record.log'),'w')
rec=subprocess.Popen(['xcrun','simctl','io',a.device,'recordVideo','--codec=hevc',str(video)],stderr=subprocess.PIPE,stdout=subprocess.DEVNULL,text=True)
receipt={'device':a.device,'locale':a.locale,'native_file':str(video),'host_launch_epoch':time.time(),'markers':{}}
for line in rec.stderr:
    record_log.write(line);record_log.flush()
    if 'Recording started' in line:
        receipt['recording_started_epoch']=time.time();break
cmd=['xcodebuild','test-without-building','-project','GrowingUp.xcodeproj','-scheme','GrowingUpUI','-destination','id='+a.device,'-derivedDataPath',str(root/'DerivedData'),'-parallel-testing-enabled','NO','-only-testing:GrowingUpUITests/AppStoreScreenshotTests/testRecordAppPreview','-resultBundlePath',str(out/(a.take+'.xcresult')),'GROWINGUP_APP_STORE_CAPTURE=1','GROWINGUP_APP_STORE_LOCALE='+a.locale,'GROWINGUP_APP_STORE_PHOTOS='+str(Path.cwd()/'docs/app-store-demo-photos'),'GROWINGUP_VISUAL_CHECKS=0','GROWINGUP_RECORD_SNAPSHOTS=0','CODE_SIGNING_ALLOWED=NO']
try:
    with open(log,'w') as stream:
        proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        for line in proc.stdout:
            stream.write(line);stream.flush()
            if 'PREVIEW_MARK ' in line:
                words=line.strip().split('PREVIEW_MARK ')[-1].split();receipt['markers'][words[0]]=float(words[1]);print(line.strip(),flush=True)
            elif 'error:' in line or 'failed' in line.lower():print(line.strip(),flush=True)
        receipt['test_exit_code']=proc.wait()
finally:
    rec.send_signal(signal.SIGINT)
    try:rec.wait(timeout=20)
    except subprocess.TimeoutExpired:rec.terminate();rec.wait()
    record_log.close()
    (out/(a.take+'-timeline.json')).write_text(json.dumps(receipt,indent=2))
print('Recording completed:',video,flush=True)
raise SystemExit(receipt.get('test_exit_code',1))
