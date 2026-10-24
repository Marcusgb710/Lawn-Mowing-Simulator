"""Character identity sheet from final front and side renders, with costume swatches."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;REPO=HERE.parents[3]
font_path=REPO/'art-source/GUI/Fonts/Source/Nunito-800.ttf'
font=ImageFont.truetype(str(font_path),23);small=ImageFont.truetype(str(font_path),17)
sheet=Image.new('RGB',(2048,2048),'#24442B');d=ImageDraw.Draw(sheet)
rows=[r for r in json.loads((OUT/'model_manifest.json').read_text())['assets'] if r['name'].startswith('NPC_')]
common=['#D4A484','#BAB7AC','#EFE5C8','#9F906C'];palettes={}
for i,r in enumerate(rows):
    n=r['name'];x=(i%3)*682;y=(i//3)*682
    d.rounded_rectangle((x+10,y+10,x+672,y+672),radius=18,fill='#315A39')
    d.text((x+341,y+25),n,font=font,fill='#FFF7E0',anchor='mt')
    for j,mode in enumerate(['Front','Side']):
        image=Image.open(HERE/'CharacterViews'/(n+'_'+mode+'.png')).convert('RGB')
        dimensions=r['dimensions_studs'];extent=dimensions[0 if mode=='Front' else 2]/max(dimensions)*631+32
        image=image.crop((max(0,round(384-extent/2)),50,min(768,round(384+extent/2)),718))
        image.thumbnail((316,524),Image.Resampling.LANCZOS);sheet.paste(image,(x+23+j*328,y+70))
        d.text((x+180+j*328,y+60),mode.upper(),font=small,fill='#CFE3C6',anchor='mt')
    colors=['#859B74','#F1E5C8','#9F906C','#B62222','#917C55','#BAB7AC'] if 'June' in n else ['#A792C1','#D4A484','#CCC09B','#F1E5C8'] if 'Gloria' in n else ['#5B3798','#DCB03D','#9F906C','#3E3128'] if 'Chad' in n or 'TurfKing' in n else ['#276D37','#235B9D','#AF7754','#3E3128'] if 'Sam' in n else ['#F1E5C8','#BE495D','#AF7754','#BAB7AC'] if 'Edna' in n else ['#9CB8C2','#414C50','#7E503C' if n.endswith('2') else '#D4A484','#917C55']
    palettes[n]=colors;w=632/len(colors)
    for j,c in enumerate(colors):
        xx=x+25+j*w;d.rounded_rectangle((xx,y+595,xx+w-8,y+622),radius=6,fill=c)
        d.text((xx+w/2-4,y+632),c,font=small,fill='#FFF7E0',anchor='mt')
sheet.save(OUT/'Previews/CharacterSheet.png')
(HERE/'character_palettes.json').write_text(json.dumps(palettes,indent=2)+'\n')
print('CharacterSheet complete: nine poses, front/side, palette hex codes.')
