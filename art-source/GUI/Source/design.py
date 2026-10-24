"""Maple Grove Summer design tokens and reproducible text-free GUI pieces."""
from pathlib import Path
import json,math
import numpy as np
from PIL import Image,ImageDraw,ImageFilter,ImageFont
HERE=Path(__file__).resolve().parent;OUT=HERE.parent
import sys
sys.dont_write_bytecode=True
P={'ink':'#17301C','panel':'#24442B','card':'#315A39','text':'#FFF7E0','subtext':'#CFE3C6','accent':'#7BC74D','accent_dark':'#4E9A2E','money':'#FFD24A','danger':'#E0553F','info':'#6FB7E8','rival':'#6B4FBF','gold':'#E8B931','grandma':'#E3C27A','hat_band':'#C8463C','disabled':'#69746A'}
P.update(primary_face='#386E28',danger_face='#A43A2E',disabled='#626D63',locked_card='#465448')
def rgb(color):return tuple(int(color.lstrip('#')[i:i+2],16) for i in [0,2,4])
def font(size,kind='body',bold=False):
    file='DenkOne-Regular.ttf' if kind=='heading' else 'LilitaOne-Regular.ttf' if kind=='display' else 'Nunito-800.ttf' if bold else 'Nunito-600.ttf'
    return ImageFont.truetype(str(OUT/'Fonts/Source'/file),round(size))
def text(im,xy,words,size=28,color=None,kind='body',anchor=None,bold=False,stroke=0):
    ImageDraw.Draw(im).text(xy,words,font=font(size,kind,bold),fill=color or P['text'],anchor=anchor,stroke_width=stroke,stroke_fill=P['ink'])
def wrap(words,size,width,kind='body'):
    f=font(size,kind);lines=[];line=''
    for w in words.split():
        candidate=(line+' '+w).strip()
        if f.getlength(candidate)>width and line:lines.append(line);line=w
        else:line=candidate
    if line:lines.append(line)
    return lines
def paragraph(im,xy,words,size,width,color=None,line_height=None):
    x,y=xy
    for line in wrap(words,size,width):text(im,(x,y),line,size,color);y+=line_height or size*1.34
    return y
def tint(image,color):
    c=Image.new('RGBA',image.size,color);c.putalpha(image.getchannel('A'));return c
