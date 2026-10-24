"""Detailed, unbranded mesh authoring. Coordinates are Roblox studs until serialization."""
import bpy,bmesh,math,json,random
from pathlib import Path
from mathutils import Vector,Matrix
from contextlib import contextmanager
S=.28;C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));CI=C.inverted();TAU=math.tau
WORK=Path(__file__).resolve().parent; REPO=WORK.parents[3]
SPECS=json.loads((WORK/'specifications.json').read_text());BY={s['name']:s for s in SPECS}
COLORS={'black':(24,28,30),'rubber':(31,34,35),'rubber_light':(46,48,47),'steel':(173,183,188),'steel_dark':(79,88,93),'galvanized':(145,156,157),'chrome':(196,205,210),'wood':(154,111,62),'wood_light':(183,145,93),'wood_dark':(104,72,44),'red':(182,34,34),'orange':(225,92,20),'yellow':(226,180,34),'green':(39,109,55),'blue':(35,91,157),'white':(221,226,220),'gray':(131,143,144),'darkgray':(65,76,80),'canvas':(145,124,85),'soil':(69,49,30),'stone':(125,129,119),'leaf':(45,105,38),'leaf_light':(84,134,45),'pink':(216,98,137),'purple':(138,72,164),'petal_white':(238,226,210),'amber':(220,140,35),'glass':(125,169,183),'clear':(208,225,229),'rust':(121,65,30)}
KINDS={'black':'plastic','rubber':'rubber','rubber_light':'rubber','steel':'steel','steel_dark':'steel','galvanized':'steel','chrome':'chrome','wood':'wood','wood_light':'wood','wood_dark':'wood','canvas':'fabric','soil':'soil','stone':'stone','leaf':'leaf','leaf_light':'leaf','glass':'glass','clear':'glass','rust':'rust'}
MATS={};BOX_CACHE={};WHEEL_MESH_CACHE={};ASSETS={}
def material(key):
 if key in MATS:return MATS[key]
 rgb=COLORS[key];kind=KINDS.get(key,'paint');m=bpy.data.materials.new('HP_'+key);m.use_nodes=True
 def linear(v):v=v/255;return v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4
 m.diffuse_color=tuple(linear(v) for v in rgb)+(1,);p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color
 p.inputs['Metallic'].default_value=.85 if kind in ['steel','chrome'] else .1 if kind=='paint' else 0
 p.inputs['Roughness'].default_value={'steel':.31,'chrome':.17,'wood':.64,'rubber':.78,'fabric':.86,'stone':.86,'soil':.96,'glass':.12,'leaf':.54,'rust':.86,'pegboard':.76}.get(kind,.38)
 if kind=='glass':p.inputs['Alpha'].default_value=.30 if key=='clear' else .42;m.surface_render_method='DITHERED';p.inputs['Metallic'].default_value=.12
 m['palette']=key;m['finish']=kind;MATS[key]=m;return m

def R(x=0,y=0,z=0):return Matrix.Rotation(math.radians(x),3,'X')@Matrix.Rotation(math.radians(y),3,'Y')@Matrix.Rotation(math.radians(z),3,'Z')
def mix(a,b,t):return Vector(a).lerp(Vector(b),t)
def circle(center,rx,ry,plane='xz',n=48,start=0,end=TAU):
 c=Vector(center);points=[]
 for i in range(n+1):
  t=start+(end-start)*i/n;v=(rx*math.cos(t),0,ry*math.sin(t)) if plane=='xz' else (rx*math.cos(t),ry*math.sin(t),0) if plane=='xy' else (0,rx*math.cos(t),ry*math.sin(t));points.append(c+Vector(v))
 return points

def catmull(points,steps=4):
 pts=[Vector(x) for x in points];out=[]
 for i in range(len(pts)-1):
  p0=pts[max(i-1,0)];p1=pts[i];p2=pts[i+1];p3=pts[min(i+2,len(pts)-1)]
  for j in range(steps):
   t=j/steps;out.append((2*p1+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t**3)*.5)
 out.append(pts[-1]);return out

