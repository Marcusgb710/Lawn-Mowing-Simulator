"""Consistent 8 px rounded white glyphs, also saved as editable SVG paths."""
from design import *
SVG=HERE/'GlyphSVG';SVG.mkdir(exist_ok=True)
class Glyph:
    def __init__(self):self.im=Image.new('RGBA',(512,512));self.d=ImageDraw.Draw(self.im);self.svg=[]
    def line(self,pts,width=8):
        self.d.line([(x*4,y*4) for x,y in pts],fill='white',width=width*4,joint='curve')
        for x,y in pts:self.d.ellipse(((x-width/2)*4,(y-width/2)*4,(x+width/2)*4,(y+width/2)*4),fill='white')
        self.svg.append('<polyline points="'+' '.join(f'{x},{y}' for x,y in pts)+'" fill="none" stroke="white" stroke-width="'+str(width)+'" stroke-linecap="round" stroke-linejoin="round"/>')
    def ellipse(self,box,fill=False,width=8):
        b=[v*4 for v in box];self.d.ellipse(b,fill='white' if fill else None,outline=None if fill else 'white',width=width*4)
        x1,y1,x2,y2=box;self.svg.append(f'<ellipse cx="{(x1+x2)/2}" cy="{(y1+y2)/2}" rx="{(x2-x1)/2}" ry="{(y2-y1)/2}" fill="'+('white' if fill else 'none')+'" stroke="white" stroke-width="'+str(0 if fill else width)+'"/>')
    def rect(self,box,fill=False):
        self.d.rounded_rectangle([v*4 for v in box],radius=7*4,fill='white' if fill else None,outline=None if fill else 'white',width=8*4)
        x1,y1,x2,y2=box;self.svg.append(f'<rect x="{x1}" y="{y1}" width="{x2-x1}" height="{y2-y1}" rx="7" fill="'+('white' if fill else 'none')+'" stroke="white" stroke-width="'+str(0 if fill else 8)+'"/>')
    def poly(self,pts):
        self.d.polygon([(x*4,y*4) for x,y in pts],fill='white');self.svg.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in pts)+'" fill="white"/>')
    def save(self,name):
        self.im.resize((128,128),Image.Resampling.LANCZOS).save(OUT/'Icons'/(name+'.png'))
        (SVG/(name+'.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n'+'\n'.join(self.svg)+'\n</svg>\n')
def star(g,c=(64,64),r=38):
    pts=[]
    for k in range(10):t=-math.pi/2+k*math.pi/5;rr=r if k%2==0 else r*.44;pts.append((c[0]+rr*math.cos(t),c[1]+rr*math.sin(t)))
    g.poly(pts)
def person(g,x,y,scale=1):
    g.ellipse((x-10*scale,y-14*scale,x+10*scale,y+6*scale));g.line([(x-19*scale,y+37*scale),(x-17*scale,y+20*scale),(x,y+13*scale),(x+17*scale,y+20*scale),(x+19*scale,y+37*scale)])
def mower(g):
    g.line([(20,88),(82,88),(82,75),(40,75),(28,35),(17,30)])
    g.ellipse((24,84,44,104));g.ellipse((70,84,90,104));g.rect((51,57,74,74))
def truck(g):
    g.line([(17,83),(17,51),(69,51),(69,34),(91,34),(110,62),(110,83)])
    g.line([(69,52),(96,52)]);g.line([(34,91),(90,91)]);g.ellipse((23,80,44,102));g.ellipse((84,80,105,102))
def crown_icon(g):g.line([(23,90),(105,90),(108,38),(83,60),(64,24),(45,60),(20,38),(23,90)]);g.line([(27,102),(101,102)])
def build(name):
    g=Glyph()
    if name=='Money':g.ellipse((20,20,108,108));g.ellipse((32,32,96,96),width=5);g.line([(64,42),(64,86)],10)
    elif name=='Level':star(g)
    elif name=='CurbAppeal':g.line([(23,61),(23,105),(96,105),(96,61),(60,29),(16,66)]);g.rect((48,77,69,105));star(g,(97,29),17)
    elif name in ['Truck','Cat_Truck']:truck(g)
    elif name=='Guide':
        g.line([(64,36),(64,106)]);g.line([(64,36),(43,25),(17,25),(17,94),(44,94),(64,106),(84,94),(111,94),(111,25),(85,25),(64,36)])
        for x in [28,77]:
            for y in [45,60,75]:g.line([(x,y),(x+23,y)],5)
    elif name=='Crew':person(g,45,40,.85);person(g,87,44,.8)
    elif name=='Close':g.line([(31,31),(97,97)],10);g.line([(97,31),(31,97)],10)
    elif name=='Back':g.line([(56,28),(22,64),(56,100)]);g.line([(24,64),(107,64)])
    elif name=='Check':g.line([(26,65),(51,91),(104,32)],11)
    elif name=='Lock':g.rect((25,55,103,108));g.line([(39,55),(39,34),(48,20),(79,20),(90,34),(90,55)]);g.ellipse((59,72,69,82),True);g.line([(64,80),(64,94)],6)
    elif name=='Timer':g.ellipse((26,31,104,109));g.line([(65,71),(65,44)]);g.line([(64,71),(84,80)]);g.line([(49,17),(79,17)]);g.line([(64,18),(64,29)])
    elif name=='Damage':g.line([(64,18),(113,106),(15,106),(64,18)]);g.line([(64,47),(64,75)],10);g.ellipse((59,88,69,98),True)
    elif name=='Info':g.ellipse((18,18,110,110));g.ellipse((59,35,69,45),True);g.line([(64,59),(64,91)],9)
    elif name=='Goal':g.line([(28,109),(28,22),(98,22),(81,45),(98,68),(29,68)])
    elif name=='Jobs':g.rect((29,23,100,109));g.rect((46,16,82,36));g.line([(44,58),(84,58)],6);g.line([(44,76),(84,76)],6);g.line([(44,94),(69,94)],6)
    elif name=='Orders':g.line([(19,47),(64,22),(109,47),(109,99),(64,113),(19,99),(19,47),(64,67),(109,47)]);g.line([(64,67),(64,113)]);g.line([(41,35),(86,56)])
    elif name in ['Business','Cat_Business']:
        g.line([(20,56),(20,108),(108,108),(108,56)]);g.line([(14,54),(28,24),(100,24),(114,54),(14,54)]);g.rect((35,72,58,106));g.rect((75,73,97,93))
        for x in [35,64,92]:g.line([(x,28),(x,51)],6)
    elif name in ['Messages','Talk']:g.line([(20,26),(108,26),(108,89),(60,89),(35,110),(37,89),(20,89),(20,26)]);g.line([(37,48),(91,48)],6);g.line([(37,67),(77,67)],6)
    elif name=='Sell':g.line([(18,56),(60,18),(110,68),(68,110),(18,61),(18,56)]);g.ellipse((35,39,47,51),True)
    elif name=='Premium':g.line([(30,28),(98,28),(114,55),(64,112),(14,55),(30,28)]);g.line([(14,55),(114,55)]);g.line([(44,29),(36,55),(64,109),(91,55),(81,29)])
    elif name=='Cat_Mower':mower(g)
    elif name=='Cat_Trimmer':g.line([(36,103),(94,20)]);g.rect((77,16,106,41));g.line([(29,98),(58,119)]);g.line([(22,108),(46,82),(66,98)])
    elif name=='Cat_Rake':g.line([(64,19),(64,80)]);g.line([(27,82),(101,82)]);[g.line([(x,82),(x,108)],6) for x in [28,46,64,82,100]]
    elif name=='Cat_Edger':g.line([(28,21),(28,71),(87,90)]);g.ellipse((67,69,108,110));g.line([(84,87),(84,44)])
    elif name=='Cat_HedgeTrimmer':g.rect((19,28,54,70));g.line([(47,64),(104,112)],12);[g.line([(55+k*9,67+k*8),(62+k*9,59+k*8)],6) for k in range(5)]
    elif name=='Cat_HandTool':g.line([(27,105),(65,66)]);g.poly([(57,73),(66,38),(105,19),(94,57),(57,73)])
    elif name in ['Cat_Pruning','Snip']:
        g.ellipse((19,80,49,111));g.ellipse((76,80,106,111));g.line([(42,84),(85,22)]);g.line([(84,84),(42,22)]);g.ellipse((58,57,70,69),True)
    elif name=='Cat_Watering':g.rect((28,58,91,103));g.line([(90,76),(109,45),(119,49)]);g.line([(30,65),(17,41),(37,26),(63,28),(66,57)]);g.line([(109,27),(110,17)],6)
    elif name=='Cat_Digging':g.line([(64,44),(64,85)]);g.line([(47,18),(47,42),(81,42),(81,18),(47,18)]);g.poly([(40,77),(88,77),(84,102),(64,118),(44,102)])
    elif name=='Cat_Hauling':g.line([(17,56),(100,56),(81,91),(40,91),(17,56),(12,37)]);g.ellipse((55,85,79,109));g.line([(86,58),(113,40)])
    elif name=='Cat_LawnCare':g.rect((34,43,98,83));g.line([(40,45),(31,20),(18,20)]);g.ellipse((42,85,62,105));g.ellipse((83,85,103,105));g.line([(65,44),(65,17)])
    elif name=='Cat_Protection':
        g.line([(28,88),(21,69),(23,58),(32,62),(39,78),(39,27),(46,22),(51,27),(51,61),(53,18),(61,16),(66,21),(65,62),(69,24),(77,23),(82,29),(79,68),(85,40),(93,39),(98,47),(95,89),(82,111),(43,111),(28,88)],7)
    elif name=='Cat_Supplies':g.rect((26,45,103,109));g.line([(43,43),(43,24),(86,24),(86,44)]);g.line([(27,68),(102,68)])
    elif name=='Cat_Decorations':
        for x in [25,63,101]:g.line([(x,109),(x,29),(x+9,18),(x+18,29),(x+18,109)],6)
        g.line([(18,54),(118,54)]);g.line([(18,87),(118,87)])
    elif name=='Cat_Trailer':g.rect((22,47,94,89));g.line([(94,89),(115,89),(115,76)]);g.ellipse((38,80,62,104));g.ellipse((70,80,94,104))
    elif name=='Fuel':g.line([(30,28),(91,28),(104,104),(22,104),(30,28)]);g.rect((45,16,78,30));g.line([(42,47),(85,88)]);g.line([(85,47),(42,88)])
    elif name=='Tire':g.ellipse((18,18,110,110),width=17);g.ellipse((49,49,79,79),width=6)
    elif name=='Blade':g.poly([(16,78),(103,24),(112,51),(26,106)]);g.ellipse((58,59,70,71),True)
    elif name=='Spool':g.ellipse((24,25,104,49));g.line([(25,37),(25,92)]);g.line([(103,37),(103,92)]);g.ellipse((24,79,104,105));g.line([(103,90),(115,110)])
    elif name=='Wrench':g.line([(93,18),(79,33),(83,48),(99,51),(113,37),(108,65),(88,74),(41,115),(20,94),(62,48),(66,28),(93,18)],7)
    elif name=='Sharp':g.poly([(23,88),(94,21),(108,37),(37,105)]);star(g,(31,31),16)
    elif name=='PickUp':g.line([(26,103),(26,80),(41,59),(50,60),(50,26),(59,21),(67,26),(67,66),(91,66),(104,81),(98,109),(45,109),(26,103)])
    elif name=='Place':g.rect((40,47,90,91));g.line([(18,40),(18,18),(42,18)]);g.line([(90,18),(112,18),(112,41)]);g.line([(18,91),(18,111),(40,111)]);g.line([(91,111),(112,111),(112,91)])
    elif name=='Turn':g.line([(29,85),(19,66),(26,40),(49,22),(78,22),(98,38),(106,60)]);g.line([(87,53),(108,66),(117,44)]);g.line([(89,91),(65,106),(40,99)])
    elif name=='PutBack':g.rect((27,71,105,110));g.line([(63,79),(63,23)]);g.line([(42,47),(63,24),(85,47)])
    elif name=='Continue':g.line([(44,26),(85,64),(44,102)],12)
    elif name=='Skip':g.line([(27,28),(73,64),(27,100)],10);g.line([(96,26),(96,102)],10)
    elif name.startswith('Tier_'):
        g.line([(22,24),(106,24),(102,88),(64,115),(26,88),(22,24)],6)
        count={'Tier_Homeowner':1,'Tier_Serious':2,'Tier_Pro':3}[name]
        for i in range(count):g.line([(43,49+i*17),(64,62+i*17),(85,49+i*17)],6)
    elif name=='Score_Lawn':
        for x in [24,45,66,87]:g.line([(x,105),(x+11,26)],8)
        g.line([(16,107),(111,107)])
    elif name=='Score_Edges':g.line([(23,24),(23,103),(107,103)],11);g.line([(46,24),(46,81),(107,81)],6)
    elif name=='Score_Beds':
        g.line([(64,107),(64,64)]);g.ellipse((47,33,81,67));
        for box in [(32,33,59,60),(69,33,96,60),(48,17,79,47),(48,56,79,85)]:g.ellipse(box)
        g.line([(64,88),(36,76)]);g.line([(64,87),(92,73)])
    elif name=='Score_Decor':star(g);g.ellipse((17,17,111,111),width=5)
    elif name=='Crown':crown_icon(g)
    elif name=='Junk':g.line([(20,96),(89,29)],12);g.line([(60,59),(91,65)],7);g.ellipse((70,78,110,118))
    else:raise ValueError(name)
    g.save(name)
def main():
    groups=[['Money','Level','CurbAppeal','Truck','Guide','Crew','Close','Back','Check','Lock','Timer','Damage','Info','Goal'],['Jobs','Orders','Business','Messages','Sell','Premium'],['Cat_'+n for n in ['Mower','Trimmer','Rake','Edger','HedgeTrimmer','HandTool','Pruning','Watering','Digging','Hauling','LawnCare','Protection','Supplies','Decorations','Truck','Trailer','Business']],['Fuel','Tire','Blade','Spool','Wrench','Sharp'],['Snip','PickUp','Place','Turn','PutBack','Talk','Continue','Skip'],['Tier_Homeowner','Tier_Serious','Tier_Pro'],['Score_Lawn','Score_Edges','Score_Beds','Score_Decor'],['Crown','Junk']]
    names=sum(groups,[])
    for n in names:build(n)
    (HERE/'glyphs.json').write_text(json.dumps(names,indent=2)+'\n')
    for app,color in [('Jobs','accent_dark'),('Orders','money'),('Business','info'),('Crew','rival'),('Messages','hat_band')]:
        im=Image.new('RGBA',(768,768));d=ImageDraw.Draw(im)
        d.rounded_rectangle((24,33,744,744),radius=138,fill=P['ink'])
        d.rounded_rectangle((24,18,744,717),radius=138,fill=P[color],outline=P['ink'],width=18)
        d.arc((57,48,711,681),190,340,fill=P['text'],width=8)
        glyph=Image.open(OUT/'Icons'/(app+'.png')).resize((450,450),Image.Resampling.LANCZOS)
        im.alpha_composite(glyph,(159,129));im.resize((256,256),Image.Resampling.LANCZOS).save(OUT/'Computer'/('App_'+app+'.png'))
    sheet=Image.new('RGB',(1280,math.ceil(len(names)/10)*110),P['panel'])
    for i,n in enumerate(names):
        im=Image.open(OUT/'Icons'/(n+'.png')).resize((32,32),Image.Resampling.LANCZOS)
        x=15+(i%10)*128;y=14+(i//10)*110;sheet.paste(im,(x+36,y),im);text(sheet,(x+52,y+45),n,11,anchor='mt')
    sheet.save(OUT/'Previews/Glyphs_32px.png');print('Glyphs:',len(names))
if __name__=='__main__':main()
