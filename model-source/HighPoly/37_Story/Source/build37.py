"""Grandma's Rival: clothed static cast, story locations and lawn debris.
All modelling coordinates are Roblox studs; serialization converts to metres.
"""
from core import *
COLORS.update(skin=(212,164,132),skin_warm=(175,119,84),skin_deep=(126,80,60),sage=(133,155,116),cream=(241,229,200),khaki=(159,144,108),lavender=(167,146,193),silver_hair=(186,183,172),blonde=(204,192,155),hair_dark=(62,49,40),gold=(220,176,61),crown_gold=(238,190,53),turf_purple=(91,55,152),house_blue=(156,184,194),roof=(61,67,73),rose=(190,73,93),iris=(71,100,83),marble=(45,91,61),paper=(220,213,184))
KINDS.update(skin='fabric',skin_warm='fabric',skin_deep='fabric',sage='fabric',khaki='fabric',lavender='fabric',cream='fabric',silver_hair='fabric',blonde='fabric',hair_dark='fabric',gold='chrome',crown_gold='chrome',marble='stone',roof='stone')
COLORS['polo_purple']=COLORS['turf_purple'];KINDS['polo_purple']='fabric'
COLORS['shirt_green']=COLORS['green'];KINDS['shirt_green']='fabric'
COLORS['shirt_blue']=COLORS['house_blue'];KINDS['shirt_blue']='fabric'
COLORS['tennis_felt']=(207,210,59);KINDS['tennis_felt']='fabric'
COLORS['mulch_black']=(37,31,24);KINDS['mulch_black']='soil'

def marker(a,name,p,parent=None,look=(0,0,-1)):
    if not hasattr(a,'extra_markers'):a.extra_markers=[]
    a.extra_markers.append(dict(name=name,instance_type='Attachment',parent_mesh=parent or a.name+'__Body',position_studs=list(p),orientation_degrees=[0,0,0],look_vector=list(look),attributes={}))

def loft(a,label,rings,color,n=32):
    # Each ring is centre x/y/z, half-width and half-depth; sinusoidal profile
    # variations form subtle cloth folds rather than disconnected armour pieces.
    verts=[];faces=[]
    for j,(x,y,z,rx,rz) in enumerate(rings):
        for k in range(n):
            t=k*TAU/n;fold=1+.016*math.sin(t*7+j*.8)
            verts.append((x+rx*math.cos(t)*fold,y,z+rz*math.sin(t)*fold))
    for j in range(len(rings)-1):
        for k in range(n):q=(k+1)%n;faces.append((j*n+k,j*n+q,(j+1)*n+q,(j+1)*n+k))
    faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+k for k in range(n))])
    a.mesh(label,verts,faces,color)

def limb(a,label,points,radii,color,n=16):
    pts=catmull(points,3)
    rr=[]
    for j in range(len(pts)):
        t=j/(len(pts)-1)*(len(radii)-1);i=min(int(t),len(radii)-2);rr.append(radii[i]*(1-(t-i))+radii[i+1]*(t-i))
    a.tube(label,pts,color=color,sides=n,radii=rr)

def hand(a,p,skin,pose='relaxed'):
    x,y,z=p
    a.sphere('Palm with knuckles',(.23,.29,.12),(x,y,z),skin,16,8)
    for i in range(4):
        xx=x+(i-1.5)*.052;length=[.16,.205,.19,.15][i]
        if pose=='up':points=[(xx,y-.02,z),(xx,y+length*.55,z-.025),(xx,y+length,z-.05)]
        else:points=[(xx,y-.065,z-.02),(xx,y-.12,z-.045),(xx,y-.08-length*.25,z-.085)]
        limb(a,'Separate articulated finger',points,[.032,.029,.023],skin,8)
        a.sphere('Finger nail',(.035,.045,.012),(points[-1][0],points[-1][1],points[-1][2]-.021),'cream',8,4)
    limb(a,'Opposable thumb',[(x-.095,y+.01,z),(x-.16,y-.07,z-.03),(x-.13,y-.12,z-.09)],[.04,.034,.027],skin,10)

def mug(a,p,china=False):
    x,y,z=p
    a.lathe('Hollow tea cup' if china else 'Hollow coffee mug',[(0,.13),(.02,.17),(.25,.18),(.29,.19),(.29,.16),(.06,.14),(.04,0)],p,'cream',segments=24)
    a.ring('Cup handle',(x+.19,y+.16,z),.10,.09,.025,'xy','gold' if china else 'cream',24,8)
    a.lathe('Coffee surface',[(0,.145),(.008,.145)],(x,y+.23,z),'wood_dark',segments=24)
    if china:a.lathe('China saucer',[(0,.04),(.02,.27),(.055,.29),(.08,.18)],(x,y-.05,z),'cream',segments=24)

def crown(a,p,size=.25):
    outline=[(-.5,-.32),(.5,-.32),(.5,.28),(.23,.08),(0,.48),(-.23,.08),(-.5,.28)]
    a.profile('Five-point crown emblem',[(x*size,z*size) for x,z in outline],.018,p,'crown_gold',R(x=-90))

