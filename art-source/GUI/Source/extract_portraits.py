"""Extract exact square portraits from the painted source sheets."""
from pathlib import Path
import json
from PIL import Image
HERE=Path(__file__).resolve().parent;OUT=HERE.parent
sources=[('June.png',3,2,['June_Neutral','June_Smug','June_Annoyed','June_Proud','June_Laughing',None]),('GloriaChad.png',3,2,['Gloria_Smug','Gloria_FakeSmile','Gloria_Furious',None,None,None]),('Corrections.png',2,2,['Gloria_Defeated','Chad_Cocky','Chad_Panicked',None]),('SamBridge.png',3,2,['Sam_FedUp','Sam_Happy','Edna_Happy','Rossi_Gossip','Nguyen_Picky','BridgeClub']),('Judges.png',2,2,['Judge1','Judge2',None,None])]
records=[]
for source,cols,rows,names in sources:
    im=Image.open(HERE/'PortraitSheets'/source).convert('RGB')
    for i,name in enumerate(names):
        if not name:continue
        rect=(round(i%cols*im.width/cols),round(i//cols*im.height/rows),round((i%cols+1)*im.width/cols),round((i//cols+1)*im.height/rows))
        pic=im.crop(rect).resize((512,512),Image.Resampling.LANCZOS)
        correction=HERE/'PortraitEdits'/(name+'.png')
        if correction.exists():pic=Image.open(correction).convert('RGB').resize((512,512),Image.Resampling.LANCZOS)
        pic.save(OUT/'Portraits'/(name+'.png'))
        records.append(dict(id=name,source_sheet='Source/PortraitSheets/'+source,source_crop_px=rect,size_px=[512,512],correction_source='Source/PortraitEdits/'+name+'.png' if correction.exists() else None))
assert len(records)==19
(HERE/'portraits.json').write_text(json.dumps(records,indent=2)+'\n')
print('Extracted 19 painted portraits. Apply reviewed single-portrait corrections after extraction.')
