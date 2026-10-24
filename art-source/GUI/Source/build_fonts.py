"""OFL Lilita One: paired AngelCode JSON bitmap fonts and finished wordmarks."""
from design import *
import string
def make_atlas(name,chars,cap):
    path=OUT/'Fonts/Source/LilitaOne-Regular.ttf'
    probe=ImageFont.truetype(str(path),100);height=-probe.getbbox('H',anchor='ls')[1]
    size=round(100*cap/height);f=ImageFont.truetype(str(path),size)
    pad=14;atlas=Image.new('RGBA',(1024,1024));outline=Image.new('RGBA',(1024,1024));x=y=4;row_h=0;metrics=[]
    base=cap+pad;line_height=round(size*1.25)+pad*2;digit_width=math.ceil(max(f.getlength(c) for c in string.digits))
    for ch in chars:
        box=f.getbbox(ch,anchor='ls');w=box[2]-box[0]+pad*2;h=box[3]-box[1]+pad*2
        if x+w>1020:x=4;y+=row_h+4;row_h=0
        assert y+h<=1024,(name,ch,y+h)
        mask=Image.new('L',(w,h));d=ImageDraw.Draw(mask);pos=(pad-box[0],pad-box[1]);d.text(pos,ch,font=f,anchor='ls',fill=255)
        face=Image.new('RGBA',(w,h),'white');face.putalpha(mask)
        stroke=Image.new('L',(w,h));d=ImageDraw.Draw(stroke);d.text(pos,ch,font=f,anchor='ls',fill=255,stroke_width=5,stroke_fill=255)
        sh=Image.new('L',(w,h));sh.paste(stroke.filter(ImageFilter.GaussianBlur(2)),(0,4))
        combined=Image.fromarray(np.maximum(np.array(stroke),np.array(sh)))
        border=Image.new('RGBA',(w,h),P['ink']);border.putalpha(combined)
        atlas.alpha_composite(face,(x,y));outline.alpha_composite(border,(x,y))
        advance=digit_width if name=='Display_Numbers' and ch in string.digits else round(f.getlength(ch))
        metrics.append(dict(id=ord(ch),char=ch,x=x,y=y,width=w,height=h,xoffset=box[0]-pad,yoffset=base+box[1]-pad,xadvance=advance,page=0,chnl=15))
        x+=w+4;row_h=max(row_h,h)
    # Space is a real blank glyph so the ordinary AngelCode renderer can lay out sentences.
    metrics.append(dict(id=32,char=' ',x=0,y=0,width=1,height=1,xoffset=0,yoffset=0,xadvance=round(f.getlength(' ')),page=0,chnl=15))
    kern=[]
    for first in chars:
        for second in chars:
            amount=round(f.getlength(first+second)-f.getlength(first)-f.getlength(second))
            if amount and not (name=='Display_Numbers' and first.isdigit() and second.isdigit()):kern.append(dict(first=ord(first),second=ord(second),amount=amount))
    for suffix,image in [('Face',atlas),('Outline',outline)]:
        image.save(OUT/'Fonts'/(name+'_'+suffix+'.png'))
        doc=dict(pages=[name+'_'+suffix+'.png'],info=dict(face='Lilita One',size=size,bold=0,italic=0,charset='',unicode=1,stretchH=100,smooth=1,aa=1,padding=[pad]*4,spacing=[4,4],outline=0 if suffix=='Face' else 5),common=dict(lineHeight=line_height,base=base,scaleW=1024,scaleH=1024,pages=1,packed=0),chars=metrics,kernings=kern)
        (OUT/'Fonts'/(name+('' if suffix=='Face' else '_Outline')+'.fnt')).write_text(json.dumps(doc,indent=2)+'\n')
    return dict(name=name,cap_height_px=cap,font_size_px=size,line_height_px=line_height,base_px=base,face_atlas='Fonts/'+name+'_Face.png',outline_atlas='Fonts/'+name+'_Outline.png',metrics='Fonts/'+name+'.fnt',outline_metrics='Fonts/'+name+'_Outline.fnt',tabular_digit_advance_px=digit_width if name=='Display_Numbers' else None)

def bitmap_text(words,name,scale=1,color=None):
    doc=json.loads((OUT/'Fonts'/(name+'.fnt')).read_text());table={g['id']:g for g in doc['chars']};kern={(k['first'],k['second']):k['amount'] for k in doc['kernings']}
    advance=0;prev=None
    for c in words:
        if prev is not None:advance+=kern.get((prev,ord(c)),0)
        advance+=table[ord(c)]['xadvance'];prev=ord(c)
    canvas=Image.new('RGBA',(advance+60,doc['common']['lineHeight']+40));face=Image.open(OUT/'Fonts'/(name+'_Face.png'));border=Image.open(OUT/'Fonts'/(name+'_Outline.png'));pen=25;prev=None
    for c in words:
        g=table[ord(c)];pen+=kern.get((prev,ord(c)),0) if prev is not None else 0
        rect=(g['x'],g['y'],g['x']+g['width'],g['y']+g['height']);pos=(pen+g['xoffset'],10+g['yoffset'])
        canvas.alpha_composite(border.crop(rect),pos)
        ink=face.crop(rect);ink=tint(ink,color or P['text']);canvas.alpha_composite(ink,pos)
        pen+=g['xadvance'];prev=ord(c)
    return canvas.resize((round(canvas.width*scale),round(canvas.height*scale)),Image.Resampling.LANCZOS)