def face(a,cy,skin,hair,mood,hat=False,glasses=False,bob=False,curly=False,young=False):
    with a.moving(a.name+'__Head',(0,cy-.46,0),'head'):
        a.sphere('Sculpted face and jaw',(.86,1.04,.79),(0,cy,0),skin,32,18)
        a.sphere('Soft chin',(.45,.27,.30),(0,cy-.36,-.20),skin,20,8)
        for side in [-1,1]:
            a.sphere('Ear',(.15,.25,.16),(side*.438,cy-.04,.015),skin,16,8)
            a.sphere('Ear inner fold',(.07,.13,.035),(side*.45,cy-.04,-.065),'skin_warm',12,6)
            x=side*.187
            a.sphere('White of eye',(.225,.125,.095),(x,cy+.105,-.361),'cream',20,8)
            a.sphere('Iris',(.077,.089,.032),(x,cy+.105,-.414),'iris',16,8)
            a.sphere('Pupil',(.041,.058,.021),(x,cy+.105,-.432),'black',12,6)
            a.sphere('Eye catchlight',(.018,.021,.012),(x-.017,cy+.125,-.445),'white',8,4)
            a.tube('Upper eyelid',[(x-.105,cy+.108,-.38),(x,cy+.178,-.399),(x+.105,cy+.108,-.38)],.016,skin,10,curve=True)
            a.tube('Lower eyelid',[(x-.097,cy+.094,-.38),(x,cy+.052,-.405),(x+.097,cy+.094,-.38)],.009,skin,8,curve=True)
            raised=.07 if mood in ['unimpressed','smug'] and side==-1 else 0
            a.tube('Expressive eyebrow',[(x-.10,cy+.235+raised,-.337),(x,cy+.26+raised,-.36),(x+.10,cy+.23+raised,-.34)],.022,hair,12,curve=True)
            if not young:
                for k in range(2):a.tube('Eye smile crease',[(side*.30,cy+.06-k*.04,-.32),(side*.37,cy+.04-k*.04,-.29)],.007,'skin_warm',6)
            if glasses:
                a.ring('Round wire spectacles',(x,cy+.10,-.446),.15,.126,.009,'xy','steel_dark',32,6)
                a.bar('Glasses temple',(side*.33,cy+.10,-.43),(side*.44,cy+.1,.04),.009,'steel_dark',8)
        if glasses:a.tube('Spectacle bridge',[(-.04,cy+.12,-.446),(0,cy+.14,-.45),(.04,cy+.12,-.446)],.008,'steel_dark',8,curve=True)
        a.sphere('Nose bridge',(.15,.29,.19),(0,cy-.015,-.365),skin,20,9)
        a.sphere('Nose tip',(.18,.14,.17),(0,cy-.105,-.443),skin,20,8)
        for x in [-.063,.063]:a.sphere('Nostril',(.038,.024,.018),(x,cy-.133,-.497),'skin_warm',8,4)
        smile=mood not in ['fedup','unimpressed','fussy']
        yy=cy-.255
        a.tube('Mouth expression',[(-.17,yy+(.045 if smile else -.015),-.345),(0,yy-.022,-.388),(.17,yy+(.045 if smile else .005),-.345)],.016,'wood_dark',10,curve=True)
        a.tube('Lower lip',[(-.11,yy-.025,-.36),(0,yy-.055,-.382),(.11,yy-.025,-.36)],.013,'skin_warm',10,curve=True)
        if mood in ['grin','happy']:
            a.sphere('Open smiling mouth',(.28,.087,.038),(0,yy,-.385),'wood_dark',20,6)
            a.box('Visible smile teeth',(.21,.033,.018),(0,yy+.022,-.411),'cream',.008)
        # A shaped hair cap and layered individual locks leave forehead exposed.
        a.sphere('Hair cap',(.90,.58,.73),(0,cy+.29,.07),hair,24,12)
        rng=random.Random(17)
        for i in range(18 if curly else 12):
            t=i*TAU/(18 if curly else 12);x=.39*math.cos(t);z=.32*math.sin(t)+.08
            y=cy+.24 if bob else cy+.38
            if curly:a.sphere('Soft grey curl',(.20,.19,.19),(x,y+rng.uniform(-.08,.08),z),hair,10,5)
            else:
                end_y=cy-.22 if bob and z>-.12 else cy+.12
                a.tube('Combed hair lock',[(x*.6,cy+.49,z*.5),(x,cy+.3,z),(x*.97,end_y,z)],.045,hair,8,curve=True)
        if hat:
            a.lathe('Woven sun hat brim',[(0,.05),(.015,.68),(.045,.70),(.075,.56),(.10,.36)],(0,cy+.47,.02),'canvas',segments=40)
            a.lathe('Straw hat crown',[(0,.34),(.20,.31),(.26,.25),(.28,.04)],(0,cy+.54,.02),'canvas',segments=32)
            a.lathe('Red hat ribbon',[(0,.347),(.065,.338)],(0,cy+.56,.02),'red',segments=40)
            for k in range(8):a.ring('Woven straw concentric braid',(0,cy+.49+k*.004,.02),.39+k*.035,thick=.006,color='wood_light',n=40,sides=4)
        if hair=='silver_hair' and not bob and not curly:a.sphere('Low silver bun',(.40,.39,.35),(0,cy-.08,.39),hair,20,10)