class Geo:
 def __init__(self,name,origin=(0,0,0),role='static'):
  self.name=name;self.origin=Vector(origin);self.role=role;self.verts=[];self.faces=[];self.uvs=[];self.colors=[];self.smooth=[];self.feature_components=[]
 def add(self,verts,faces,color='steel',smooth=True,uvs=None,label=''):
  offset=len(self.verts);self.verts.extend([Vector(v) for v in verts]);self.faces.extend([tuple(i+offset for i in f) for f in faces]);self.colors.extend([color]*len(faces));self.smooth.extend([smooth]*len(faces) if isinstance(smooth,bool) else smooth)
  if uvs is None:
   low=[min(v[i] for v in verts) for i in range(3)];hi=[max(v[i] for v in verts) for i in range(3)];axes=sorted(range(3),key=lambda i:hi[i]-low[i],reverse=True)[:2]
   uvs=[((v[axes[0]]-low[axes[0]])/max(hi[axes[0]]-low[axes[0]],1e-9),(v[axes[1]]-low[axes[1]])/max(hi[axes[1]]-low[axes[1]],1e-9)) for v in verts]
  self.uvs.extend(uvs)
  if label:self.feature_components.append(dict(name=label,vertices=(offset,len(self.verts)),triangles=sum(len(f)-2 for f in faces)))
 @property
 def triangles(self):return sum(len(f)-2 for f in self.faces)

