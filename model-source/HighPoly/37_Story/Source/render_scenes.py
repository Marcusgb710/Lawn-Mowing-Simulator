"""Porch and contest scenes, composed from the delivered story geometry."""
import bpy,json,math,sys,time,subprocess
from pathlib import Path
from mathutils import Matrix,Vector
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;REPO=HERE.parents[3]
while any('export_story.py' in line for line in subprocess.run(['ps','-C','blender','-o','args='],capture_output=True,text=True).stdout.splitlines()):time.sleep(2)
bpy.ops.wm.open_mainfile(filepath=str(HERE/'Story.blend'))
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));S=.28
scene=bpy.context.scene;rows=json.loads((OUT/'model_manifest.json').read_text())['assets']
for r in rows:bpy.data.collections[r['name']].hide_render=True
stage=bpy.data.collections.new('Story scene staging only');scene.collection.children.link(stage)
def place(name,pos,yaw=0):
    root=bpy.data.objects.new('Scene '+name,None);stage.objects.link(root);root.location=C@Vector(pos)*S;root.rotation_euler=(C@Matrix.Rotation(math.radians(yaw),3,'Y')@C.inverted()).to_euler()
    for obj in bpy.data.collections[name].objects:
        if obj.type!='MESH':continue
        clone=obj.copy();clone.data=obj.data;stage.objects.link(clone);clone.parent=root
    return root
def simple_mat(name,rgb):
    m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*rgb,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;return m
lawn=simple_mat('Staging lawn',(.14,.27,.06));light_lawn=simple_mat('Staging stripe',(.20,.34,.08))
def box(pos,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=C@Vector(pos)*S);o=bpy.context.object;o.dimensions=(size[0]*S,size[2]*S,size[1]*S);o.data.materials.append(mat)
    for col in list(o.users_collection):col.objects.unlink(o)
    stage.objects.link(o)
box((0,-.12,30),(180,.2,180),lawn)
for i in range(14):box((-28+i*4,.005,-8),(4,.01,30),light_lawn if i%2 else lawn)
white=simple_mat('Staging white fence',(.75,.79,.72))
for z in range(-1,29):box((-14,1.5,z),(.15,3,.35),white)
for y in [.9,2.2]:box((-14,y,14),(.18,.13,30),white)
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.50,.69,.87,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
sun_data=bpy.data.lights.new('Warm afternoon sun','SUN');sun_data.energy=2.1;sun_data.angle=.10;sun_data.color=(1,.83,.60)
sun=bpy.data.objects.new(sun_data.name,sun_data);stage.objects.link(sun);sun.rotation_euler=(.5,-.4,-.7)
d=bpy.data.cameras.new('Scene camera');cam=bpy.data.objects.new(d.name,d);stage.objects.link(cam);scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False;scene.cycles.use_adaptive_sampling=True;scene.cycles.adaptive_threshold=.04
scene.render.resolution_x=1920;scene.render.resolution_y=1080;scene.render.resolution_percentage=100;scene.render.image_settings.color_mode='RGB';scene.view_settings.view_transform='AgX'
def capture(name,position,target,lens):
    selected='--only' not in sys.argv or name in sys.argv[sys.argv.index('--only')+1].split(',')
    cam.location=C@Vector(position)*S;cam.rotation_euler=(C@Vector(target)*S-cam.location).to_track_quat('-Z','Y').to_euler();d.lens=lens
    for im in bpy.data.images:
        if im.source=='FILE' and not im.packed_file:im.pack()
    if selected:
        scene.render.filepath='//../Previews/'+name+'.png';bpy.ops.wm.save_as_mainfile(filepath=str(HERE/(name+'.blend')),compress=True)
        scene.render.filepath=str(OUT/'Previews'/(name+'.png'));bpy.ops.render.render(write_still=True);print('SCENE',name,flush=True)
    remove=[o for o in stage.objects if o.parent is not None or o.type=='EMPTY']
    for o in remove:bpy.data.objects.remove(o,do_unlink=True)
place('PorchDeck',(0,0,0));chair=next(m for m in next(r for r in rows if r['name']=='PorchDeck')['markers'] if m['name']=='ChairSpot')['position_studs']
place('PorchRockingChair',chair);place('NPC_June_Sitting',chair)
place('GloriaHouse',(-36,0,40));place('GloriaYard_Stage2',(-36,0,40))
house_row=next(r for r in rows if r['name']=='GloriaHouse')
drive=next(m for m in house_row['markers'] if m['name']=='Driveway')['position_studs']
porch=next(m for m in house_row['markers'] if m['name']=='Porch')['position_studs']
place('TurfKingTruck',list(Vector((-36,0,40))+Vector(drive)));place('NPC_Gloria',list(Vector((-36,0,40))+Vector(porch)))
capture('Scene_Porch',(12,8,-19),(-9,6,8),28)
for name,pos,yaw in [('NPC_June_Standing',(-4,0,0),-65),('NPC_Gloria',(4,0,0),65),('NPC_Judge1',(-2.2,0,4),0),('NPC_Judge2',(2.2,0,4),0),('BestYardTrophy',(0,0,-2),0),('GloriaHouse',(4,0,45),0),('GloriaYard_Stage3',(4,0,45),0)]:place(name,pos,yaw)
capture('Scene_Contest',(12,9,-22),(0,3,1),42)
