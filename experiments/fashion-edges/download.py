import json,subprocess,hashlib
from pathlib import Path
root=Path(__file__).parent/'models'
root.mkdir(exist_ok=True)
revisions={'segmentation':'e2bf8e4460fc8fa32bba5ea4d94b3233d367b0e4','vitmatte':'6a58ad7646403c1df626fbd746900aec7361ea1d'}
for label,repo,files in [('segmentation','ZhengPeng7/BiRefNet',['model.safetensors','config.json']),('vitmatte','hustvl/vitmatte-small-composition-1k',['model.safetensors','config.json','preprocessor_config.json'])]:
 dest=root/label;dest.mkdir(exist_ok=True)
 raw=subprocess.check_output(['curl','-fsSL','https://huggingface.co/api/models/'+repo+'/revision/'+revisions[label]+'?blobs=true'])
 info=json.loads(raw);rev=info['sha'];manifest={'repository':repo,'revision':rev,'files':{}}
 for name in files:
  meta=next((x for x in info['siblings'] if x['rfilename']==name),None)
  if meta is None: print('Unavailable:',repo,name,flush=True);continue
  path=dest/name
  if not path.exists():subprocess.run(['curl','-fL','--retry','3','--silent','--show-error','-o',str(path)+'.partial',f'https://huggingface.co/{repo}/resolve/{rev}/{name}'],check=True);Path(str(path)+'.partial').rename(path)
  sha=hashlib.sha256(path.read_bytes()).hexdigest()
  if meta.get('lfs',{}).get('sha256'):assert sha==meta['lfs']['sha256']
  manifest['files'][name]=sha
  print(label,name,path.stat().st_size,flush=True)
 (dest/'manifest.json').write_text(json.dumps(manifest,indent=2))
