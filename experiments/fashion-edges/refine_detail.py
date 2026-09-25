import sys,time,json,gc,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'.cache/site-packages'));sys.path.insert(0,str(ROOT/'Runtime'))
import worker
import torch,numpy as np
from PIL import Image,ImageFilter
from transformers import VitMatteImageProcessor,VitMatteForImageMatting
HERE=Path(__file__).parent;OUT=HERE/'results';folder=HERE/'models/vitmatte'
processor=VitMatteImageProcessor.from_pretrained(folder,local_files_only=True)
model=VitMatteForImageMatting.from_pretrained(folder,local_files_only=True).eval().to('mps');torch.set_num_threads(4)
rows=json.loads((OUT/'timings.json').read_text())
for name in ['boot','shirt']:
 box=next(r['box'] for r in rows if r['image']==name and r['variant']=='segmentation-roi')
 full=Image.open(OUT/f'{name}-segmentation-roi.png').convert('RGBA');region=full.crop(box);size=region.size;region.thumbnail((1536,1536));a=region.getchannel('A');binary=a.point(lambda x:255 if x>=128 else 0)
 inner=np.array(binary.filter(ImageFilter.MinFilter(13)))>0;outer=np.array(binary.filter(ImageFilter.MaxFilter(13)))>0
 tri=np.zeros((region.height,region.width),dtype=np.uint8);tri[outer]=128;tri[inner]=255
 inputs=processor(images=region.convert('RGB'),trimaps=Image.fromarray(tri),return_tensors='pt');inputs={k:v.to('mps') for k,v in inputs.items()}
 t=time.monotonic()
 with torch.inference_mode():alpha=model(**inputs).alphas[0,0].float().cpu().numpy()[:region.height,:region.width]
 assert np.isfinite(alpha).all();alpha[tri==0]=0;alpha[tri==255]=1
 a=Image.fromarray((np.clip(alpha,0,1)*255).round().astype('uint8')).resize(size,Image.Resampling.LANCZOS)
 mask=Image.new('L',full.size);mask.paste(a,box[:2]);full.putalpha(mask);full.save(OUT/f'{name}-segmentation-roi-vitmatte-detail.png')
 row={'image':name,'variant':'segmentation-roi-vitmatte-detail','seconds':round(time.monotonic()-t,3),'refinement_size':list(region.size)};rows.append(row);print(json.dumps(row),flush=True)
 del inputs,alpha;gc.collect();torch.mps.empty_cache()
(OUT/'timings.json').write_text(json.dumps(rows,indent=2))
