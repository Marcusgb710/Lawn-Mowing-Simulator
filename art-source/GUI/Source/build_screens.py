"""Eleven finished style frames assembled from delivered PNG pieces and bitmap fonts."""
from design import *
from build_fonts import bitmap_text
import shutil
REPO=OUT.parents[1];CACHE={};REGIONS=[]
def load(rel):
    if rel not in CACHE:CACHE[rel]=Image.open(OUT/rel).convert('RGBA')
    return CACHE[rel].copy()
def fit(image,size):
    ratio=min(size[0]/image.width,size[1]/image.height)
    return image.resize((round(image.width*ratio),round(image.height*ratio)),Image.Resampling.LANCZOS)
def cover(image,size):
    factor=max(size[0]/image.width,size[1]/image.height);im=image.resize((round(image.width*factor),round(image.height*factor)),Image.Resampling.LANCZOS)
    x=(im.width-size[0])//2;y=(im.height-size[1])//2;return im.crop((x,y,x+size[0],y+size[1])).convert('RGBA')
def paste(im,image,rect):
    x,y,w,h=map(round,rect);pic=fit(image,(w,h));im.alpha_composite(pic,(x+(w-pic.width)//2,y+(h-pic.height)//2))
def piece(im,name,rect):
    row=json.loads((HERE/'slices.json').read_text())[name];source=load(row['file']);x,y,w,h=map(round,rect)
    sl=row['slice_center_px']
    if sl:
        left,top,right,bottom=sl
        # Fixed borders display at half authoring size (2x source artwork).
        dx=[0,round(left/2),w-round((source.width-right)/2),w];dy=[0,round(top/2),h-round((source.height-bottom)/2),h]
        sx=[0,left,right,source.width];sy=[0,top,bottom,source.height]
        patch=Image.new('RGBA',(w,h))
        for j in range(3):
            for i in range(3):
                if dx[i+1]<=dx[i] or dy[j+1]<=dy[j]:continue
                cut=source.crop((sx[i],sy[j],sx[i+1],sy[j+1])).resize((dx[i+1]-dx[i],dy[j+1]-dy[j]),Image.Resampling.LANCZOS);patch.alpha_composite(cut,(dx[i],dy[j]))
    else:patch=source.resize((w,h),Image.Resampling.LANCZOS)
    im.alpha_composite(patch,(x,y));REGIONS.append(dict(asset=row['file'],rect_px=[x,y,w,h]))
def icon(im,name,rect,color=None):
    pic=load('Icons/'+name+'.png');paste(im,tint(pic,color or P['text']),rect)
def button(im,rect,label,style='Primary',icon_name=None):
    x,y,w,h=rect;h=max(h,88);rect=(x,y,w,h);piece(im,'Button_'+style,rect)
    color=P['ink'] if style.removesuffix('_Pressed') in ['Money','Robux'] else P['text']
    if icon_name:icon(im,icon_name,(x+18,y+18,38,38),color)
    text(im,(x+w/2+(14 if icon_name else 0),y+h/2-4),label,28,color,anchor='mm',bold=True)
def meter(im,rect,share=.65,kind='ProgressFill'):
    x,y,w,h=rect;piece(im,'ProgressTrack',(x,y,w,h));tile=load('Kit/'+kind+'.png').resize((64,max(1,round(h-8))),Image.Resampling.LANCZOS)
    filled=Image.new('RGBA',(max(1,round((w-12)*share)),max(1,round(h-8))))
    for xx in range(0,filled.width,64):filled.alpha_composite(tile,(xx,0))
    im.alpha_composite(filled,(round(x+6),round(y+3)))
def heading(im,xy,label,size=42):text(im,xy,label,size,kind='heading')
def display(im,xy,words,width=300,name='Display_Numbers',color=None):
    pic=bitmap_text(words,name,1,color);paste(im,pic,(xy[0],xy[1],width,100))
def portrait(im,name,rect):
    pic=load('Portraits/'+name+'.png');x,y,w,h=map(round,rect);inner=round((w+10)*208/256);pic=cover(pic,(inner,inner));mask=Image.new('L',(inner,inner));ImageDraw.Draw(mask).ellipse((0,0,inner-1,inner-1),fill=255)
    im.paste(pic,(x+(w-inner)//2,y+(h-inner)//2),mask);piece(im,'PortraitRing',(x-5,y-5,w+10,h+10))
def background(size,story=False):
    path=REPO/'model-source/HighPoly/37_Story/Previews/Scene_Porch.png' if story else REPO/'art-source/TitleCard/Background_Master.png'
    return cover(Image.open(path),size)
def finish(im,name):
    im.convert('RGB').save(OUT/'StyleFrames'/(name+'.png'));im.convert('RGB').save(OUT/'Previews'/(name+'.png'))
    im.resize((im.width//2,im.height//2),Image.Resampling.LANCZOS).convert('RGB').save(OUT/'Previews'/(name+'_50pct.png'))
    return list(REGIONS)

def hud(phone=False):
    size=(2340,1080) if phone else (1920,1080);w,h=size;im=background(size);REGIONS.clear()
    piece(im,'HudPanel',(30,25,425,175));icon(im,'Money',(54,42,56,56),P['money']);display(im,(111,31),'$12,450',300,color=P['money'])
    icon(im,'Level',(58,115,35,35));text(im,(110,115),'Level 6  •  18 jobs done',26,bold=True);meter(im,(106,153,303,23),.57)
    piece(im,'HudPanel',(w-335,25,305,145));icon(im,'CurbAppeal',(w-306,51,48,48));text(im,(w-242,49),'Curb appeal',25);text(im,(w-242,85),'68 / 100',31,bold=True);meter(im,(w-297,133,236,24),.68)
    for i,(label,key,glyph) in enumerate([('Truck','T','Truck'),('Guide','G','Guide'),('Crew','C','Crew')]):
        yy=240+i*108;piece(im,'MenuButton',(26,yy,250,98))
        if phone:icon(im,glyph,(38,yy+30,32,32));text(im,(99,yy+31),label,27,bold=True)
        else:text(im,(54,yy+46),key,29,anchor='mm',bold=True);icon(im,glyph,(104,yy+20,40,40));text(im,(154,yy+31),label,27,bold=True)
    piece(im,'StickyNote',(36,645,395,200));icon(im,'Goal',(57,667,42,42),P['ink']);text(im,(112,667),"GRANDMA'S GOAL",24,P['ink'],kind='heading');paragraph(im,(66,715),'Buy the Reel Push Mower',26,325,P['ink']);text(im,(66,759),'$66 / $150',30,P['ink'],bold=True)
    meter(im,(64,795,320,17),.44)
    piece(im,'GoalTracker',(w-414,240,384,450));heading(im,(w-375,266),'FRONT LAWN',31)
    for i,(label,done) in enumerate([('Mow the lawn',False),('Trim the edges',False),('Pick up junk 1/4',False),('Rake clippings',True)]):
        yy=326+i*54;icon(im,'Check' if done else 'Goal',(w-375,yy,28,28),P['accent'] if done else P['subtext']);text(im,(w-331,yy),label,25)
    icon(im,'Timer',(w-373,557,31,31));text(im,(w-325,555),'03:24 / 05:00',27,bold=True);meter(im,(w-371,603,300,20),.68)
    icon(im,'Damage',(w-373,630,25,25),P['danger']);text(im,(w-331,627),'Damage  $0',24)
    piece(im,'Reticle_Active',(w/2-16,h/2-16,32,32))
    piece(im,'Prompt',(w/2-265,h/2+42,530,88))
    if phone:text(im,(w/2,h/2+82),'Take Reel Push Mower',29,anchor='mm',bold=True)
    else:piece(im,'KeyBadge',(w/2-242,h/2+60,52,52));text(im,(w/2-216,h/2+86),'E',25,anchor='mm',bold=True);text(im,(w/2-170,h/2+70),'Take Reel Push Mower',29,bold=True)
    if phone:
        for i,(glyph,label) in enumerate([('Snip','Snip'),('PickUp','Pick up')]):
            x=w-345+i*165;y=825;piece(im,'TouchButton',(x,y,145,145));icon(im,glyph,(x+37,y+29,72,72));text(im,(x+73,y+154),label,28,anchor='mt',bold=True,stroke=2)
    else:text(im,(w/2,1028),'Hold Alt for the mouse',23,anchor='mm',stroke=2)
    return im

def desktop(title):
    im=cover(load('Computer/Wallpaper.png'),(1920,1080));im.alpha_composite(Image.new('RGBA',im.size,(9,23,13,95)))
    piece(im,'Panel',(55,40,1810,980));heading(im,(105,73),title,42);button(im,(1615,65,190,78),'Back','Neutral','Back')
    piece(im,'Computer/Taskbar',(0,1000,1920,80))
    for i,app in enumerate(['Jobs','Orders','Business','Crew','Messages']):
        paste(im,load('Computer/App_'+app+'.png'),(42+i*185,1009,50,50));text(im,(103+i*185,1023),app,24)
    display(im,(1480,996),'$12,450',345,color=P['money']);return im
def jobs():
    im=desktop('Jobs  /  Maple Grove');text(im,(110,180),'Good work travels down the street.',29,P['subtext'])
    for i,(who,address,wants,pay) in enumerate([('Edna Alvarez','24 Maple St','Front Lawn','$66'),('Mrs. Rossi','118 Oak Ave','Mow, edge and rake','$184'),('Ms. Nguyen','62 Birch Ln','Perfect edges and flower beds','$320')]):
        x=100+i*575;piece(im,'Card',(x,260,550,650));icon(im,'Jobs',(x+35,294,68,68));heading(im,(x+35,387),who,36)
        text(im,(x+35,446),address,23,P['subtext']);paragraph(im,(x+35,490),wants,29,465)
        for k,line in enumerate(['Front lawn','Pick up junk','Leave it spotless']):icon(im,'Check',(x+35,591+k*45,25,25),P['accent']);text(im,(x+77,586+k*45),line,26)
        display(im,(x+30,721),pay,240,color=P['money'])
        button(im,(x+35,815,480,78),'Take job','Primary')
        if i==1:paste(im,load('Wordmarks/Stamp_TakenByTurfKing.png'),(x+20,537,510,150));button(im,(x+35,815,480,78),'Taken','Disabled')
    return im
def orders():
    im=desktop('Orders  /  Tools & supplies')
    for i,label in enumerate(['Mowers','Trimmers','Rakes & Blowers','Supplies','Decorations','Premium']):
        x=104+i*282;piece(im,'Tab_Active' if i==0 else 'Tab',(x,177,265,92));text(im,(x+132,219),label,24,anchor='mm',bold=True)
    entries=[('ReelMower','Reel Push Mower','Homeowner • Wall rack','$150','Money'),('GasPushMower','Gas Push Mower','Homeowner • Floor spot','Bought','Disabled'),('SelfPropelledMower','Self-Propelled Mower','Serious • Floor spot','Sell $7','Danger'),('RidingMower','Riding Mower','Serious • Equipment bay','Locked','Disabled')]
    for i,(item,label,storage,state,style) in enumerate(entries):
        x=105+i*429;piece(im,'Card_Locked' if state=='Locked' else 'Card',(x,285,405,660));paste(im,load('Items/'+item+'.png'),(x+35,307,335,280))
        for j,line in enumerate(wrap(label,29,335,'heading')):heading(im,(x+35,595+j*39),line,29)
        text(im,(x+35,696),storage,23,P['subtext']);paragraph(im,(x+35,739),'Reliable equipment for a lawn worth showing off.',24,335)
        button(im,(x+26,840,353,86),state,style,'Lock' if state=='Locked' else None)
    return im
def premium():
    im=desktop('Orders  /  Premium');text(im,(115,177),'PRO UPGRADES',28,P['money'],kind='heading')
    for i,(item,label,price) in enumerate([('Pass_DiamondBlades','Diamond Blades','R$ 199'),('Pass_RunFlatTires','Run-Flat Tires','R$ 149'),('Pass_EndlessSpool','Endless Spool','R$ 99'),('Pass_BigTank','Big Tank','Owned')]):
        x=111+i*429;piece(im,'Card',(x,220,402,270));paste(im,load('Store/'+item+'.png'),(x+20,240,145,145));heading(im,(x+178,249),label,23);button(im,(x+160,351,220,92),price,'Robux' if price!='Owned' else 'Disabled')
    for xx,title in [(115,'PREMIUM TOOLS'),(1010,'TRUCK PAINT')]:heading(im,(xx,535),title,28)
    for i,(item,title,label) in enumerate([('GoldenGasPushMower','Golden Push Mower','R$ 249'),('ChromeSelfPropelledMower','Chrome Self-Propelled Mower','Owned'),('RacingRed','Racing Red','Use'),('StealthWrap','Stealth Wrap','In use')]):
        x=112+i*429;piece(im,'Card',(x,587,402,360));paste(im,load('Items/'+item+'.png'),(x+28,605,346,192));paragraph(im,(x+28,805),title,24,345);button(im,(x+25,860,352,78),label,'Robux' if 'R$' in label else 'Neutral')
    return im
def messages():
    im=desktop('Messages');piece(im,'Card',(95,177,487,780))
    for i,(name,face,preview) in enumerate([('Grandma June','June_Neutral','Now THAT is a mower.'),('Bridge Club','BridgeClub','Free Thursday?'),('Chad • TurfKing','Chad_Cocky','Cute scissors, bud.'),('Sam','Sam_Happy','if you ever need help lmk')]):
        y=200+i*165;piece(im,'ThreadCard_Active' if i==0 else 'ThreadCard',(113,y,450,147));portrait(im,face,(131,y+18,91,91));heading(im,(240,y+26),name,25);text(im,(240,y+75),preview,20,P['subtext'])
        if i==0:piece(im,'Badge_Unread',(509,y+23,31,31));text(im,(525,y+36),'1',17,anchor='mm',bold=True)
    portrait(im,'June_Proud',(637,189,120,120));heading(im,(790,204),'Grandma June',36);text(im,(792,254),'Grandma is typing…',24,P['subtext'])
    for name,rect,line in [('Bubble_Theirs',(648,350,1010,145),'Now THAT is a mower. Your grandfather had one just like it.'),('Bubble_Theirs',(648,515,1010,130),'He was terrible with it.'),('Bubble_Mine',(870,670,881,110),'I will make you proud, Grandma.')]:
        piece(im,name,rect);paragraph(im,(rect[0]+32,rect[1]+30),line,31,rect[2]-64)
    piece(im,'GoalCard',(646,814,1110,140));icon(im,'Goal',(678,842,47,47),P['money']);heading(im,(750,839),'BUY THE REEL PUSH MOWER',27);text(im,(750,884),'$66 / $150 saved',26,P['subtext']);return im
def dialogue(phone=False):
    size=(2340,1080) if phone else (1920,1080);w,h=size;im=background(size,True)
    bar=load('Kit/Letterbox.png').resize((w,82));im.alpha_composite(bar,(0,0));im.alpha_composite(bar.transpose(Image.Transpose.FLIP_TOP_BOTTOM),(0,h-82))
    piece(im,'Bubble',(w-645,180,565,155));piece(im,'BubbleTail',(w-475,311,75,45));paragraph(im,(w-609,213),'Morning, June! Lovely… dandelions.',30,490,P['ink'])
    piece(im,'DialogueBox',(265,h-358,w-340,280));portrait(im,'June_Annoyed',(51,h-424,270,270));piece(im,'NameTag',(343,h-398,348,80));text(im,(514,h-362),'GRANDMA JUNE',27,P['ink'],anchor='mm',kind='heading')
    paragraph(im,(354,h-312),"Thirty years. Thirty years I've won Best Yard on this street… and Gloria Pemberton goes and hires somebody.",35,w-470,line_height=46)
    for i in range(5):ImageDraw.Draw(im).ellipse((359+i*22,h-145,368+i*22,h-136),fill=P['money'] if i==1 else P['subtext'])
    text(im,(w-460,h-142),'Tap to continue' if phone else 'Click to continue',26,bold=True);icon(im,'Continue',(w-200,h-150,30,30));button(im,(w-223,25,184,92),'Skip','Neutral','Skip');return im
def pay():
    im=background((1920,1080));im.alpha_composite(Image.new('RGBA',im.size,(10,27,13,150)))
    piece(im,'Panel',(380,60,1160,940));paste(im,load('Wordmarks/JobComplete.png'),(550,100,820,140));heading(im,(475,280),"EDNA'S FRONT LAWN",32)
    lines=[('Job pay','+$66'),('Finish quality','+$18'),('Speed bonus','+$8'),('Crew bonus','+$0'),('Curb appeal','+$6'),('Junk cleared','+$4'),('Damage','−$0')]
    for i,(label,value) in enumerate(lines):y=355+i*59;text(im,(480,y),label,30);text(im,(1440,y),value,32,P['money'],anchor='ra',bold=True)
    meter(im,(474,797,972,13),1);heading(im,(480,847),'TOTAL EARNED',32);display(im,(1110,815),'$102',340,color=P['money']);button(im,(652,912,616,84),'Back to the truck','Primary');return im
def contest():
    im=cover(Image.open(REPO/'model-source/HighPoly/37_Story/Previews/Scene_Contest.png'),(1920,1080));im.alpha_composite(Image.new('RGBA',im.size,(10,27,13,150)))
    piece(im,'Panel',(220,45,1480,975));piece(im,'Ribbon',(435,62,1050,151));paste(im,load('Wordmarks/BestYard.png'),(515,84,890,100));paste(im,load('Moments/Trophy.png'),(810,218,300,300));paste(im,load('Wordmarks/Winner.png'),(690,450,540,120))
    heading(im,(325,251),"JUNE'S YARD",33);heading(im,(1240,251),"GLORIA'S YARD",33)
    display(im,(325,340),'95/100',380,color=P['accent']);display(im,(1240,340),'88/100',380,color=P['subtext'])
    for i,(label,you,rival) in enumerate([('Lawn & stripes',24,22),('Edges',24,23),('Beds & shrubs',23,21),('Decor & charm',24,22)]):
        y=594+i*67;text(im,(325,y),label,27);meter(im,(658,y-3,420,25),you/25,'ScoreFill_You');text(im,(1113,y),str(you),28,P['accent'],bold=True);meter(im,(1190,y-3,320,25),rival/25,'ScoreFill_Rival');text(im,(1540,y),str(rival),28,P['subtext'],bold=True)
    text(im,(338,896),'31st trophy  •  $2,500  •  Best Yard Trophy',30,P['money'],bold=True);button(im,(1206,891,380,90),'Celebrate','Primary');return im
def sheet():
    im=Image.new('RGBA',(2048,2048),P['panel']);heading(im,(76,48),'MAPLE GROVE SUMMER',63);text(im,(80,135),'Sunny, tactile, phone-first • final art system',33,P['subtext'])
    for i,(name,col) in enumerate(P.items()):
        x=85+(i%8)*244;y=225+(i//8)*124;ImageDraw.Draw(im).rounded_rectangle((x,y,x+63,y+63),radius=16,fill=col,outline=P['text'],width=2);text(im,(x+77,y),name,22);text(im,(x+77,y+35),col,21,P['subtext'])
    heading(im,(85,535),'TYPE & NUMBERS',35);heading(im,(85,599),'DenkOne headings',40);text(im,(85,665),'Nunito • readable live text',30);display(im,(80,715),'$12,450',470,color=P['money'])
    paste(im,bitmap_text('Best Yard','Display_Headline',1),(690,560,550,145));paragraph(im,(1350,557),'Lilita One images for big moments. Two aligned layers: white face, deep-green outline and shadow.',28,570)
    for i,style in enumerate(['Primary','Money','Danger','Neutral','Disabled','Robux']):
        x=82+(i%3)*635;y=865+(i//3)*128;button(im,(x,y,350,100),style,style)
        button(im,(x+365,y,225,100),'Pressed',style+'_Pressed')
    piece(im,'Panel',(82,1190,590,340));heading(im,(120,1225),'Panel, card & tabs',35)
    piece(im,'Card',(104,1290,548,210))
    for i in range(2):piece(im,'Tab_Active' if i==0 else 'Tab',(118+i*245,1310,230,92));text(im,(228+i*245,1352),'Mowers' if i==0 else 'Supplies',25,anchor='mm')
    meter(im,(120,1440,490,27),.68)
    for i,(name,label) in enumerate([('Prompt','Take Reel Push Mower'),('Prompt_Blocked',"That won't fit there.")]):piece(im,name,(740,1188+i*125,570,103));text(im,(781,1221+i*125),label,27,bold=True)
    piece(im,'Toast',(740,1450,570,100));icon(im,'Messages',(765,1471,36,36));text(im,(824,1480),'New text from Grandma June',24)
    piece(im,'Bubble_Theirs',(1380,1190,570,150));paragraph(im,(1410,1220),'You missed a spot.',28,500)
    piece(im,'StickyNote',(1380,1390,570,150));text(im,(1420,1430),"GRANDMA'S GOAL",28,P['ink'],kind='heading')
    for i,name in enumerate(['Money','Truck','Crew','Snip','Talk','Crown','Junk','Score_Lawn','Score_Beds','Premium']):icon(im,name,(100+i*189,1675,102,102))
    text(im,(85,1860),'White tintable glyphs • 8 px rounded strokes • 32 px legibility',31,P['subtext']);text(im,(85,1930),'2x frames • 9-slice borders • 44 px minimum touch targets',31,P['subtext']);return im
def main():
    porch=Image.open(HERE/'Marketing_Wallpaper.png')
    wallpaper=cover(porch,(1024,576)).filter(ImageFilter.GaussianBlur(8));wallpaper.convert('RGB').save(OUT/'Computer/Wallpaper.png')
    layouts={}
    for name,fn in [('HUD_PC',lambda:hud(False)),('HUD_Phone',lambda:hud(True)),('Computer_Jobs',jobs),('Computer_Orders',orders),('Computer_Premium',premium),('Computer_Messages',messages),('Dialogue_PC',lambda:dialogue(False)),('Dialogue_Phone',lambda:dialogue(True)),('PayBreakdown',pay),('BestYard',contest),('Sheet',sheet)]:
        REGIONS.clear();im=fn();layouts[name]=finish(im,name);print('FRAME',name,flush=True)
    (HERE/'frame_layouts.json').write_text(json.dumps(layouts,indent=2)+'\n')
if __name__=='__main__':main()