def character(name):
    a=Asset(name);sitting='Sitting' in name;june='June' in name;gloria='Gloria' in name;chad='Chad' in name;sam='Sam' in name;casual='Casual' in name;edna='Edna' in name;judge='Judge' in name
    skin='skin_warm' if edna or sam else 'skin_deep' if name=='NPC_Judge2' else 'skin'
    top='sage' if june else 'lavender' if gloria else 'polo_purple' if chad or sam and not casual else 'shirt_green' if casual else 'cream' if edna else 'shirt_blue'
    pants='khaki' if june or chad or sam and not casual else 'blue' if casual else 'white' if gloria else 'darkgray'
    hip_y=1.95 if sitting else 2.30;torso_top=3.0 if sitting else 3.92;cy=3.47 if sitting else 4.53
    if name=='NPC_Judge1':cy-=.20;torso_top-=.15
    # Grounded shoes with distinct soles, vamp, heel and laces.
    for side in [-1,1]:
        x=side*.31;foot_z=-2.0 if sitting else -.18
        a.box('Rubber shoe sole',(.47,.13,.78),(x,.065,foot_z),'rubber',.055,segments=3)
        a.sphere('Shaped shoe upper',(.45,.27,.70),(x,.21,foot_z),'sage' if june else 'white' if chad or sam else skin if edna else 'wood_dark',20,9)
        if edna:
            for zz in [foot_z-.16,foot_z+.10]:a.bar('Comfort sandal leather strap',(x-.19,.30,zz),(x+.19,.30,zz),.036,'wood_dark',10)
        if gloria:a.box('Kitten heel',(.22,.16,.18),(x,.10,foot_z+.25),'black',.02)
        if chad or sam:
            for k in range(3):a.bar('White shoelace',(x-.10,.31,foot_z-.12+k*.07),(x+.10,.31,foot_z-.12+k*.07),.012,'cream',8)
        knee=(x,1.05,-.95 if sitting else -.05)
        ankle=(x,.30,foot_z+.1);hip=(side*.30,hip_y,.35 if sitting else .02)
        shorts=chad or sam and not casual
        if shorts:
            limb(a,'Pressed shorts leg',[(x,1.55,-.02),hip],[.22,.27],pants,24)
            limb(a,'Bare calf',[ankle,knee,(x,1.55,-.02)],[.13,.16,.18],skin,20)
            a.ring('Pressed shorts hem',(x,1.55,-.02),.22,thick=.025,color='khaki',n=24,sides=6)
        else:limb(a,'Calf beneath sundress' if edna else 'Trouser leg with bent knee',[ankle,knee,hip],[.15,.18,.24] if edna else [.16,.22,.27],skin if edna else pants,24)
        if not shorts and not edna:
            for k in range(3):a.tube('Trouser knee fold',[(x-.14,knee[1]+k*.05,knee[2]-.17),(x,knee[1]-.025+k*.05,knee[2]-.23),(x+.13,knee[1]+k*.05,knee[2]-.17)],.012,pants,8,curve=True)
    body_z=.26 if sitting else 0
    rings=[]
    for i in range(12):
        t=i/11;y=hip_y-.06+t*(torso_top-hip_y)
        width=.47+(.13*math.sin(t*math.pi))-(.08 if t>.9 else 0)
        if edna:width+=.13
        rings.append((0,y,body_z,width,.28+.035*math.sin(t*math.pi)))
    loft(a,'Tailored cardigan or polo',rings,top,40)
    a.bar('Neck inset beneath the collar',(0,torso_top-.48,body_z),(0,cy-.37,0),.18,skin,24)
    if june or gloria:
        a.box('Blouse visible between cardigan',(.25,1.20,.035),(0,torso_top-.65,body_z-.31),'cream',.025)
        for side in [-1,1]:
            a.tube('Cardigan bound edge',[(side*.16,hip_y,body_z-.30),(side*.14,torso_top-.25,body_z-.31),(side*.22,torso_top,body_z-.21)],.024,top,10,curve=True)
        for k in range(5):a.sphere('Cardigan button',(.044,.044,.02),(.15,hip_y+.18+k*.23,body_z-.34),'wood_dark',8,4)
    else:
        for side in [-1,1]:a.profile('Folded shirt collar',[(0,0),(.23,0),(.12,.25)],.018,(side*.13,torso_top-.05,body_z-.26),top,R(x=90,z=side*13))
    # Sleeves and forearms meet with cuffs and posed, separate fingers.
    left_hand=(-.64,2.45,-.58);right_hand=(.65,2.38,-.50)
    if june and not sitting:left_hand=(-.37,2.85,-.63);right_hand=(.40,2.85,-.63)
    if sitting:left_hand=(-1.10,2.65,-.65);right_hand=(1.0,2.48,-.88)
    if gloria:left_hand=(-.37,2.75,-.45);right_hand=(.38,2.56,-.55)
    if chad:right_hand=(.76,3.60,-.40)
    if edna:right_hand=(.88,3.96,-.1)
    if sam:left_hand=(-.42,2.35,-.22);right_hand=(.42,2.35,-.22)
    if judge:left_hand=(-.48,2.85,-.6);right_hand=(.45,3.02,-.75)
    for side,p in [(-1,left_hand),(1,right_hand)]:
        shoulder=(side*.51,torso_top-.16,body_z);elbow=(side*.68,(torso_top+p[1])/2-.16,p[2]*.35)
        sleeve_end=mix(elbow,p,.18 if chad or sam else .78)
        limb(a,'Cloth sleeve folds',[shoulder,elbow,sleeve_end],[.22,.17,.145],top,20)
        limb(a,'Exposed forearm',[sleeve_end,mix(sleeve_end,p,.7),p],[.14,.115,.10],skin,16)
        if sam and not casual:
            a.tube('Pocket opening around tucked hand',[(side*.28,2.47,-.29),(side*.43,2.40,-.28),(side*.53,2.49,-.23)],.022,'khaki',10,curve=True)
        else:hand(a,p,skin,'up' if edna and side==1 else 'relaxed')
        for k in range(2):a.tube('Sleeve compression fold',[(elbow[0]-.1,elbow[1]+k*.06,elbow[2]-.13),(elbow[0],elbow[1]-.03+k*.06,elbow[2]-.17),(elbow[0]+.09,elbow[1]+k*.06,elbow[2]-.13)],.013,top,8,curve=True)
    if june:
        if sitting:mug(a,(-1.10,2.65,-.67))
        else:
            for side in [-1,1]:
                a.ring('Shears oval grip',(side*.17,2.88,-.80),.12,.19,.035,'xy','rust',24,8)
                a.profile('Old shear blade',[(0,0),(.08,.42),(.02,.60),(-.035,.12)],.025,(side*.12,3.05,-.84),'rust',R(x=90,z=side*22))
            a.sphere('Shears pivot screw',(.08,.08,.05),(0,3.03,-.86),'steel',12,6)
    if gloria:mug(a,(.15,2.73,-.65),True)
    if edna:
        mug(a,(-.64,2.45,-.58))
        loft(a,'Floral sundress skirt',[(0,.55,0,.74,.53),(0,1,0,.73,.51),(0,1.7,0,.69,.48),(0,2.4,0,.65,.46)],'cream',32)
        for i in range(28):
            t=i*2.399;y=.75+(i%6)*.24;rx=.74-(y-.55)*.09/1.85;rz=.53-(y-.55)*.07/1.85
            p=Vector((rx*math.cos(t),y,rz*math.sin(t)));normal=Vector((math.cos(t)/rx,0,math.sin(t)/rz)).normalized()
            rot=Vector((0,0,1)).rotation_difference(normal).to_matrix()
            for petal in range(5):
                angle=petal*TAU/5;offset=rot@Vector((.027*math.cos(angle),.027*math.sin(angle),.006))
                a.sphere('Sundress flower petal',(.043,.043,.035),p+offset,'rose',8,4)
    if chad or sam and not casual:
        crown(a,(-.22,torso_top-.43,-.312),.23)
        with a.moving(a.name+'__Head',(0,cy-.46,0),'head'):
            a.box('Visor brim',(.78,.065,.44),(0,cy+.46,-.35),'gold',.08)
            a.ring('Visor head band',(0,cy+.43,0),.43,.36,.045,'xz','gold',32,8)
    if chad:
        a.box('Clipboard under arm',(.58,.82,.065),(-.60,2.9,.09),'wood_light',.025,R(z=-14))
        a.box('Blank clipboard paper',(.48,.65,.015),(-.60,2.91,.045),'paper',.015,R(z=-14))
        # Real thumbs-up silhouette, beyond the folded fingers.
        limb(a,'Raised thumb',[(.63,3.62,-.42),(.65,3.90,-.42),(.66,4.02,-.44)],[.06,.055,.04],skin,12)
    if casual:
        for x in [-.31,.31]:a.sphere('Grass stain on jeans',(.21,.16,.035),(x,1.13,-.27),'leaf',12,6)
        for i in range(2):
            a.sphere('Work glove held in hand',(.20,.29,.10),(-.42+i*.13,2.12,-.30),'canvas',16,6)
    if judge:
        a.box('Judging clipboard',(.60,.84,.06),(-.29,2.83,-.73),'wood_light',.02,R(x=-12))
        a.box('Blank paper',(.50,.70,.012),(-.29,2.85,-.77),'paper',.01,R(x=-12))
        a.bar('Judging pencil',(.44,3.02,-.83),(.14,2.86,-.85),.018,'yellow',8)
        if name=='NPC_Judge1':
            a.ring('Magnifying glass rim',(.46,3.12,-.85),.16,thick=.022,plane='xy',color='steel',n=32,sides=8)
            a.bar('Magnifier handle',(.46,2.79,-.85),(.46,2.98,-.85),.04,'wood_dark',12)
            for x in [-.1,.1]:a.profile('Bow-tie silk wing',[(0,0),(.15,.10),(.15,-.10)],.06,(x,torso_top-.18,-.29),'turf_purple',R(x=90,z=180 if x<0 else 0))
        else:
            a.tube('Lanyard',[(-.17,torso_top-.06,-.27),(0,3.18,-.40),(.17,torso_top-.06,-.27)],.018,'turf_purple',8)
            a.box('Blank lanyard badge',(.25,.34,.025),(0,3.08,-.41),'paper',.02)
    hair='silver_hair' if june or edna or judge else 'blonde' if gloria else 'hair_dark'
    mood='unimpressed' if sitting else 'smug' if gloria else 'fedup' if sam and not casual else 'fussy' if judge else 'happy' if edna else 'grin' if chad or casual else 'proud'
    face(a,cy,skin,hair,mood,june or name=='NPC_Judge2',june,gloria,edna,sam or chad)
    if chad:
        with a.moving(a.name+'__Head',(0,cy-.46,0),'head'):
            for x in [-.22,.22]:a.sphere('Wraparound sunglasses pushed onto visor',(.34,.15,.08),(x,cy+.50,-.39),'black',20,8)
            a.bar('Sunglasses bridge',(-.08,cy+.50,-.43),(.08,cy+.50,-.43),.018,'steel_dark',8)
    if name=='NPC_Judge2':
        with a.moving(a.name+'__Head',(0,cy-.46,0),'head'):
            for i in range(7):
                t=i*TAU/7;a.sphere('Big hat flower petal',(.19,.19,.10),(.40+.11*math.cos(t),cy+.56+.11*math.sin(t),-.35),'rose',12,6)
            a.sphere('Hat flower centre',(.13,.13,.08),(.40,cy+.56,-.40),'yellow',12,6)
    if gloria:
        with a.moving(a.name+'__Head',(0,cy-.46,0),'head'):
            for x in [-.44,.44]:a.sphere('Pearl earring',(.08,.10,.08),(x,cy-.16,-.02),'cream',12,6)
    marker(a,'Head',(0,cy+.1,-.46),a.name+'__Head');marker(a,'Talk',(0,3.1 if not sitting else 2.6,-1.0))
    if sitting:
        a.keep_authored_size=True;a.feature('shares_ground_origin_with','PorchRockingChair');a.feature('seated_pose_authored_without_recentering',1)
    a.feature('clothed_static_pose');a.feature('individual_fingers');a.feature('separate_neck_pivot_head');a.feature('expression',mood)
    return a

