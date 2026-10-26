"""Five requested camera views of the delivered geometry and unchanged references."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector,Matrix
HERE=Path(__file__).resolve().parent;OUT=HERE.parent
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));S=.28
bpy.ops.wm.open_mainfile(filepath=str(HERE/'June_Seated.blend'))
scene=bpy.context.scene
def visible(name,value):bpy.data.collections[name].hide_render=not value
stage=bpy.data.collections.new('Preview staging only');scene.collection.children.link(stage)
def link(obj):
    for col in list(obj.users_collection):col.objects.unlink(obj)
    stage.objects.link(obj)
floor_mat=bpy.data.materials.new('Warm neutral review floor');floor_mat.diffuse_color=(.27,.29,.27,1)
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;link(floor);floor.location.z=-.002;floor.data.materials.append(floor_mat)
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.cycles.use_adaptive_sampling=True;scene.cycles.adaptive_threshold=.035
scene.render.resolution_x=1280;scene.render.resolution_y=1280;scene.render.resolution_percentage=100;scene.render.image_settings.color_mode='RGB';scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX';scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.74,.85,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for pos,energy,size in [((-3,4,6),1150,5),((4,-2,5),1500,4),((2,5,2),450,4)]:
    light=bpy.data.lights.new('Review softbox','AREA');light.energy=energy;light.size=size;o=bpy.data.objects.new(light.name,light);stage.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Pose review camera');cam=bpy.data.objects.new(data.name,data);stage.objects.link(cam);scene.camera=cam;data.type='ORTHO'
def capture(name,offset,target,scale):
    if '--only' in sys.argv and name not in sys.argv[sys.argv.index('--only')+1].split(','):return
    target=C@Vector(target)*S;cam.location=target+C@Vector(offset)*S;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();data.ortho_scale=scale*S
    scene.render.filepath=str(OUT/'Previews'/(name+'.png'));bpy.ops.render.render(write_still=True);print('PREVIEW',name,flush=True)
visible('PorchDeck',False);visible('PorchRockingChair',False);visible('NPC_June_Sitting',True)
capture('June_Front',(0,0,-15),(0,2.15,-.3),5.15)
capture('June_Side',(15,0,0),(0,2.15,-.3),5.15)
visible('PorchRockingChair',True)
capture('June_InRocker_Side',(15,0,0),(0,2.15,-.1),5.3)
capture('June_InRocker_ThreeQuarter',(10,3,-15),(0,2.15,-.1),5.5)
visible('PorchDeck',True)
row=next(r for r in json.loads((OUT.parent/'37_Story/model_manifest.json').read_text())['assets'] if r['name']=='PorchDeck')
spot=next(m['position_studs'] for m in row['markers'] if m['name']=='ChairSpot')
for name in ['PorchRockingChair','NPC_June_Sitting']:bpy.data.objects[name].location=C@Vector(spot)*S
capture('June_OnPorch',(13,9,-17),(-.2,2.8,0),13.0)
scene.render.filepath='//../Previews/June_OnPorch.png';bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'June_OnPorch.blend'),compress=True)
