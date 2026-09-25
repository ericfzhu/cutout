from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).parent/'results'
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20)
variants=[('matting','Current matting'),('matting-roi','Matting: product-focused'),('segmentation','Segmentation'),('segmentation-roi','Segmentation: product-focused'),('matting-vitmatte','Current + ViTMatte'),('segmentation-vitmatte','Segmentation + ViTMatte'),('segmentation-roi-vitmatte','Focused segmentation + ViTMatte'),('segmentation-roi-vitmatte-detail','ViTMatte: higher-detail region')]
for name,box in [('boot',(395,1780,1780,2025)),('shirt',(830,435,1280,1080)),('boot-laces',(1010,1170,1280,1460))]:
 sample=name.split('-')[0];cw,ch=(700,180) if name=='boot' else (360,430)
 sheet=Image.new('RGB',(cw*2,(ch+46)*4),'#292929');d=ImageDraw.Draw(sheet)
 for i,(variant,label) in enumerate(variants):
  path=ROOT/f'{sample}-{variant}.png'
  if not path.exists():continue
  im=Image.open(path).convert('RGBA');bg=Image.new('RGBA',im.size,'#ececec' if sample=='boot' else '#555565');im=Image.alpha_composite(bg,im).crop(box);im.thumbnail((cw-12,ch))
  x=(i%2)*cw;y=(i//2)*(ch+46)
  d.text((x+8,y+12),label,fill='white',font=font);sheet.paste(im.convert('RGB'),(x+6,y+46))
 sheet.save(ROOT/f'{name}-comparison.jpg',quality=94)