def rocker():
    a=Asset('PorchRockingChair')
    for x in [-.9,.9]:
        pts=[(x,.06+(.18*(t/1.5)**2),t) for t in [-1.5,-1.2,-.8,0,.8,1.2,1.5]]
        a.tube('Curved wooden rocker runner',pts,.075,'white',16,curve=True)
        for z in [-.75,.6]:a.bar('Turned chair leg',(x,.13,z),(x,1.55,z),.075,'white',16)
        a.bar('Arm support',(x,1.5,-.72),(x,2.3,-.72),.06,'white',16)
        a.box('Rounded arm rest',(.22,.13,2.2),(x,2.33,.1),'white',.065)
    for i in range(7):a.box('Seat plank',(1.85,.09,.25),(0,1.53,-.8+i*.26),'white',.035)
    a.box('Faded cushion',(1.68,.20,1.65),(0,1.69,0),'cream',.10,segments=3)
    for x in [-.9,.9]:a.bar('Back upright',(x,1.5,.80),(x,3.85,1.18),.09,'white',20)
    for i in range(9):
        x=-.72+i*.18;a.lathe('Turned spindle',[(0,.035),(.15,.055),(.35,.035),(.65,.06),(.9,.035),(1.4,.04)],(x,2.05,.99),'white',segments=16)
    for y in [2.0,3.55,3.88]:a.box('Back rail',(2.0,.15,.18),(0,y,1.13),'white',.06)
    for x in [-.6,0,.6]:
        for z in [-.55,0,.55]:a.sphere('Faded cushion flower',(.12,.014,.12),(x,1.80,z),'rose',12,5)
    marker(a,'Seat',(0,1.8,0));return a

def porch():
    a=Asset('PorchDeck')
    with a.moving(a.name+'__Deck',(0,0,0),'collision_floor'):
        a.box('Structural deck',(10,.25,6),(0,1.475,1),'wood',.03)
    for i in range(25):a.box('Individual weathered porch board',(.38,.07,6),( -4.8+i*.4,1.565,1),'wood_light' if i%3 else 'wood',.015)
    for i in range(3):
        with a.moving(a.name+'__Step'+str(i),(0,0,0),'collision_step'):
            a.box('Solid safe step',(4.0,(i+1)*.53,.68),(0,(i+1)*.265,-3.66+i*.67),'wood_light',.03)
    for x in [-4.8,4.8]:
        for z in [-1.8,3.8]:a.box('Square railing post',(.20,2.8,.2),(x,3,z),'white',.02)
        a.box('Side handrail',(.22,.17,5.8),(x,4.25,1),'white',.035)
        for j in range(14):a.box('Low-poly side baluster',(.07,2.32,.07),(x,2.96,-1.6+j*.4),'white',0)
    a.box('Back handrail',(9.6,.17,.22),(0,4.25,3.8),'white',.035)
    for j in range(24):a.box('Back baluster',(.07,2.32,.07),(-4.6+j*.4,2.96,3.8),'white',0)
    a.lathe('Terracotta geranium pot',[(0,.35),(.55,.48),(.60,.50),(.65,.42)],(3.8,1.60,2.7),'orange',segments=28)
    for i in range(9):
        t=i*2.4;x=3.8+.3*math.cos(t);z=2.7+.3*math.sin(t)
        a.bar('Geranium stem',(3.8,2.18,2.7),(x,2.83,z),.025,'leaf',8)
        for k in range(5):a.sphere('Geranium red petal',(.14,.11,.14),(x+.08*math.cos(k*TAU/5),2.83,z+.08*math.sin(k*TAU/5)),'red',8,4)
    marker(a,'ChairSpot',(-1,1.60,1));return a

