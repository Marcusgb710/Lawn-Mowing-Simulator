"""Moments, pass/product icons, game icon and model-based store thumbnails."""
from design import *
from build_fonts import bitmap_text
from build_screens import load,cover,fit,paste,piece
REPO=OUT.parents[1]
def rays(size=1024,transparent=False):
    y,x=np.mgrid[:size,:size];xx=(x-size/2)/(size/2);yy=(y-size/2)/(size/2);r=np.sqrt(xx*xx+yy*yy)
    angle=np.arctan2(yy,xx);beam=(np.cos(angle*18)>.7).astype(float)*.12
    light=np.clip(1-r*.65,0,1);base=np.array(rgb(P['panel']))
    arr=np.clip(base[None,None,:]+(light+beam)[:,:,None]*np.array([65,80,28]),0,255).astype('uint8')
    image=Image.fromarray(arr).convert('RGBA')
    if transparent:image.putalpha(Image.fromarray((np.clip(1-r,0,1)**1.5*(125+beam*650)).clip(0,255).astype('uint8')))
    return image
def sprite_sheets():
    confetti=Image.new('RGBA',(1024,1024));rng=np.random.default_rng(38)
    particles=[(float(rng.uniform(0,256)),float(rng.uniform(0,256)),int(rng.integers(0,6)),float(rng.uniform(0,math.tau))) for _ in range(34)]
    colors=[P[k] for k in ['money','accent','danger','info','rival','grandma']]
    for frame in range(16):
        tile=Image.new('RGBA',(768,768));d=ImageDraw.Draw(tile)
        for x,y,c,t in particles:
            px=(x+math.sin(frame*math.tau/16+t)*10)%256;py=(y+frame*16)%256;angle=t+frame*math.tau/8;w=3+abs(math.sin(angle))*6;h=3+abs(math.cos(angle))*9
            d.rounded_rectangle(((px-w)*3,(py-h)*3,(px+w)*3,(py+h)*3),radius=3,fill=colors[c])
        for i in range(7):
            x=(i*37+math.sin(frame*math.tau/16)*4)%256;y=(i*41+frame*16)%256
            d.polygon([(x*3,y*3),((x+4)*3,(y-12)*3),((x+6)*3,(y+4)*3)],fill=P['accent_dark'])
        confetti.alpha_composite(tile.resize((256,256),Image.Resampling.LANCZOS),((frame%4)*256,(frame//4)*256))
    confetti.save(OUT/'Moments/Confetti.png')
    spark=Image.new('RGBA',(256,256))
    for frame,factor in enumerate([.35,.72,1,.52]):
        tile=Image.new('RGBA',(384,384));d=ImageDraw.Draw(tile);c=192;r=140*factor
        pts=[(c,c-r),(c+r*.20,c-r*.20),(c+r,c),(c+r*.20,c+r*.20),(c,c+r),(c-r*.20,c+r*.20),(c-r,c),(c-r*.20,c-r*.20)]
        d.polygon(pts,fill=P['text']);tile.alpha_composite(Image.new('RGBA',tile.size))
        glow=tile.filter(ImageFilter.GaussianBlur(10));glow.alpha_composite(tile);spark.alpha_composite(glow.resize((128,128),Image.Resampling.LANCZOS),((frame%2)*128,(frame//2)*128))
    spark.save(OUT/'Moments/Sparkle.png')
    (HERE/'sprite_sheets.json').write_text(json.dumps({'Confetti':dict(file='Moments/Confetti.png',columns=4,rows=4,frames=16,frame_size_px=[256,256],fps=16,loop=True),'Sparkle':dict(file='Moments/Sparkle.png',columns=2,rows=2,frames=4,frame_size_px=[128,128],fps=12,loop=False)},indent=2)+'\n')
def store_icons():
    mapping={'Pass_DiamondBlades':'SpareMowerBlade','Pass_RunFlatTires':'SpareTire','Pass_EndlessSpool':'TrimmerLine','Pass_BigTank':'GasCan'}
    variants=[r['id'] for r in json.loads((HERE/'items.json').read_text()) if r['finish'] is not None]
    for name,item in list(mapping.items())+[(n,n) for n in variants]:
        im=rays(512);d=ImageDraw.Draw(im)
        d.ellipse((18,18,494,494),outline=P['gold'],width=12);d.ellipse((34,34,478,478),outline=P['ink'],width=7)
        paste(im,load('Items/'+item+'.png'),(82,82,348,348))
        if name=='Pass_DiamondBlades':
            glyph=tint(load('Icons/Premium.png'),P['info']);paste(im,glyph,(305,88,96,96))
        if name=='Pass_EndlessSpool':
            d=ImageDraw.Draw(im)
            for x in [190,252]:d.ellipse((x,245,x+82,295),outline=P['text'],width=12)
        im.convert('RGB').save(OUT/'Store'/(name+'.png'))
    icon=rays(512);d=ImageDraw.Draw(icon)
    for i in range(8):d.polygon([(i*80-100,512),((i+1)*80-100,512),((i+1)*50+100,220),(i*50+100,220)],fill=P['accent'] if i%2 else P['accent_dark'])
    paste(icon,load('Items/SelfPropelledMower.png'),(40,48,432,432));d.rounded_rectangle((13,13,499,499),radius=92,outline=P['money'],width=14);icon.convert('RGB').save(OUT/'Store/GameIcon.png')
    return variants
def headline(im,words):
    label=bitmap_text(words,'Display_Headline',2,P['text']);pic=fit(label,(1660,250));im.alpha_composite(pic,((1920-pic.width)//2,42))
def thumbnails():
    title=cover(Image.open(REPO/'art-source/TitleCard/Background_Master.png'),(1920,1080));paste(title,Image.open(REPO/'art-source/TitleCard/Logo.png').convert('RGBA'),(440,65,1040,460));headline_bottom=bitmap_text('Your summer starts here','Display_Headline',1.3);paste(title,headline_bottom,(400,896,1120,150));title.convert('RGB').save(OUT/'Store/Thumbnail_1.png')
    for i,(file,words) in enumerate([('Marketing_Shears.png','Start from the bottom'),('Marketing_Rivals.png',"Beat Grandma's rival"), (None,'Run your own business'),('Marketing_TrophyYard.png','Win Best Yard')],2):
        if file:im=cover(Image.open(HERE/file),(1920,1080))
        else:
            im=cover(Image.open(REPO/'art-source/TitleCard/Background_Master.png'),(1920,1080));paste(im,Image.open(HERE/'BusinessDesk.png').convert('RGBA'),(870,400,850,620))
        headline(im,words);im.convert('RGB').save(OUT/'Store'/('Thumbnail_'+str(i)+'.png'))
def contacts():
    for folder,dest,cols,thumb,cell_w,cell_h in [('Items','Items_ContactSheet.png',10,160,205,215),('Portraits','Portraits_ContactSheet.png',5,256,410,335)]:
        files=sorted((OUT/folder).glob('*.png'));sheet=Image.new('RGB',(cols*cell_w,math.ceil(len(files)/cols)*cell_h),P['panel'])
        for i,p in enumerate(files):
            im=Image.open(p).convert('RGBA');im.thumbnail((thumb,thumb),Image.Resampling.LANCZOS);x=(i%cols)*cell_w+(cell_w-im.width)//2;y=(i//cols)*cell_h+8;sheet.paste(im,(x,y),im)
            text(sheet,((i%cols)*cell_w+cell_w/2,(i//cols)*cell_h+thumb+19),p.stem,13 if folder=='Items' else 24,anchor='mt')
        sheet.save(OUT/'Previews'/dest)
def main():
    sprite_sheets();variants=store_icons()
    hero=Image.open(HERE/'TrophyHero.png').convert('RGBA');im=rays(1024,True);paste(im,hero,(50,20,924,984));im.save(OUT/'Moments/Trophy.png')
    thumbnails();contacts()
    (HERE/'store_ids.json').write_text(json.dumps(dict(pass_ids=['DiamondBlades','RunFlatTires','EndlessSpool','BigTank'],product_ids=variants,game_icon_square_safe_inset_px=40,pass_product_circle_safe_radius_px=222),indent=2)+'\n');print('Store, moments and contact sheets complete')
if __name__=='__main__':main()
