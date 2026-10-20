"""Make the Fredoka logo, periodic stripe tile, exact background tiles and UI mock-ups.

Run with Python 3, Pillow, NumPy and fontTools after the two Blender renders.
--draft uses Background_Draft.png for composition review; final uses the master.
All generated files stay inside art-source/TitleCard/.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

HERE=Path(__file__).resolve().parent
OUT=HERE.parent
PREVIEW=OUT/'Previews';PREVIEW.mkdir(exist_ok=True)
FONT=HERE/'Fonts/Fredoka-SemiBold.ttf'
WORDS=[('LAWN MOWING',130,180,14),('SIMULATOR',112,322,12)]
GREEN='#173c28';CREAM='#fff7dc'

def logo():
    # Work at 3x for smooth small-size edges and real transparent padding.
    scale=3
    fg=Image.new('RGBA',(1024*scale,512*scale))
    d=ImageDraw.Draw(fg)
    for text,size,baseline,stroke in WORDS:
        font=ImageFont.truetype(str(FONT),size*scale)
        d.text((512*scale,baseline*scale),text,font=font,anchor='ms',
               fill=CREAM,stroke_width=stroke*scale,stroke_fill=GREEN)
    # A small, simple mown-lawn mark. Its blade silhouettes remain clear at 300 px.
    def poly(points,color):d.polygon([(int(x*scale),int(y*scale)) for x,y in points],fill=color)
    d.rounded_rectangle((352*scale,408*scale,672*scale,452*scale),radius=19*scale,fill=GREEN)
    for i in range(8):
        d.rectangle(((362+i*38)*scale,418*scale,(398+i*38)*scale,442*scale),
                    fill='#92bc52' if i%2==0 else '#5a913e')
    for x,h,lean in [(456,34,-16),(484,47,-9),(512,59,0),(540,47,9),(568,34,16)]:
        poly([(x-6,410),(x-10,410-h*.6),(x+lean,410-h),(x+7,410)],GREEN)
        poly([(x-2,407),(x-4,410-h*.56),(x+lean,414-h),(x+2,407)],'#87b64a')
    alpha=fg.getchannel('A')
    shadow=Image.new('RGBA',fg.size,(0,0,0,0))
    s=Image.new('RGBA',fg.size,(6,28,17,0));s.putalpha(alpha.point(lambda a:int(a*.36)).filter(ImageFilter.GaussianBlur(5*scale)))
    shadow.alpha_composite(s,(2*scale,8*scale))
    shadow.alpha_composite(fg)
    final=shadow.resize((1024,512),Image.Resampling.LANCZOS)
    final.save(OUT/'Logo.png')
    final.resize((300,150),Image.Resampling.LANCZOS).save(PREVIEW/'Logo_300px.png')
    # Portable outlined SVG: glyph paths, no system font dependency.
    tt=TTFont(FONT);glyphs=tt.getGlyphSet();cmap=tt.getBestCmap();upem=tt['head'].unitsPerEm
    svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512" viewBox="0 0 1024 512">',
         '<title>Lawn Mowing Simulator</title>',
         '<desc>Fredoka, weight 650. Lettering is editable vector outlines. Small mown-lawn mark.</desc>',
         '<defs><filter id="shadow" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="2" dy="8" stdDeviation="5" flood-color="#061c11" flood-opacity=".36"/></filter></defs>',
         '<g filter="url(#shadow)">']
    for text,size,baseline,stroke in WORDS:
        ratio=size/upem;advance=sum(tt['hmtx'][cmap[ord(c)]][0] for c in text)*ratio
        x=(1024-advance)/2
        commands=[]
        for char in text:
            glyph=glyphs[cmap[ord(char)]];pen=SVGPathPen(glyphs)
            glyph.draw(TransformPen(pen,(ratio,0,0,-ratio,x,baseline)))
            commands.append(pen.getCommands());x+=tt['hmtx'][cmap[ord(char)]][0]*ratio
        svg.append('<path d="'+' '.join(commands)+'" fill="'+CREAM+'" stroke="'+GREEN+'" stroke-width="'+str(stroke*2)+'" stroke-linejoin="round" paint-order="stroke fill"/>')
    svg.append('<rect x="352" y="408" width="320" height="44" rx="19" fill="'+GREEN+'"/>')
    for i in range(8):svg.append('<rect x="'+str(362+i*38)+'" y="418" width="36" height="24" fill="'+('#92bc52' if i%2==0 else '#5a913e')+'"/>')
    for x,h,lean in [(456,34,-16),(484,47,-9),(512,59,0),(540,47,9),(568,34,16)]:
        points=[(x-6,410),(x-10,410-h*.6),(x+lean,410-h),(x+7,410)]
        svg.append('<polygon points="'+' '.join(str(a)+','+str(b) for a,b in points)+'" fill="'+GREEN+'"/>')
        points=[(x-2,407),(x-4,410-h*.56),(x+lean,414-h),(x+2,407)]
        svg.append('<polygon points="'+' '.join(str(a)+','+str(b) for a,b in points)+'" fill="#87b64a"/>')
    svg.extend(['</g>','</svg>'])
    (HERE/'Logo.svg').write_text('\n'.join(svg)+'\n')
    (HERE/'logo_layout.json').write_text(json.dumps(dict(text='Lawn Mowing Simulator',font_family='Fredoka',weight=650,width_axis=100,canvas=[1024,512],lines=[dict(text=t,font_size=s,baseline_y=y,outline_px=w) for t,s,y,w in WORDS],mark='mown stripes with five grass blades'),indent=2)+'\n')
    return final

def stripes():
    # Torus-domain noise is exactly periodic. Duplicate the endpoint column so
    # the last and first texel match as well as the underlying periodic field.
    x=np.arange(256)/255*2*np.pi;y=np.arange(64)/63*2*np.pi
    xx,yy=np.meshgrid(x,y)
    n=(np.sin(17*xx+7*yy)+np.sin(37*xx-11*yy)*.6+np.cos(51*xx+23*yy)*.3)*1.15
    a=np.array([103,158,66.]);b=np.array([79,132,50.])
    base=np.where((np.arange(256)<128)[None,:,None],a,b)
    arr=np.clip(base+n[:,:,None],0,255).astype(np.uint8)
    # A narrow transition across each boundary avoids a discontinuous seam.
    for k in range(3):
        t=(k+1)/4
        mix=(a+b)/2
        arr[:,k]=np.clip(mix*(1-t)+a*t+n[:,k,None],0,255)
        arr[:,-1-k]=np.clip(mix*(1-t)+b*t+n[:,-1-k,None],0,255)
    arr[:,-1]=arr[:,0];arr[-1]=arr[0]
    im=Image.fromarray(arr,'RGB');im.save(OUT/'Stripes.png');return im

def crop_fill(image,size):
    w,h=size;factor=max(w/image.width,h/image.height)
    nw,nh=round(image.width*factor),round(image.height*factor)
    img=image.resize((nw,nh),Image.Resampling.LANCZOS)
    return img.crop(((nw-w)//2,(nh-h)//2,(nw-w)//2+w,(nh-h)//2+h)).convert('RGBA')

def mockup(background,wordmark,stripe,size,path):
    w,h=size;im=crop_fill(background,size)
    # Match src/first/init.client.luau, including MaxSize constraints.
    area_w=min(.62*w,900);area_h=min(.36*h,450)
    factor=min(area_w/1024,area_h/512)
    lg=wordmark.resize((round(1024*factor),round(512*factor)),Image.Resampling.LANCZOS)
    lx=round((w-lg.width)/2);ly=round(.1*h+(area_h-lg.height)/2)
    im.alpha_composite(lg,(lx,ly))
    bw=round(max(260,min(.5*w,640)));bx=(w-bw)//2;by=round(.9*h-70)
    draw=ImageDraw.Draw(im)
    font=ImageFont.truetype(str(FONT),22)
    draw.text((w/2,by+14),'Loading the neighborhood...',anchor='mm',font=font,
              fill='white',stroke_width=2,stroke_fill='#23461e')
    track=(bx,by+40,bx+bw,by+58)
    overlay=Image.new('RGBA',size)
    ImageDraw.Draw(overlay).rounded_rectangle(track,radius=9,fill=(30,40,30,192))
    im.alpha_composite(overlay)
    fill_w=round(bw*.68)
    tiled=Image.new('RGBA',(fill_w,18));tile=stripe.resize((64,16),Image.Resampling.LANCZOS).convert('RGBA')
    for x in range(0,fill_w,64):
        for y in range(0,18,16):tiled.alpha_composite(tile,(x,y))
    mask=Image.new('L',(fill_w,18));ImageDraw.Draw(mask).rounded_rectangle((0,0,fill_w-1,17),radius=9,fill=255)
    im.paste(tiled,(bx,by+40),mask)
    if (OUT/'Mower.png').exists():
        mower=Image.open(OUT/'Mower.png').convert('RGBA').resize((34,34),Image.Resampling.LANCZOS)
        im.alpha_composite(mower,(bx+fill_w-17,by+6))
    im.convert('RGB').save(path)
    return dict(screen_size_px=[w,h],logo_canvas_rect_px=[lx,ly,lx+lg.width,ly+lg.height],loading_track_rect_px=list(track),progress=.68)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--draft',action='store_true');args=parser.parse_args()
    lg=logo();stripe=stripes()
    master=Image.open(OUT/('Source/Background_Draft.png' if args.draft else 'Background_Master.png')).convert('RGB')
    if not args.draft:
        assert master.size==(2048,1152)
        for name,rect in [('TL',(0,0,1024,576)),('TR',(1024,0,2048,576)),('BL',(0,576,1024,1152)),('BR',(1024,576,2048,1152))]:master.crop(rect).save(OUT/('Background_'+name+'.png'))
    layouts={}
    for suffix,size in [('16x9',(1920,1080)),('Phone',(2340,1080)),('Tablet',(2048,1536))]:
        path=PREVIEW/('TitleCard_'+suffix+'.png')
        layouts[path.name]=mockup(master,lg,stripe,size,path)
    (HERE/'mockup_layouts.json').write_text(json.dumps(layouts,indent=2)+'\n')
    if not args.draft:
        # Useful visual audit of the actual common crop, not an upload asset.
        safe=master.copy();d=ImageDraw.Draw(safe)
        d.rectangle((256,104,1791,1047),outline='#ffffb0',width=4)
        safe.save(PREVIEW/'Background_SafeZone.png')
    print('Built logo, stripe tile, '+('draft mock-ups' if args.draft else 'four exact tiles and final mock-ups'))

if __name__=='__main__':main()