def house():
    a=Asset('GloriaHouse');a.current=a.part(a.name+'__Body')
    a.box('Two-storey colonial',(27,22,24),(5,11.5,4),'house_blue',.08)
    a.box('Garage wing',(15,11,25),(-15,5.7,3),'house_blue',.06)
    for front_z,w,x,h in [(-8.1,27,5,22),(-9.6,15,-15,11),(16.1,27,5,22)]:
        for j in range(int(h/.4)):a.box('Individual horizontal siding course',(w,.35,.09),(x,.7+j*.4,front_z),'house_blue',0)
    def roof(w,d,pos,eave,rise):
        x,y,z=pos;length=math.hypot(w/2,rise);angle=math.degrees(math.atan2(rise,w/2))
        for side in [-1,1]:
            rot=R(z=-side*angle);center=Vector((x+side*w/4,eave+rise/2,z))
            a.box('Roof slope',(length+.4,.22,d),center,'roof',.02,rot)
            for j in range(9):
                for k in range(20):
                    p=rot@Vector((-length/2+(j+.5)*length/9,.14,-d/2+(k+.5)*d/20))+center
                    a.box('Shingle course',(length/9+.07,.025,d/20-.03),p,'roof',0,rot)
        for zz in [z-d/2,z+d/2]:
            for side in [-1,1]:a.bar('White gable fascia',(x+side*w/2,eave,zz),(x,eave+rise,zz),.10,'white',10)
    roof(29,26,(5,0,4),23,6);roof(17,27,(-15,0,3),11.4,4)
    for x,w,depth,z,eave,rise in [(5,29,26,4,23,6),(-15,17,27,3,11.4,4)]:
        for side in [-1,1]:
            end=z+side*depth/2
            a.profile('Closed colonial gable',[(-w/2,0),(w/2,0),(0,-rise)],.16,(x,eave,end),'house_blue',R(x=90))
            a.box('Eave frieze joins wall to gable',(w,.65,1.0),(x,eave-.2,end-side*.45),'white',.02)
    def window(x,y,z,w=3.6,h=5):
        a.box('Window recess',(w+.2,h+.2,.16),(x,y,z),'black',.02)
        with a.moving(a.name+'__Windows',role='glass'):a.box('Window glass',(w-.2,h-.2,.035),(x,y,z-.11),'glass',.01)
        for xx in [x-w/2,x+w/2]:
            a.box('White window casing',(.16,h+.3,.2),(xx,y,z-.16),'white',.02)
            a.box('Black shutter',(.9,h,.16),(xx+(-.6 if xx<x else .6),y,z),'black',.025)
            for j in range(10):a.box('Shutter louver',(.7,.06,.05),(xx+(-.6 if xx<x else .6),y-h/2+.3+j*.45,z-.10),'darkgray',0)
        for yy in [y-h/2,y,y+h/2]:a.box('Window cross rail',(w,.12,.2),(x,yy,z-.17),'white',.01)
        a.box('Window central mullion',(.10,h,.12),(x,y,z-.20),'white',.01)
    for x in [-3,5,13]:window(x,17.8,-8.25)
    for x in [-3,13]:window(x,6.4,-8.25)
    a.box('Lavender front door',(3.3,7.2,.2),(5,4.3,-8.3),'lavender',.04)
    for y in [2.1,4.8]:a.box('Raised door panel',(2.7,2.1,.05),(5,y,-8.43),'lavender',.05)
    a.sphere('Brass doorknob',(.18,.18,.18),(6.1,4.1,-8.55),'gold',16,8)
    a.box('Porch deck',(26,.65,6.6),(5,.5,-11.0),'white',.025)
    for x in [-7,1,9,17]:
        a.bar('Porch column',(x,.85,-13),(x,10,-13),.20,'white',24)
        for y in [1,9.7]:a.box('Column capital',(.65,.28,.65),(x,y,-13),'white',.025)
    a.box('Covered porch roof',(27,.3,7),(5,10.1,-11),'roof',.04)
    # A projecting bay with glazing on three faces.
    a.box('Bay window base',(5.3,1.2,2.2),(13,1.6,-9),'white',.04)
    window(13,5.0,-10.0,4.2,4.5)
    for x in [10.35,15.65]:
        with a.moving(a.name+'__Windows',role='glass'):a.box('Bay return-side glazing',(.035,4.5,1.8),(x,5,-9.0),'glass',.01)
        for y in [2.7,5,7.3]:a.box('Bay return white cross rail',(.16,.12,2.0),(x,y,-9.0),'white',.015)
        for z in [-9.95,-8.05]:a.box('Bay return corner casing',(.16,4.7,.14),(x,5,z),'white',.015)
    for x in [-18.3,-11.7]:
        a.box('Garage door',(5.8,8.3,.18),(x,4.6,-9.7),'white',.03)
        for j in range(5):
            a.box('Garage panel groove',(5.6,.04,.025),(x,1.4+j*1.5,-9.81),'gray',0)
            for xx in [x-1.4,x+1.4]:a.box('Garage raised panel',(2.5,1.0,.035),(xx,1.9+j*1.5,-9.82),'cream',.025)
    # Drive on the -X side, kept inside the house's requested total footprint.
    a.box('Left paved driveway',(15,.12,10),(-15,.06,-14),'stone',.02)
    a.box('Porch approach path',(3,.14,5),(5,.07,-16.5),'stone',.02)
    for i in range(2):a.box('Colonial porch step',(5,(i+1)*.40,.72),(5,(i+1)*.20,-14.55+i*.70),'white',.025)
    marker(a,'Porch',(5,.85,-11));marker(a,'Driveway',(-15,.16,-29));return a

def turf_sign(a,p=(0,0,0),scale=1):
    x,y,z=p
    for side in [-1,1]:a.bar('Wire sign stake',(x+side*.52*scale,y,z),(x+side*.52*scale,y+1.75*scale,z),.018*scale,'steel',8)
    a.box('Purple lawn sign',(1.6*scale,.80*scale,.07*scale),(x,y+1.55*scale,z),'turf_purple',.03*scale)
    crown(a,(x,y+1.55*scale,z-.05*scale),.85*scale)

