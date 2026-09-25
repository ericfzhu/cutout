"""Offline fashion-product comparison. No image upload; app files unchanged."""
import os,sys,json,time,gc,resource
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.cache/site-packages'))
sys.path.insert(0,str(ROOT/'Runtime'))
import worker
import torch
import numpy as np
from PIL import Image,ImageFilter
from safetensors.torch import load_file
from model.birefnet import BiRefNet
from model.BiRefNet_config import BiRefNetConfig
HERE=Path(__file__).parent;OUT=HERE/'results';OUT.mkdir(exist_ok=True)
SAMPLES={'boot':Path('/Users/eric/Downloads/867708WCB452010_F.jpg'),'shirt':Path('/Users/eric/Downloads/A4568001_4.webp')}
metrics=[]
def record(name,variant,seconds,**extra):
 row=dict(image=name,variant=variant,seconds=round(seconds,3),peak_process_GiB=round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1024**3,3),**extra)
 metrics.append(row);(OUT/'timings.json').write_text(json.dumps(metrics,indent=2));print(json.dumps(row),flush=True)
def release():
 gc.collect()
 if torch.backends.mps.is_available():torch.mps.empty_cache()
engine=worker.Engine("matting");print('device',engine.device,flush=True)
for variant in ['matting','segmentation']:
 if variant=='segmentation':
  del engine.model;release()
  with torch.device('meta'): engine.model=BiRefNet(config=BiRefNetConfig(bb_pretrained=False))
  weights=load_file(str(HERE/'models/segmentation/model.safetensors'))
  engine.model.load_state_dict(weights,strict=True,assign=True);del weights
  engine.model.eval().requires_grad_(False).to(device=engine.device,dtype=engine.dtype)
 for name,src in SAMPLES.items():
  t=time.monotonic();engine.remove(src,OUT/f'{name}-{variant}.png');record(name,variant,time.monotonic()-t)
  # Second pass focuses on the subject bounds to spend more of the 1024 input on it.
  prior=Image.open(OUT/f'{name}-matting.png').convert('RGBA');a=np.array(prior.getchannel('A'));ys,xs=np.nonzero(a>127)
  pad=int(max(xs.max()-xs.min(),ys.max()-ys.min())*.10)
  box=(max(0,int(xs.min())-pad),max(0,int(ys.min())-pad),min(prior.width,int(xs.max())+pad+1),min(prior.height,int(ys.max())+pad+1))
  original=Image.open(src).convert('RGBA');roi=OUT/f'{name}-roi-input.png';original.crop(box).save(roi)
  t=time.monotonic();engine.remove(roi,OUT/f'{name}-{variant}-roi-local.png')
  local=Image.open(OUT/f'{name}-{variant}-roi-local.png').getchannel('A');alpha=Image.new('L',original.size,0);alpha.paste(local,box[:2]);original.putalpha(alpha);original.save(OUT/f'{name}-{variant}-roi.png');record(name,variant+'-roi',time.monotonic()-t,box=box)
del engine;release()
# Boundary refinement: small model, aspect-preserving long edge capped at 1024.
from transformers import VitMatteImageProcessor,VitMatteForImageMatting
folder=HERE/'models/vitmatte';processor=VitMatteImageProcessor.from_pretrained(folder,local_files_only=True)
refiner=VitMatteForImageMatting.from_pretrained(folder,local_files_only=True).eval()
device='mps' if torch.backends.mps.is_available() else 'cpu';refiner.to(device);torch.set_num_threads(4)
for name,src in SAMPLES.items():
 original=Image.open(src).convert('RGB');small=original.copy();small.thumbnail((1024,1024))
 for source in ['matting','segmentation','segmentation-roi']:
  alpha=Image.open(OUT/f'{name}-{source}.png').getchannel('A').resize(small.size,Image.Resampling.LANCZOS)
  # Leave a 6px unknown band around the 50% contour (12px total).
  binary=alpha.point(lambda x:255 if x>=128 else 0)
  inner=np.array(binary.filter(ImageFilter.MinFilter(13)))>0
  outer=np.array(binary.filter(ImageFilter.MaxFilter(13)))>0
  tri=np.zeros((small.height,small.width),dtype=np.uint8);tri[outer]=128;tri[inner]=255
  inputs=processor(images=small,trimaps=Image.fromarray(tri),return_tensors='pt');inputs={k:v.to(device) for k,v in inputs.items()}
  t=time.monotonic()
  with torch.inference_mode():pred=refiner(**inputs).alphas[0,0].float().cpu().numpy()[:small.height,:small.width]
  assert np.isfinite(pred).all()
  pred[tri==0]=0;pred[tri==255]=1
  mask=Image.fromarray((np.clip(pred,0,1)*255).round().astype('uint8')).resize(original.size,Image.Resampling.LANCZOS)
  result=original.convert('RGBA');result.putalpha(mask);result.save(OUT/f'{name}-{source}-vitmatte.png')
  record(name,source+'-vitmatte',time.monotonic()-t,refinement_size=list(small.size))
  del inputs,pred;release()
print('COMPLETE',flush=True)