SLICES={}
def piece(name,size=(256,256),fill='panel',radius=40,title=False,pressed=False,alpha=255,kind='frame',slice_rect=None):
    scale=3;w,h=size
    mask=Image.new('L',(w*scale,h*scale));d=ImageDraw.Draw(mask)
    top=12+(2 if pressed else 0);bottom=h-24+(2 if pressed else 0)
    shape=(12*scale,top*scale,(w-12)*scale,bottom*scale)
    d.rounded_rectangle(shape,radius=radius*scale,fill=255)
    shadow=Image.new('RGBA',mask.size,(8,22,12,0));shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(4*scale)).point(lambda a:int(a*.45)))
    im=Image.new('RGBA',mask.size);im.alpha_composite(shadow,(0,7*scale))
    d=ImageDraw.Draw(im)
    if kind=='button':
        d.rounded_rectangle((12*scale,(top+7)*scale,(w-12)*scale,(bottom+7)*scale),radius=radius*scale,fill=P['ink'])
    if name in ['Button_Primary','Button_Primary_Pressed','Tab_Active','Bubble_Mine']:fill='primary_face'
    if name in ['Button_Danger','Button_Danger_Pressed','Prompt_Blocked']:fill='danger_face'
    if name=='Card_Locked':fill='locked_card'
    col=P.get(fill,fill);base=rgb(col)
    if pressed:base=tuple(int(v*.87) for v in base)
    face=Image.new('RGBA',mask.size,(*base,alpha));face.putalpha(mask.point(lambda v:int(v*alpha/255)))
    im.alpha_composite(face)
    if title:
        band=Image.new('RGBA',mask.size)
        ImageDraw.Draw(band).rectangle((0,0,w*scale,160*scale),fill=tuple(int(v*.77) for v in base)+(255,))
        band.putalpha(Image.fromarray((np.array(band.getchannel('A'),dtype=np.uint16)*np.array(mask,dtype=np.uint16)//255).astype('uint8')))
        im.alpha_composite(band)
    # Grain is alpha-only and subtle; never competes with live text.
    rng=np.random.default_rng(38+w+h);grain=Image.new('RGBA',mask.size,(255,247,224,0))
    noise=rng.integers(0,4,(h*scale,w*scale),dtype=np.uint8)
    grain.putalpha(Image.fromarray((noise.astype(np.uint16)*np.array(mask,dtype=np.uint16)//255).astype('uint8')))
    im.alpha_composite(grain);d=ImageDraw.Draw(im)
    d.rounded_rectangle(shape,radius=radius*scale,outline=P['ink'],width=7*scale)
    highlight=tuple(min(255,v+35) for v in base)+(100,);rr=max(8,radius-8)
    d.line(((20+rr)*scale,(top+8)*scale,(w-20-rr)*scale,(top+8)*scale),fill=highlight,width=2*scale)
    d.arc((20*scale,(top+8)*scale,(20+rr*2)*scale,(top+8+rr*2)*scale),180,270,fill=highlight,width=2*scale)
    d.arc(((w-20-rr*2)*scale,(top+8)*scale,(w-20)*scale,(top+8+rr*2)*scale),270,360,fill=highlight,width=2*scale)
    if name=='MenuButton':d.rounded_rectangle((24*scale,30*scale,89*scale,(h-42)*scale),radius=16*scale,fill=P['ink'])
    if name in ['Card_Selected','ThreadCard_Active']:d.rounded_rectangle(shape,radius=radius*scale,outline=P['accent'],width=7*scale)
    if name=='StickyNote':
        d.polygon([(w*scale-54*scale,12*scale),(w*scale-12*scale,55*scale),(w*scale-54*scale,55*scale)],fill=P['grandma'])
        d.line([(w*scale-54*scale,12*scale),(w*scale-54*scale,55*scale),(w*scale-12*scale,55*scale)],fill=P['ink'],width=4*scale)
    im=im.resize(size,Image.Resampling.LANCZOS);im.save(OUT/'Kit'/(name+'.png'))
    if slice_rect is None:
        inset=min(64,w//3,h//3);slice_rect=[inset,176 if title else inset,w-inset,h-inset]
        if slice_rect[1]>=slice_rect[3]:slice_rect[1]=h//3
    SLICES[name]=dict(file='Kit/'+name+'.png',size_px=list(size),slice_center_px=slice_rect,content_inset_px=[26,92 if title else 24,26,32],draw_scale=2)

def tile(name,colors,size=(256,48)):
    w,h=size;x=np.arange(w)[None,:];y=np.arange(h)[:,None]
    a=np.array(rgb(colors[0]));b=np.array(rgb(colors[1]));c=np.where(((x//32)%2)[:,:,None]==0,a,b)
    c=np.broadcast_to(c,(h,w,3)).copy().astype(float)
    c*= (1+.08*np.cos(y*math.pi/h))[:,:,None]
    arr=np.zeros((h,w,4),dtype=np.uint8);arr[:,:,:3]=np.clip(c,0,255);arr[:,:,3]=255
    arr[:3,:,:3]=rgb(P['ink']);arr[-3:,:,:3]=rgb(P['ink']);arr[:,-1]=arr[:,0]
    Image.fromarray(arr).save(OUT/'Kit'/(name+'.png'))
    SLICES[name]=dict(file='Kit/'+name+'.png',size_px=list(size),slice_center_px=[2,8,w-2,h-8],tile_mode='horizontal',tile_display_size_px=[64,12],draw_scale=2)

def circle_piece(name,size,fill,ring=False):
    s=3;im=Image.new('RGBA',(size*s,size*s));d=ImageDraw.Draw(im)
    if ring:
        d.ellipse((12*s,12*s,(size-12)*s,(size-12)*s),outline=P[fill],width=12*s)
    else:
        unit=size/256
        d.ellipse((14*unit*s,20*unit*s,(size-14*unit)*s,(size-8*unit)*s),fill=P['ink'])
        d.ellipse((14*unit*s,10*unit*s,(size-14*unit)*s,(size-18*unit)*s),fill=P[fill],outline=P['ink'],width=max(1,round(7*unit*s)))
        d.arc((23*unit*s,18*unit*s,(size-23*unit)*s,(size-28*unit)*s),190,340,fill=P['text'],width=max(1,round(3*unit*s)))
    im.resize((size,size),Image.Resampling.LANCZOS).save(OUT/'Kit'/(name+'.png'))
    SLICES[name]=dict(file='Kit/'+name+'.png',size_px=[size,size],slice_center_px=None,scaling='uniform',draw_scale=2)

def build_kit():
    for name in ['Panel','DialogueBox']:piece(name,(512,320),title=name=='Panel',radius=48)
    for name in ['Card','Card_Selected','Card_Locked','ThreadCard','ThreadCard_Active','GoalCard','GoalTracker']:
        piece(name,(384,224),fill='card' if 'Locked' not in name else 'disabled')
    for name,fill in [('Primary','accent_dark'),('Money','money'),('Danger','danger'),('Neutral','card'),('Disabled','disabled'),('Robux','gold')]:
        for pressed in [False,True]:piece('Button_'+name+('_Pressed' if pressed else ''),(384,144),fill,32,pressed=pressed,kind='button',slice_rect=[56,48,328,88])
    for name,fill in [('Tab','card'),('Tab_Active','accent_dark')]:piece(name,(256,128),fill,28)
    piece('ProgressTrack',(256,64),'ink',24,slice_rect=[32,24,224,40])
    for name,cols in [('ProgressFill',[P['accent'],P['accent_dark']]),('ProgressFill_Money',[P['money'],P['gold']]),('ProgressFill_TurfKing',[P['rival'],'#8066CB']),('ScoreFill_You',[P['accent'],P['accent_dark']]),('ScoreFill_Rival',[P['rival'],'#8066CB'])]:tile(name,cols)
    for name,size,fill in [('PriceTag',(288,160),'money'),('Toast',(512,160),'panel'),('Tooltip',(320,160),'panel'),('Prompt',(512,144),'panel'),('Prompt_Blocked',(512,144),'danger'),('HudPanel',(512,240),'panel'),('MenuButton',(384,144),'panel'),('KeyBadge',(128,128),'ink'),('NameTag',(320,128),'grandma'),('Bubble',(384,192),'text'),('StickyNote',(384,256),'grandma'),('Bubble_Theirs',(384,192),'card'),('Bubble_Mine',(384,192),'accent_dark'),('ScoreTrack',(384,96),'ink'),('Ribbon',(512,192),'rival')]:
        piece(name,size,fill,32,alpha=225 if name=='HudPanel' else 255,slice_rect=[112,48,320,88] if name=='MenuButton' else None)
    # The plant-tag is clipped at one end and has a real cord hole.
    p=OUT/'Kit/PriceTag.png';im=Image.open(p);d=ImageDraw.Draw(im)
    d.polygon([(12,12),(62,12),(12,62)],fill=(0,0,0,0));d.line([(12,62),(62,12)],fill=P['ink'],width=7)
    d.ellipse((44,35,62,53),fill=P['ink']);im.save(p)
    for name,size,fill,ring in [('TouchButton',256,'accent_dark',False),('TouchButton_Small',192,'card',False),('HoldRing',256,'ink',True),('HoldRing_Fill',256,'accent',True),('PortraitRing',256,'grandma',True),('Badge_Unread',64,'danger_face',False)]:circle_piece(name,size,fill,ring)
    for name,fill in [('Reticle','text'),('Reticle_Active','accent'),('Reticle_Blocked','danger')]:
        im=Image.new('RGBA',(192,192));d=ImageDraw.Draw(im);d.ellipse((66,66,126,126),fill=P[fill],outline=P['ink'],width=12)
        if name=='Reticle_Active':d.ellipse((36,36,156,156),outline=P[fill],width=6)
        if name=='Reticle_Blocked':d.line((48,144,144,48),fill=P[fill],width=9)
        im.resize((64,64),Image.Resampling.LANCZOS).save(OUT/'Kit'/(name+'.png'))
        SLICES[name]=dict(file='Kit/'+name+'.png',size_px=[64,64],slice_center_px=None,scaling='uniform')
    im=Image.new('RGBA',(192,96));d=ImageDraw.Draw(im);d.polygon([(12,0),(168,0),(48,80)],fill=P['text'],outline=P['ink'],width=6);im.save(OUT/'Kit/BubbleTail.png')
    SLICES['BubbleTail']=dict(file='Kit/BubbleTail.png',size_px=[192,96],slice_center_px=None,scaling='uniform')
    arr=np.zeros((64,1,4),dtype=np.uint8);arr[:,:,:3]=0;arr[:,:,3]=(255*np.clip(np.arange(64)[::-1]/16,0,1))[:,None].astype(np.uint8)
    Image.fromarray(arr).save(OUT/'Kit/Letterbox.png');SLICES['Letterbox']=dict(file='Kit/Letterbox.png',size_px=[1,64],slice_center_px=None,scaling='stretch_x',soft_inner_edge='bottom; mirror vertically for lower bar')
    (HERE/'palette.json').write_text(json.dumps(P,indent=2)+'\n');(HERE/'slices.json').write_text(json.dumps(SLICES,indent=2)+'\n')
    # The computer taskbar shares the panel geometry, with its own exact slice record.
    piece('Taskbar',(512,128),'ink',32)
    im=Image.open(OUT/'Kit/Taskbar.png');im.save(OUT/'Computer/Taskbar.png');(OUT/'Kit/Taskbar.png').unlink()
    row=SLICES.pop('Taskbar');row['file']='Computer/Taskbar.png';SLICES['Computer/Taskbar']=row
    (HERE/'slices.json').write_text(json.dumps(SLICES,indent=2)+'\n')
    print('Kit:',len(SLICES),'pieces')

if __name__=='__main__':build_kit()