def yard(stage):
    a=Asset('GloriaYard_Stage'+str(stage));a.keep_authored_size=True
    h=ASSETS['GloriaHouse'];low,high=h.bounds();sx=44/(high.x-low.x)
    fitted_x=lambda x:-22+(x-low.x)*sx
    walk_x=fitted_x(5);drive_x=fitted_x(-15);drive_width=15*sx;drive_edge=drive_x+drive_width/2
    beds=[(drive_edge+.4,walk_x-2.0),(walk_x+2.0,21.3)]
    with a.moving(a.name+'__Lawn',role='lawn'):
        a.box('Shared turf footprint',(44,.12,30),(0,.06,-33),'leaf',0)
        count=14 if stage<3 else 16
        for i in range(0 if stage==2 else count):
            col='leaf_light' if i%2 else 'leaf'
            if stage==1:col='leaf'
            a.box('Diagonal stripe' if stage==2 else 'Lawn checker pass',(44/count,.012,30),(-22+(i+.5)*44/count,.127,-33),col,0)
            if stage==3:
                for j in range(10):a.box('Checkerboard stripe intersection',(44/count-.01,.008,3),(-22+(i+.5)*44/count,.139,-46.5+j*3),'leaf_light' if (i+j)%2 else 'leaf',0)
        if stage==2:
            def clip(poly,cut,greater):
                result=[]
                for u,v in zip(poly,poly[1:]+poly[:1]):
                    du=u[0]+u[1]-cut;dv=v[0]+v[1]-cut;inside_u=du>=-1e-8 if greater else du<=1e-8;inside_v=dv>=-1e-8 if greater else dv<=1e-8
                    if inside_u:result.append(u)
                    if inside_u!=inside_v:
                        t=du/(du-dv);result.append((u[0]+(v[0]-u[0])*t,u[1]+(v[1]-u[1])*t))
                return result
            for i in range(30):
                low=-70+i*2.5;poly=[(-22,-48),(22,-48),(22,-18),(-22,-18)]
                poly=clip(clip(poly,low,True),low+2.5,False)
                if len(poly)>2:a.mesh('Clipped diagonal mowing stripe',[(x,.14,z) for x,z in poly],[tuple(range(len(poly)))],'leaf_light' if i%2 else 'leaf',False)
    a.box('Front walk aligns with house porch',(3,.12,30),(walk_x,.11,-33),'stone',0)
    a.box('Driveway continues to the street',(drive_width,.12,30),(drive_x,.10,-33),'stone',0)
    for left,right in beds:a.box('Fresh black mulch bed',(right-left,.10,6.2),((left+right)/2,.15,-21.4),'soil' if stage==1 else 'mulch_black',0)
    for i in range(12):
        x=drive_edge+1.35+i*2.3
        if x>20.8 or abs(x-walk_x)<2.6:continue
        a.box('Hedge clipped block' if stage>1 else 'Uneven hedge',(1.95,1.5+(i%3)*(.15 if stage==1 else 0),1.5),(x,1.0,-20),'leaf',.18,segments=2)
        for j in range(10):
            t=j*2.4;a.sphere('Hedge leaf cluster',(.32,.35,.31),(x+.67*math.cos(t),1.3+.4*math.sin(t*2),-20+.53*math.sin(t)),'leaf_light' if j%3==0 else 'leaf',8,4)
    if stage==1:
        rng=random.Random(37)
        for i in range(110):
            x=rng.uniform(-21,21);z=rng.uniform(-47,-23)
            if x<drive_edge+.2 or abs(x-walk_x)<1.7:continue
            a.bar('Long grass tuft',(x,.15,z),(x+.1,.55,z+.05),.018,'leaf_light',5)
            if i%5==0:a.sphere('Dandelion head',(.15,.09,.15),(x,.49,z),'yellow',8,4)
    if stage>1:turf_sign(a,(walk_x-2.5,0,-44))
    for left,right in beds:
        count=6 if stage==1 else 9 if stage==2 else 14
        for i in range(count):
            x=left+.6+(right-left-1.2)*i/(count-1);y=.4;z=-23.4
            a.bar('Rose or flower stem',(x,.2,z),(x,y+.3,z),.022,'leaf',6)
            for j in range(5):a.sphere('Rose petals',(.14,.13,.14),(x+.07*math.cos(j*1.26),y+.3,z+.07*math.sin(j*1.26)),'rose',8,4)
    if stage==3:
        for x,z in [(walk_x-4,-25),(walk_x+4,-25),(walk_x-4,-32),(walk_x+4,-32)]:
            a.lathe('Formal topiary planter',[(0,.6),(.6,.8),(.8,.85)],(x,.2,z),'white',segments=20)
            a.bar('Topiary trunk',(x,1,z),(x,2.4,z),.09,'wood',10)
            a.sphere('Clipped topiary ball',(1.7,1.7,1.7),(x,2.8,z),'leaf',20,10)
        for z in [-28,-32,-36,-40,-44]:
            for x in [walk_x-2.1,walk_x+2.1]:
                a.bar('Solar path light stem',(x,.15,z),(x,.85,z),.04,'steel_dark',8)
                a.box('Solar lamp cap',(.35,.08,.35),(x,.95,z),'black',.02)
                a.box('Lamp lens',(.22,.18,.22),(x,.83,z),'cream',.02)
        for i in range(5):
            x=-3+i*1.7;z=-43
            for dx in [-.12,.12]:a.bar('Flamingo leg',(x+dx,.2,z),(x+dx,1.25,z),.025,'rose',6)
            a.sphere('Flamingo body',(.65,.55,1.0),(x,1.4,z),'pink',12,6)
            a.tube('Flamingo S neck',[(x,1.5,z-.3),(x,1.9,z-.55),(x,2.3,z-.4),(x,2.25,z-.7)],.065,'pink',10,curve=True)
            a.sphere('Flamingo beak',(.15,.10,.25),(x,2.22,z-.81),'black',10,5)
        a.lathe('Tiered contest fountain',[(0,1.9),(.25,2.0),(.45,1.8),(.55,.35),(1.9,.25),(2.0,1.2),(2.2,1.3),(2.4,.25),(3.6,.20),(3.7,.65),(3.9,.7),(4.1,.1)],(-.5,.17,-35),'stone',segments=32)
        a.lathe('Still fountain water',[(0,1.75),(.01,1.75)],(-.5,.56,-35),'blue',segments=32)
    a.feature('shared_footprint_origin','GloriaHouse ground origin; yard occupies Z -48 to -18')
    a.feature('layout',dict(walk_x=walk_x,walk_width=3,drive_x=drive_x,drive_width=drive_width,drive_z=[-48,-8],beds=beds))
    return a

def trophy():
    a=Asset('BestYardTrophy')
    for i in range(14):
        t=i*TAU/14;a.bar('Real turf skirt',(math.cos(t)*1.05,0,math.sin(t)*1.05),(math.cos(t)*1.13,.30,math.sin(t)*1.13),.035,'leaf',6)
    for x in [-.8,.8]:
        for z in [-.8,.8]:a.box('White display stand leg',(.18,1.65,.18),(x,.86,z),'white',.02)
    a.box('Display stand top',(2.1,.18,2.1),(0,1.75,0),'white',.05)
    for y,size,col in [(1.94,1.75,'wood_dark'),(2.12,1.52,'marble'),(2.30,1.30,'marble')]:a.box('Stepped plinth',(size,.18,size),(0,y,0),col,.045)
    a.box('Blank brass trophy plaque',(.84,.22,.025),(0,2.14,-.78),'gold',.025)
    with a.moving(a.name+'__Cup',(0,2.4,0),'cup'):
        a.lathe('Gold loving cup and stem',[(0,.48),(.13,.50),(.22,.25),(.70,.19),(.85,.62),(1.0,.83),(1.55,.97),(1.72,1.0),(1.77,.93),(1.55,.88),(1.0,.72),(.9,.2)],(0,2.4,0),'gold',segments=48)
        for side in [-1,1]:a.tube('Swept trophy handle',[(side*.78,3.9,0),(side*1.24,4.0,0),(side*1.28,3.5,0),(side*.75,3.18,0)],.085,'gold',16,curve=True)
        a.lathe('Trophy lid',[(0,.97),(.14,.80),(.25,.42),(.3,.1)],(0,4.17,0),'gold',segments=48)
        for i in range(24):
            t=i*TAU/24;x=.91*math.cos(t);z=.91*math.sin(t)
            a.bar('Engraved lawn stripe',(x,3.55,z),(x*.98,3.78,z*.98),.012,'crown_gold',6)
        for i in [-1,0,1]:a.tube('Raised grass tuft engraving',[(i*.07,3.45,-.92),(i*.11,3.69,-.94),(i*.15,3.84,-.91)],.018,'crown_gold',8)
        a.box('Miniature mower on lid',(.65,.14,.80),(0,4.67,0),'gold',.06)
        for x in [-.35,.35]:
            for z in [-.23,.23]:a.bar('Miniature mower wheel',(x-.05,4.63,z),(x+.05,4.63,z),.12,'gold',16)
        a.tube('Miniature mower handle',[(-.25,4.7,.25),(-.25,5.25,.5),(.25,5.25,.5),(.25,4.7,.25)],.035,'gold',12)
    return a

