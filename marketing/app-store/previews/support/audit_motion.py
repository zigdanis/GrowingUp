import argparse,json,subprocess
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('timeline');a=p.parse_args();t=json.loads(Path(a.timeline).read_text());base=t['recording_started_epoch'];m=t['markers']
frames=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v','-show_entries','frame=best_effort_timestamp_time','-of','json',t['native_file']]))['frames'];pts=[float(f['best_effort_timestamp_time']) for f in frames]
for title,begin,end in [('confetti',m['leo-arrived']-base+.1,m['leo-arrived']-base+3.3),('swipe',m['leo-swipe']-base,m['leo-arrived']-base),('editor',m.get('mia-returned',0)-base,m.get('editor-open',0)-base)]:
 gaps=[b-a for a,b in zip(pts,pts[1:]) if begin<=a<=end]
 print(title,{'start':round(begin,3),'end':round(end,3),'frames':len(gaps),'max_gap':round(max(gaps,default=0),3),'gaps_over_100ms':sum(x>.1 for x in gaps)})