def wordmarks():
    labels={'JobComplete':'Job Complete!','Payday':'Payday!','NewTool':'New Tool!','LevelUp':'Level Up!','Winner':'Winner!','SoClose':'So Close!','BestYard':'Maple Grove Best Yard','Act1':'Act 1: The Shears','Act2':'Act 2: TurfKing','Act3':'Act 3: The Crew','Act4':'Act 4: The Contest','Stamp_TakenByTurfKing':'Taken by TurfKing','Stamp_Sold':'Sold','Stamp_Bought':'Bought'}
    for name,words in labels.items():
        if name.startswith('Stamp'):
            f=font(72,'display');length=math.ceil(f.getlength(words))+70
            im=Image.new('RGBA',(min(1024,length),160));d=ImageDraw.Draw(im);col=P['gold'] if name=='Stamp_TakenByTurfKing' else P['text']
            d.rounded_rectangle((12,12,im.width-12,145),radius=14,outline=P['rival'] if name=='Stamp_TakenByTurfKing' else P['ink'],width=14)
            factor=min(1,(im.width-60)/f.getlength(words));f=font(72*factor,'display')
            d.text((im.width/2,78),words,font=f,fill=col,anchor='mm',stroke_width=3,stroke_fill=P['ink'])
            im=im.rotate(4,resample=Image.Resampling.BICUBIC,expand=True)
        else:
            im=bitmap_text(words,'Display_Headline',1.35,P['money'] if name in ['Payday','Winner','BestYard'] else P['text'])
            if name in ['Winner','LevelUp','JobComplete','BestYard']:
                d=ImageDraw.Draw(im);cx=im.width-27;cy=im.height//2
                d.polygon([(cx,cy-18),(cx+5,cy-5),(cx+18,cy),(cx+5,cy+5),(cx,cy+18),(cx-5,cy+5),(cx-18,cy),(cx-5,cy-5)],fill=P['money'],outline=P['ink'])
        box=im.getbbox();im=im.crop((max(0,box[0]-12),max(0,box[1]-12),min(im.width,box[2]+12),min(im.height,box[3]+12)))
        if im.width>1024:im=im.resize((1024,round(im.height*1024/im.width)),Image.Resampling.LANCZOS)
        im.save(OUT/'Wordmarks'/(name+'.png'))
    (HERE/'wordmarks.json').write_text(json.dumps(labels,indent=2)+'\n')
def main():
    numbers=list(dict.fromkeys('0123456789$,.+−%/:×R'))
    headline=list(dict.fromkeys(string.ascii_uppercase+string.ascii_lowercase+string.digits+".,!?'’\"-–:;&()#/$%"))
    fonts=[make_atlas('Display_Numbers',numbers,128),make_atlas('Display_Headline',headline,72)]
    (HERE/'font_spec.json').write_text(json.dumps(dict(live_heading=dict(roblox_family='DenkOne',weight='Regular',source='Fonts/Source/DenkOne-Regular.ttf',reason='Compact chunky headings pair with the cream outlined title and leave space on landscape phones.'),live_body=dict(roblox_family='Nunito',weights=['Regular','SemiBold','Bold','ExtraBold'],reason='Rounded, open counters and a broad weight range keep dense item descriptions and dialogue readable.'),display=dict(family='Lilita One',license='SIL OFL 1.1',source='Fonts/Source/LilitaOne-Regular.ttf'),bitmap_fonts=fonts),indent=2)+'\n')
    wordmarks()
    im=Image.new('RGB',(2048,1024),P['panel']);text(im,(75,55),'MAPLE GROVE SUMMER • TYPE',49,kind='heading')
    for words,name,y in [('$12,450','Display_Numbers',210),('Act 2: TurfKing','Display_Headline',470),('Best Yard','Display_Headline',730)]:
        line=bitmap_text(words,name,1.4);line=line.crop(line.getbbox());line.thumbnail((880,190),Image.Resampling.LANCZOS)
        im.paste(line,(90,y),line)
    text(im,(1050,230),'LIVE HEADINGS',38,kind='heading');text(im,(1050,300),'DenkOne • Regular',30)
    paragraph(im,(1050,425),'Nunito keeps item descriptions, dialogue and message threads clear. Regular / SemiBold / Bold / ExtraBold',30,800)
    text(im,(1050,690),'Face + outline + shadow',36,kind='heading');paragraph(im,(1050,755),'Two aligned layers. White glyph faces can be tinted. Deep-green outlines use the same glyph rectangles and advances.',28,800)
    im.save(OUT/'Fonts/Specimen.png');print('Bitmap fonts, 14 wordmarks and specimen complete')
if __name__=='__main__':main()