def junk(name):
    a=Asset(name)
    if name=='DebrisStick':
        a.tube('Crooked bark stick',[(-1.2,.13,-.1),(-.6,.17,.05),(.1,.12,0),(.7,.17,.1),(1.2,.14,.05)],.09,'wood_dark',14,curve=True)
        a.tube('Short side twig',[(.2,.13,0),(.45,.22,.3),(.65,.19,.52)],.045,'wood',10,curve=True)
        for i in range(12):a.bar('Raised bark groove',(-1+i*.18,.20,-.03),(-.88+i*.18,.20,.04),.013,'wood',6)
    elif name=='DebrisRock':
        a.sphere('Weathered field stone',(.8,.5,.65),(0,.25,0),'stone',24,12)
        for i in range(10):
            x=-.20+i*.035;z=.08+(.05 if i%2 else 0);y=.25+.25*math.sqrt(1-(x/.4)**2-(z/.325)**2)
            normal=Vector((x/.4**2,(y-.25)/.25**2,z/.325**2)).normalized();rotation=Vector((0,1,0)).rotation_difference(normal).to_matrix();centre=Vector((x,y,z))-normal*.009
            start=len(a.current.verts);a.sphere('Conforming moss patch',(.16,.035,.15),(0,0,0),'leaf',10,4)
            for j in range(start,len(a.current.verts)):a.current.verts[j]=rotation@a.current.verts[j]+centre
    elif name=='DebrisDogBall':
        a.sphere('Fuzzy tennis ball',(.55,.55,.55),(0,.275,0),'tennis_felt',24,12)
        for i,v in enumerate(a.current.verts):
            delta=(v-Vector((.18,.36,.18))).length
            depth=.018*math.exp(-delta*delta/.004)
            a.current.verts[i]=v-(v-Vector((0,.275,0))).normalized()*depth
        a.ring('Curved tennis seam',(0,.275,0),.269,thick=.012,plane='xy',color='cream',n=40,sides=6)
        for i in range(12):
            t=i*2.4;x=.20*math.cos(t);y=.16*math.sin(t);z=-math.sqrt(.275**2-x*x-y*y);normal=Vector((x,y,z)).normalized()
            centre=Vector((0,.275,0))+normal*(.275-.004);rotation=Vector((0,0,1)).rotation_difference(normal).to_matrix()
            start=len(a.current.verts);a.sphere('Mud stain conforms to felt',(.07,.04,.018),(0,0,0),'soil',8,4)
            for j in range(start,len(a.current.verts)):a.current.verts[j]=rotation@a.current.verts[j]+centre
    elif name=='DebrisToyTruck':
        a.box('Yellow plastic cab',(.56,.4,.39),(0,.32,-.29),'yellow',.07)
        a.box('Toy windshield',(.38,.12,.02),(0,.40,-.49),'blue',.025)
        a.box('Red dump-bed floor',(.6,.08,.65),(0,.31,.17),'red',.025)
        for x in [-.28,.28]:a.box('Dump bed side',(.07,.22,.65),(x,.44,.17),'red',.02)
        a.box('Dump bed tailgate',(.6,.22,.07),(0,.44,.49),'red',.02)
        for x in [-.29,.29]:
            for z in [-.31,.32]:a.bar('Toy truck wheel',(x-.05,.14,z),(x+.05,.14,z),.13,'black',20)
    else:
        a.lathe('Dish-shaped scuffed frisbee',[(0,.42),(.045,.50),(.11,.5),(.16,.45),(.16,.41),(.08,.36),(.07,.02)],(0,0,0),'orange',segments=48)
        for i in range(8):
            t=i*TAU/8;a.bar('Frisbee pale scuff',(.33*math.cos(t),.158,.33*math.sin(t)),(.41*math.cos(t+.07),.158,.41*math.sin(t+.07)),.006,'canvas',6)
    return a

