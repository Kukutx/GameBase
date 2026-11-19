import numpy as np, wave, sys, os, subprocess
SR=44100
out=sys.argv[1]
rng=np.random.default_rng(7)
def ks(freq, dur, bright=0.5, decay=0.996):
    n=int(SR*dur); p=int(SR/freq)
    buf=rng.uniform(-1,1,p)
    # soften the excitation
    for _ in range(int((1-bright)*4)): buf=0.5*(buf+np.roll(buf,1))
    y=np.zeros(n)
    for i in range(n):
        y[i]=buf[i%p]
        buf[i%p]=decay*0.5*(buf[i%p]+buf[(i+1)%p])
    return y
def env(n, a=0.005, d=0.3):
    t=np.arange(n)/SR
    return np.minimum(t/a,1)*np.exp(-t/d)
def sine(f,dur,d=0.3,a=0.003):
    n=int(SR*dur); t=np.arange(n)/SR
    return np.sin(2*np.pi*f*t)*env(n,a,d)
def noise(dur,d=0.05):
    n=int(SR*dur); return rng.uniform(-1,1,n)*env(n,0.002,d)
def lowpass(x,a=0.2):
    y=np.zeros_like(x); s=0
    for i,v in enumerate(x): s+=a*(v-s); y[i]=s
    return y
def add(*s):
    n=max(len(x) for x in s); y=np.zeros(n)
    for x in s: y[:len(x)]+=x
    return y
def mix(parts,dur):
    y=np.zeros(int(SR*dur))
    for start,sig in parts:
        i=int(start*SR); sig=sig[:len(y)-i]; y[i:i+len(sig)]+=sig
    return y
def echo(x, delay=0.28, fb=0.35, n=4):
    y=x.copy(); d=int(delay*SR)
    for k in range(1,n+1):
        y[d*k:]+=x[:len(x)-d*k]*(fb**k)
    return y
def save(name,y,peak=0.8,ogg=False):
    y=y/ (np.max(np.abs(y))+1e-9)*peak
    fade=int(0.01*SR); y[-fade:]*=np.linspace(1,0,fade)
    data=(y*32767).astype(np.int16)
    path=os.path.join(out,name+".wav")
    with wave.open(path,"w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    if ogg:
        subprocess.run(["ffmpeg","-y","-loglevel","error","-i",path,"-c:a","libvorbis","-q:a","4",os.path.join(out,name+".ogg")],check=True)
        os.remove(path)
# D major pentatonic
def note(n): return 293.66*2**(n/12)
PENT=[0,2,4,7,9,12,14,16,19,21,24]
save("tap", add(lowpass(noise(0.08,0.012),0.5)*0.6, sine(820,0.12,0.03), 0.5*sine(1640,0.1,0.015)), 0.6)
save("cheer", mix([(0,ks(note(7),0.6,0.7)),(0.09,ks(note(12),0.7,0.7))],0.8), 0.7)
clang=sum(sine(f,0.35,d,0.001)*g for f,d,g in [(2140,0.12,1),(3390,0.08,0.7),(5230,0.05,0.5),(1270,0.18,0.4)])
save("clash", add(clang,lowpass(noise(0.35,0.02),0.6)*0.8), 0.45)
save("defeat", mix([(0,ks(note(-5),0.9,0.4,0.995)),(0.16,ks(note(-10),1.0,0.4,0.995))],1.1), 0.6)
save("victory", echo(mix([(0.0,ks(note(0),0.9)),(0.1,ks(note(4),0.9)),(0.2,ks(note(7),0.9)),(0.3,ks(note(12),1.2,0.8))],1.6)), 0.75)
save("layer", echo(mix([(0,ks(note(14),0.9,0.8)),(0,sine(note(26),0.9,0.35)*0.3)],1.0),0.22,0.3,3), 0.6)
gong=sum(sine(f,3.5,d,0.01)*g for f,d,g in [(98,1.6,1),(147.5,1.2,0.6),(209,0.9,0.5),(263,0.7,0.35),(331,0.5,0.25)])
gong*=1+0.15*np.sin(2*np.pi*3*np.arange(len(gong))/SR)
arp=mix([(0.25+0.11*i,ks(note(PENT[i+2]),1.4,0.8)) for i in range(6)],3.5)
save("breakthrough", add(gong*0.9,echo(arp,0.3,0.3,3)*0.8), 0.85)
swish=lowpass(rng.uniform(-1,1,int(SR*0.35)),0.15)*np.sin(np.linspace(0,np.pi,int(SR*0.35)))**2
save("study", mix([(0,swish*0.7),(0.12,ks(note(9),0.6,0.6))],0.75), 0.6)
save("scroll", swish, 0.45)
# Music: a slow pentatonic guqin line over a soft drone, 48 s, loops.
dur=48.0; bpm=66; beat=60/bpm
mel=[]; t=0.0; idx=4
seq_rng=np.random.default_rng(3)
while t<dur-4:
    step=seq_rng.choice([-2,-1,-1,1,1,2,0])
    idx=int(np.clip(idx+step,0,len(PENT)-1))
    length=seq_rng.choice([1,1,2,2,3])*beat
    mel.append((t,ks(note(PENT[idx]-12),min(length+1.5,4),0.6,0.9985)*0.8))
    if seq_rng.random()<0.25:
        mel.append((t+beat*0.5,ks(note(PENT[idx]-12+12),1.5,0.5,0.998)*0.35))
    t+=length
line=echo(mix(mel,dur+4),0.42,0.3,5)
tail=line[int(dur*SR):]; line=line[:int(dur*SR)]; line[:len(tail)]+=tail
n=int(dur*SR); tt=np.arange(n)/SR
drone=(np.sin(2*np.pi*note(-24)*tt)+0.5*np.sin(2*np.pi*note(-17)*tt))*0.12*(0.8+0.2*np.sin(2*np.pi*tt/12))
save("music_mountain", line+drone, 0.6, ogg=True)
