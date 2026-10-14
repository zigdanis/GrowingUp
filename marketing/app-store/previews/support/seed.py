"""Copy only this task's fictional, UI-created fixture into an explicitly selected simulator."""
import argparse,sqlite3,subprocess,shutil
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('device');p.add_argument('locale',choices=['en','ru']);a=p.parse_args()
root=Path(__file__).resolve().parent
app=root/'DerivedData/Build/Products/Debug-iphonesimulator/GrowingUp.app'
subprocess.run(['xcrun','simctl','install',a.device,str(app)],check=True)
container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.device,'pro.ziganshin.GrowingUp','data'],text=True).strip())
uuid='D11D2026-1013-4000-8000-00000000000'+('2' if a.locale=='ru' else '1')
dst=container/'Library/Application Support/UITests'/uuid
# Only the explicitly named task fixture can be replaced, never the live store.
if dst.exists():shutil.rmtree(dst)
shutil.copytree(root/'fixture-baseline',dst)
if a.locale=='ru':
 with sqlite3.connect(dst/'people.sqlite') as db:
  for en,ru in zip(['Mia','Leo','Mango','Teddy'],['Мия','Лео','Манго','Тедди']):db.execute('update ZCOREDATAPERSON set ZNAME=? where ZNAME=?',(ru,en))
print(dst)