def truck():
    # Purpose-built crew truck; every wheel is a separate authored pivot.
    a=Asset('TurfKingTruck')
    a.box('Chassis rails',(6.5,.35,18),(0,1.9,0),'black',.03)
    a.box('Crew cab body',(7.7,3.6,8.2),(0,4.2,-3),'turf_purple',.20,segments=3)
    a.box('Long bonnet',(7.8,1.7,4.5),(0,3.3,-8),'turf_purple',.16,segments=3)
    a.box('Cab roof',(7.8,.18,7.7),(0,6.15,-2.8),'turf_purple',.10)
    with a.moving(a.name+'__Glass',role='glass'):
        a.box('Wide windshield',(6.8,1.7,.05),(0,5.1,-7.11),'glass',.05,R(x=12))
        for x in [-3.88,3.88]:
            for z in [-4.7,-1.5]:a.box('Crew side window',(.04,1.6,2.85),(x,5.15,z),'glass',.035)
    for side in [-1,1]:
        x=side*3.96
        a.box('Continuous gold belt stripe',(.04,.24,16),(x,3.38,-1.6),'gold',.01)
        for z in [-4.7,-1.5]:
            a.box('Door handle',(.10,.13,.57),(x,4.13,z),'chrome',.035)
            # Crown faces outward on each door.
            outline=[(-.5,-.3),(.5,-.3),(.5,.3),(.22,.05),(0,.45),(-.22,.05),(-.5,.3)]
            a.profile('Gold door crown',outline,.03,(x,3.7,z),'gold',Matrix(((0,1,0),(0,0,1),(1,0,0))))
        a.box('Mirror arm',(.55,.10,.12),(side*4.08,4.7,-6.2),'chrome',.025)
        a.box('Mirror housing',(.25,.52,.72),(side*4.35,4.8,-6.2),'turf_purple',.07)
    a.box('Open bed floor',(7.6,.18,8.9),(0,2.8,6.0),'darkgray',.02)
    for side in [-1,1]:
        a.box('Bed side panel',(.24,1.7,9),(side*3.85,3.56,6),'turf_purple',.06)
        a.box('Gold bed stripe',(.035,.24,8.6),(side*3.98,3.38,6),'gold',.01)
    a.box('Closed ramp tailgate',(7.7,1.8,.18),(0,3.65,10.55),'turf_purple',.04)
    crown(a,(0,3.65,10.66),1.2)
    for x in [-3.4,3.4]:
        for z in [-10.3,10.7]:a.box('Chrome bumper corner',(1.0,.6,.42),(x,2.2,z),'chrome',.07)
        a.box('Headlight',(1.3,.6,.1),(x*.8,3.4,-10.3),'cream',.04)
    a.box('Front grille',(4.6,1.1,.16),(0,3.0,-10.3),'black',.04)
    for x in [-1.8,-1.2,-.6,0,.6,1.2,1.8]:a.box('Chrome grille bar',(.10,.9,.08),(x,3,-10.42),'chrome',.01)
    for side in [-1,1]:
        for z,tag in [(-7,'F'),(7,'R')]:a.wheel(a.name+'__Wheel'+tag+('L' if side<0 else 'R'),(side*3.7,1.35,z),2.7,.64,rim='chrome',tread=False)
        for z in [1.6,9.8]:a.bar('Ladder rack upright',(side*3.4,3.4,z),(side*3.4,8.4,z),.10,'steel',12)
    for z in [1.6,9.8]:a.bar('Ladder rack crossbar',(-3.6,8.4,z),(3.6,8.4,z),.10,'steel',12)
    with a.moving(a.name+'__LightBar',(0,6.45,-3),'lightbar'):
        a.box('Light bar base',(4.8,.15,.7),(0,6.4,-3),'black',.04)
        for i in range(12):a.box('Amber light segment',(.32,.24,.58),(-2.14+i*.39,6.6,-3),'amber',.04)
    marker(a,'Light',(0,6.7,-3),a.name+'__LightBar')
    # Compact strapped zero-turn machine in the open bed, not another library model.
    a.box('Zero-turn mower deck',(5.5,.32,3.7),(0,3.2,6),'green',.15)
    a.box('Zero-turn chassis',(3.6,.35,3.5),(0,3.65,6.5),'black',.06)
    a.box('Zero-turn seat cushion',(1.7,.25,1.6),(0,4.55,6.9),'black',.15)
    a.box('Zero-turn seat back',(1.7,1.7,.32),(0,5.25,7.6),'black',.15,R(x=-8))
    for x in [-2,2]:
        for z in [5,7.4]:a.bar('Mower strapped tire',(x-.26,3.5,z),(x+.26,3.5,z),.70 if z>6 else .35,'rubber',24)
        a.tube('Mower lap steering bar',[(x*.5,4.2,6.3),(x*.5,5.1,5.8),(x*.25,5.1,5.8)],.065,'steel_dark',12)
    for x in [-1.8,1.8]:a.tube('Gold cargo ratchet strap',[(x,3.0,3),(x,4.1,5),(x,5.65,7.6),(x,3.0,10)],.045,'yellow',8)
    low,high=a.bounds();shift=Vector((0,low.y,(low.z+high.z)/2))
    for part in a.parts.values():part.verts=[v-shift for v in part.verts];part.origin-=shift
    for m in a.extra_markers:m['position_studs']=list(Vector(m['position_studs'])-shift)
    a.keep_authored_size=True;a.feature('circular_wheel_geometry_preserved',1)
    return a

def build37():
    for spec in SPECS:
        n=spec['name']
        if n.startswith('NPC_'):character(n)
        elif n.startswith('Debris'):junk(n)
        elif n.startswith('GloriaYard'):yard(int(n[-1]))
        elif n=='PorchRockingChair':rocker()
        elif n=='PorchDeck':porch()
        elif n=='GloriaHouse':house()
        elif n=='TurfKingTruck':truck()
        elif n=='TurfKingSign':turf_sign(Asset(n))
        elif n=='BestYardTrophy':trophy()
    for a in ASSETS.values():
        if a.name=='TurfKingSign':
            for side in [-1,1]:
                a.tube('Rolled sign perimeter',[(side*.77,1.18,-.045),(side*.77,1.92,-.045)],.022,'gold',16)
            for y in [1.18,1.92]:a.bar('Rolled sign edge',(-.77,y,-.045),(.77,y,-.045),.022,'gold',16)
            for x in [-.68,.68]:
                for y in [1.28,1.82]:a.sphere('Round sign rivet',(.055,.055,.025),(x,y,-.055),'gold',16,8)
            for x in [-.52,.52]:
                for j in range(10):a.ring('Welded wire collar',(x,.05+j*.06,0),.021,thick=.007,color='steel',n=12,sides=4)
        if a.name=='TurfKingTruck':
            for i in range(28):a.box('Ribbed cargo bed',(.08,.055,8.2),(-3.3+i*.245,2.92,6),'steel_dark',.01)
            a.sphere('Mower engine cooling shroud',(1.2,.9,1.3),(0,4.25,8.1),'black',24,12)
        total=a.triangle_count();low,high=budget_for(a.spec)
        if total>high:
            protected=sum(g.triangles for g in a.parts.values() if g.role=='lawn')
            ratio=(high*.94-protected)/(total-protected)
            for key,g in list(a.parts.items()):
                if g.role=='lawn':continue
                mesh=bpy.data.meshes.new('Budget reduction');mesh.from_pydata(g.verts,[],g.faces);mesh.update()
                colors=list(dict.fromkeys(g.colors))
                for color in colors:mesh.materials.append(material(color))
                for p,c in zip(mesh.polygons,g.colors):p.material_index=colors.index(c);p.use_smooth=True
                obj=bpy.data.objects.new('Budget reduction',mesh);bpy.context.scene.collection.objects.link(obj)
                mod=obj.modifiers.new('Preserve silhouette within model budget','DECIMATE');mod.ratio=ratio;mod.use_collapse_triangulate=True
                deps=bpy.context.evaluated_depsgraph_get();evaluated=obj.evaluated_get(deps);reduced=evaluated.to_mesh()
                ng=Geo(g.name,g.origin,g.role)
                ng.add([v.co.copy() for v in reduced.vertices],[tuple(p.vertices) for p in reduced.polygons],colors[0],True,label='Budgeted authored surface')
                ng.colors=[colors[p.material_index] for p in reduced.polygons]
                evaluated.to_mesh_clear();bpy.data.objects.remove(obj,do_unlink=True);bpy.data.meshes.remove(mesh)
                a.parts[key]=ng
        print('AUTHORED',a.name,a.triangle_count(),flush=True)