class Asset:
 def __init__(self,name):
  self.name=name;self.spec=BY[name];self.base=self.spec['baseline'];self.parts={};self.current=self.part(self.name+'__Body');self.features={};self.placement_transform=None;ASSETS[name]=self
 def part(self,name,origin=(0,0,0),role='static'):
  if name not in self.parts:self.parts[name]=Geo(name,origin,role)
  return self.parts[name]
 @contextmanager
 def moving(self,name,origin=(0,0,0),role='wheel'):
  prev=self.current;self.current=self.part(name,origin,role)
  try:yield self.current
  finally:self.current=prev
 def feature(self,name,count=1):self.features[name]=count
 def mesh(self,label,verts,faces,color='steel',smooth=True,uvs=None):self.current.add(verts,faces,color,smooth,uvs,label)
 def box(self,label,size,pos,color='steel',bevel=.02,rotation=None,segments=2):
  key=(tuple(round(v,6) for v in size),round(bevel,6),segments)
  if key not in BOX_CACHE:
   bm=bmesh.new();bmesh.ops.create_cube(bm,size=1)
   for v in bm.verts:v.co=Vector([v.co[i]*size[i] for i in range(3)])
   if bevel>0:
    bmesh.ops.bevel(bm,geom=list(bm.edges),offset=min(bevel,min(size)*.42),segments=segments,profile=.5,affect='EDGES',clamp_overlap=True)
   bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.verts.ensure_lookup_table();bm.verts.index_update();verts=[v.co.copy() for v in bm.verts];faces=[tuple(v.index for v in f.verts) for f in bm.faces];smooth=[max(abs(v) for v in f.normal)<.999 for f in bm.faces];BOX_CACHE[key]=(verts,faces,smooth);bm.free()
  verts,faces,smooth=BOX_CACHE[key];matrix=rotation or Matrix.Identity(3);p=Vector(pos)
  self.mesh(label,[matrix@v+p for v in verts],faces,color,smooth)
 def tube(self,label,points,r=.04,color='steel',sides=24,radii=None,hollow=0,curve=False,closed=False):
  pts=catmull(points,4) if curve else [Vector(p) for p in points]
  if closed and (pts[0]-pts[-1]).length<1e-8:pts=pts[:-1]
  verts=[];faces=[];uv=[];previous=None;n=len(pts)
  for i,p in enumerate(pts):
   tangent=((pts[(i+1)%n]-pts[(i-1)%n]) if closed else pts[min(i+1,n-1)]-pts[max(i-1,0)]).normalized()
   ref=Vector((0,1,0)) if abs(tangent.y)<.92 else Vector((1,0,0))
   u=(previous-tangent*previous.dot(tangent)).normalized() if previous is not None else tangent.cross(ref).normalized()
   if u.length<.1:u=tangent.cross(ref).normalized()
   previous=u.copy();v=tangent.cross(u);rr=radii[i] if radii else r
   for inner in range(2 if hollow else 1):
    rad=rr-hollow if inner else rr
    for j in range(sides):
     angle=j*TAU/sides;verts.append(p+(u*math.cos(angle)+v*math.sin(angle))*rad);uv.append((j/sides,i/max(n-1,1)))
  stride=sides*(2 if hollow else 1)
  for i in range(n if closed else n-1):
   nxt=(i+1)%n
   for j in range(sides):
    k=(j+1)%sides;faces.append((i*stride+j,i*stride+k,nxt*stride+k,nxt*stride+j))
    if hollow:faces.append((i*stride+sides+k,i*stride+sides+j,nxt*stride+sides+j,nxt*stride+sides+k))
  capcount=0
  if not closed:
   if hollow:
    for row in [0,(n-1)*stride]:
     for j in range(sides):k=(j+1)%sides;faces.append((row+j,row+sides+j,row+sides+k,row+k))
   else:faces.extend([tuple(reversed(range(sides))),tuple((n-1)*stride+j for j in range(sides))]);capcount=2
  self.mesh(label,verts,faces,color,[True]*(len(faces)-capcount)+[False]*capcount,uv)
 def bar(self,label,a,b,r=.04,color='steel',sides=24):self.tube(label,[a,b],r,color,sides)
 def ring(self,label,center,rx,ry=None,thick=.018,plane='xz',color='steel',n=48,sides=8):self.tube(label,circle(center,rx,rx if ry is None else ry,plane,n),thick,color,sides,closed=True)
 def sphere(self,label,size,pos,color='steel',segments=24,rings=10):
  verts=[];faces=[];uv=[];p=Vector(pos)
  verts.append(p+Vector((0,size[1]*.5,0)));uv.append((.5,0))
  for j in range(1,rings):
   t=j*math.pi/rings
   for i in range(segments):
    a=i*TAU/segments;verts.append(p+Vector((size[0]/2*math.sin(t)*math.cos(a),size[1]/2*math.cos(t),size[2]/2*math.sin(t)*math.sin(a))));uv.append((i/segments,j/rings))
  bottom=len(verts);verts.append(p-Vector((0,size[1]*.5,0)));uv.append((.5,1))
  for i in range(segments):faces.append((0,1+i,1+(i+1)%segments))
  for j in range(rings-2):
   for i in range(segments):k=(i+1)%segments;a=1+j*segments;faces.append((a+i,a+segments+i,a+segments+k,a+k))
  last=1+(rings-2)*segments
  for i in range(segments):faces.append((last+i,bottom,last+(i+1)%segments))
  self.mesh(label,verts,faces,color,True,uv)
 def lathe(self,label,profile,center=(0,0,0),color='steel',axis='y',segments=48,caps=True):
  verts=[];faces=[];uv=[];c=Vector(center)
  for j,(h,radius) in enumerate(profile):
   for i in range(segments):
    t=i*TAU/segments;v=Vector((radius*math.cos(t),h,radius*math.sin(t))) if axis=='y' else Vector((h,radius*math.cos(t),radius*math.sin(t))) if axis=='x' else Vector((radius*math.cos(t),radius*math.sin(t),h));verts.append(v+c);uv.append((i/segments,j/(len(profile)-1)))
  for j in range(len(profile)-1):
   for i in range(segments):k=(i+1)%segments;faces.append((j*segments+i,j*segments+k,(j+1)*segments+k,(j+1)*segments+i))
  if caps:faces.extend([tuple(reversed(range(segments))),tuple((len(profile)-1)*segments+i for i in range(segments))])
  self.mesh(label,verts,faces,color,[True]*(len(faces)-(2 if caps else 0))+[False]*(2 if caps else 0),uv)
 def profile(self,label,outline,thickness=.03,pos=(0,0,0),color='steel',rotation=None,bevel=0):
  clean=[]
  for v in outline:
   if not clean or (Vector(v)-Vector(clean[-1])).length>1e-7:clean.append(v)
  if len(clean)>2 and (Vector(clean[0])-Vector(clean[-1])).length<1e-7:clean.pop()
  outline=clean;n=len(outline);matrix=rotation or Matrix.Identity(3);p=Vector(pos)
  verts=[matrix@Vector((x,y,z))+p for y in [-thickness/2,thickness/2] for x,z in outline]
  faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
  for i in range(n):j=(i+1)%n;faces.append((i,j,n+j,n+i))
  self.mesh(label,verts,faces,color,False)
 def bolt(self,pos,r=.03,axis='y',color='steel'):
  p=Vector(pos);v=Vector((0,.025,0)) if axis=='y' else Vector((.025,0,0)) if axis=='x' else Vector((0,0,.025))
  self.bar('Hexagonal fastener',p-v,p+v,r,color,6)
  self.bar('Fastener washer',p-v*1.1,p-v*.9,r*1.35,color,24)
 def wheel(self,name,center,diam,width,air=True,dual=False,rim='gray',tread=True):
  with self.moving(name,center,'wheel'):
   c=Vector(center);radius=diam/2
   profile=[(-width*.45,radius*.54),(-width*.52,radius*.77),(-width*.47,radius*.93),(-width*.31,radius),(.31*width,radius),(.47*width,radius*.93),(.52*width,radius*.77),(.45*width,radius*.54),(-width*.45,radius*.54)]
   self.lathe('Pneumatic tire with shoulders' if air else 'Solid foam tire',profile,c,'rubber','x',48,False)
   self.lathe('Pressed rim dish',[(-width*.48,radius*.55),(-width*.32,radius*.48),(-width*.25,radius*.26),(.25*width,radius*.26),(.32*width,radius*.48),(.48*width,radius*.55)],c,rim,'x',48,True)
   self.bar('Axle hub',c+Vector((-width*.57,0,0)),c+Vector((width*.57,0,0)),radius*.19,'steel_dark',24)
   if tread:
    for i in range(30):
     t=i*TAU/30;rotation=R(x=math.degrees(t),y=12*(-1 if i%2 else 1),z=0)
     self.box('Moulded tire tread',(width*.62,diam*.022,diam*.075),c+Vector((0,radius*.998*math.cos(t),radius*.998*math.sin(t))),'rubber',0,rotation)
   for side in [-1,1]:
    for i in range(5):
     t=i*TAU/5;self.bar('Wheel lug',c+Vector((side*width*.48,radius*.25*math.cos(t),radius*.25*math.sin(t))),c+Vector((side*width*.53,radius*.25*math.cos(t),radius*.25*math.sin(t))),diam*.025,'steel',6)
    if air and side==(1 if c.x>=0 else -1):self.tube('Tire valve',[c+Vector((side*width*.44,radius*.46,0)),c+Vector((side*width*.61,radius*.46,0))],diam*.012,'black',24)
 def bounds(self):
  pts=[v for p in self.parts.values() for v in p.verts];return Vector([min(v[i] for v in pts) for i in range(3)]),Vector([max(v[i] for v in pts) for i in range(3)])
 def fit(self):
  if getattr(self,'keep_authored_size',False):
   self.placement_transform=dict(scale=[1,1,1],offset=[0,0,0],authored_at_nominal_size=True);return Vector((1,1,1)),Vector((0,0,0))
  if hasattr(self,'size_limits'):
   lo,hi=self.bounds();limit=Vector(self.size_limits);scale=Vector([min(1,(limit[i]-.025)/(hi[i]-lo[i])) for i in range(3)]);offset=Vector((0,-lo.y*scale.y,0))
   for g in self.parts.values():
    g.verts=[Vector([v[i]*scale[i]+offset[i] for i in range(3)]) for v in g.verts];g.origin=Vector([g.origin[i]*scale[i]+offset[i] for i in range(3)])
   for marker in getattr(self,'extra_markers',[]):marker['position_studs']=[marker['position_studs'][i]*scale[i]+offset[i] for i in range(3)]
   self.placement_transform=dict(scale=list(scale),offset=list(offset),first_person_size_exception=True);return scale,offset
  lo,hi=self.bounds();bl=Vector(self.base['bounds_min_studs']);bh=Vector(self.base['bounds_max_studs']);scale=Vector([(bh[i]-bl[i])/(hi[i]-lo[i]) for i in range(3)]);offset=bl-Vector([lo[i]*scale[i] for i in range(3)])
  def map_position(v):
   result=[];pin=getattr(self,'pin_grip',None);target=Vector(self.base['primary_position_studs'])
   for i in range(3):
    if pin is not None and lo[i]+1e-5<pin[i]<hi[i]-1e-5 and bl[i]+1e-5<target[i]<bh[i]-1e-5:
     result.append(target[i]+(v[i]-pin[i])*((target[i]-bl[i])/(pin[i]-lo[i]) if v[i]<pin[i] else (bh[i]-target[i])/(hi[i]-pin[i])))
    else:result.append(v[i]*scale[i]+offset[i])
   return Vector(result)
  for p in self.parts.values():p.verts=[map_position(v) for v in p.verts];p.origin=map_position(p.origin)
  for marker in getattr(self,'extra_markers',[]):marker['position_studs']=list(map_position(Vector(marker['position_studs'])))
  if hasattr(self,'new_slots'):self.new_slots=[list(map_position(Vector(v))) for v in self.new_slots]
  self.placement_transform=dict(scale=list(scale),offset=list(offset))
  if hasattr(self,'pin_grip'):self.placement_transform['piecewise_grip_pin']=dict(source=list(self.pin_grip),target=list(self.base['primary_position_studs']))
  return scale,offset
 def triangle_count(self):return sum(g.triangles for g in self.parts.values())


def budget_for(spec):return spec["budget"]
