"""Little Days: original procedural score, no samples or third-party melodies."""
import json, math, wave
from pathlib import Path
import numpy as np
SR=48000; DUR=25.0; BPM=110; beat=60/BPM
root=Path(__file__).resolve().parent
mix=np.zeros((int(SR*DUR),2),dtype=np.float64)
notes=[]
rng=np.random.default_rng(10132026)
def add(midi,start,length,gain,pan,voice='marimba'):
    start=max(0,start); n=min(int(SR*length),len(mix)-int(SR*start))
    if n<=0:return
    t=np.arange(n)/SR; f=440*2**((midi-69)/12)
    if voice=='marimba':
        env=(1-np.exp(-t/0.003))*np.exp(-t/0.28)
        sig=np.sin(2*np.pi*f*t)+0.24*np.sin(2*np.pi*f*3.99*t)*np.exp(-t/0.06)+0.06*np.sin(2*np.pi*f*7.7*t)*np.exp(-t/0.025)
    elif voice=='chord':
        env=(1-np.exp(-t/0.035))*np.exp(-t/0.65)
        sig=np.sin(2*np.pi*f*t)+0.16*np.sin(2*np.pi*2*f*t)+0.035*np.sin(2*np.pi*3*f*t)
    else:
        env=(1-np.exp(-t/0.015))*np.exp(-t/0.33)
        sig=np.sin(2*np.pi*f*t)+0.12*np.sin(2*np.pi*2*f*t)
    env*=np.minimum(1,(length-t)/0.1).clip(0,1)
    v=sig*env*gain; k=int(start*SR)
    mix[k:k+n,0]+=v*math.cos((pan+1)*math.pi/4)
    mix[k:k+n,1]+=v*math.sin((pan+1)*math.pi/4)
    notes.append(dict(midi=midi,start=round(start,4),duration=length,voice=voice))
chords=[[60,64,67,71],[57,60,64,67],[53,57,60,64],[55,60,62,67], [60,64,67,72],[57,60,64,71],[53,57,60,67],[55,59,62,67], [60,64,67,71],[53,57,60,64],[55,59,62,67],[60,64,67,72]]
melodies=[[76,79,74,76,72],[76,72,71,74,76],[77,76,72,69,72],[74,79,77,74,71], [79,76,81,79,76],[76,74,72,71,69],[72,77,76,74,72],[71,74,79,77,74], [76,79,84,81,79],[77,76,72,69,72],[74,71,67,71,74],[76,79,72]]
for bar,(chord,melody) in enumerate(zip(chords,melodies)):
    at=bar*4*beat
    for j,m in enumerate(chord): add(m,at+j*0.012,1.9,0.055,-0.32+j*.21,'chord')
    add(chord[0]-24,at,1.0,.16,0,'bass')
    if bar<11:add(chord[0]-24,at+2*beat,.8,.105,0,'bass')
    positions=[0,.75,1.5,2.5,3.25] if len(melody)==5 else [0,1,2]
    for j,(m,pos) in enumerate(zip(melody,positions)):
        add(m,at+pos*beat,1.1,.11,-.2+.1*(j%5))
    if bar<11:
        for eighth in range(8):
            st=at+(eighth/2)*beat
            k=int(st*SR); n=min(int(.065*SR),len(mix)-k)
            if n<=0:continue
            noise=rng.normal(size=n); noise=np.r_[0,np.diff(noise)]
            t=np.arange(n)/SR; sig=noise*np.exp(-t/.012)*(.012 if eighth%2 else .007)
            mix[k:k+n,0]+=sig*.65;mix[k:k+n,1]+=sig*.75
# A small stereo room, with no outside assets.
for delay,gain in [(.043,.10),(.079,.065),(.121,.04)]:
    k=int(delay*SR); mix[k:]+=mix[:-k,::-1]*gain
fade=np.minimum(np.arange(len(mix))/SR/.25,1)*np.minimum((DUR-np.arange(len(mix))/SR)/1.2,1)
mix*=fade[:,None]
peak=np.max(np.abs(mix)); mix*=.76/peak
pcm=(mix*32767).astype('<i2')
with wave.open(str(root/'Little-Days.wav'),'wb') as w:
    w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
(root/'score.json').write_text(json.dumps({'title':'Little Days','bpm':BPM,'duration':DUR,'sample_rate':SR,'notes':notes,'origin':'Original procedural composition created for Danis; all synthesis from mathematical oscillators and seeded noise. No third-party samples or melodies used.','marketing_rights':'Danis may use, edit and distribute this generated score in GrowingUp marketing worldwide.'},indent=2))
print('Peak',np.max(np.abs(mix)),'RMS',np.sqrt(np.mean(mix**2)), 'stereo correlation', np.corrcoef(mix.T)[0,1])
