import base64,json,os,subprocess,sys
from pathlib import Path
device,locale=sys.argv[1:3];root=Path(__file__).resolve().parent
cfg={'identifier':'D11D2026-1013-4000-8000-00000000000'+('2' if locale=='ru' else '1'),'resetStore':False,'seed':'empty','failNextSave':False,'appearance':'dark'}
env=os.environ.copy()
for k,v in {'GROWINGUP_UI_TEST_CONFIGURATION':base64.b64encode(json.dumps(cfg).encode()).decode(),'GROWINGUP_APP_STORE_CAPTURE':'1','GROWINGUP_APP_STORE_PHOTOS':str(Path.cwd()/'docs/app-store-demo-photos'),'GROWINGUP_BIRTHDAY_NOW':'2027-01-16T08:24:12Z','GROWINGUP_BIRTHDAY_CLOCK_RUNNING':'1','TZ':'UTC'}.items():env['SIMCTL_CHILD_'+k]=v
subprocess.run(['xcrun','simctl','terminate',device,'pro.ziganshin.GrowingUp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
subprocess.run(['xcrun','simctl','launch',device,'pro.ziganshin.GrowingUp','-AppleLanguages','('+locale+')','-AppleLocale','ru_RU' if locale=='ru' else 'en_US','-AppleInterfaceStyle','Dark'],env=env,check=True)
