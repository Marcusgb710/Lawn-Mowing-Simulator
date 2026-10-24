"""True geometry renders for the story pack; no staging is exported to glTF/FBX."""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;OUT=HERE.parent
sys.path.insert(0,str(HERE))
from core import C,S
scene=bpy.context.scene
rows=json.loads((OUT/'model_manifest.json').read_text())['assets']
for r in rows:bpy.data.collections[r['name']].hide_render=True
stage=bpy.data.collections.new('Review staging');scene.collection.children.link(stage)
def link(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    stage.objects.link(o)
mat=bpy.data.materials.new('Warm grey studio floor');mat.diffuse_color=(.27,.29,.27,1)
bpy.ops.mesh.primitive_plane_add(size=200);plane=bpy.context.object;link(plane);plane.location.z=-.015;plane.data.materials.append(mat)
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False
scene.cycles.use_adaptive_sampling=True;scene.cycles.adaptive_threshold=.04
scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.image_settings.color_mode='RGB'
scene.view_settings.view_transform='AgX';scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.74,.85,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for pos,energy,size in [((-3,4,6),1150,5),((4,-2,5),1500,4),((2,5,2),450,4)]:
    d=bpy.data.lights.new('Review softbox','AREA');d.energy=energy;d.size=size
    o=bpy.data.objects.new(d.name,d);stage.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Review camera');cam=bpy.data.objects.new(d.name,d);stage.objects.link(cam);scene.camera=cam;d.type='ORTHO'
out=OUT/'Previews';out.mkdir(exist_ok=True)
views=HERE/'CharacterViews';views.mkdir(exist_ok=True)
for r in rows:
    name=r['name']
    if '--only' in sys.argv and name not in sys.argv[sys.argv.index('--only')+1].split(','):continue
    root=bpy.data.objects[name];col=bpy.data.collections[name];col.hide_render=False
    lo=Vector(r['bounds_min_studs']);hi=Vector(r['bounds_max_studs']);center=C@((lo+hi)/2)*S
    factor=3/(max(r['dimensions_studs'])*S);middle=(hi.y-lo.y)*S*factor/2;root.scale=(factor,)*3;root.location=-center*factor+Vector((0,0,middle))
    for mode in (['Preview','Front','Side','Portrait'] if name.startswith('NPC_') else ['Preview']):
        if mode=='Portrait' and '--skip-portrait' in sys.argv:continue
        target=Vector((0,0,middle));offset=Vector((-5,9,3.2))
        if name.startswith('GloriaYard'):offset=Vector((-7,10,10))
        if mode=='Front':offset=Vector((0,9,0))
        if mode=='Side':offset=Vector((9,0,0))
        if mode=='Portrait':
            marker=next(m for m in r['markers'] if m['name']=='Head')
            target=C@Vector(marker['position_studs'])*S*factor+root.location-Vector((0,0,.20))
            offset=Vector((-.3,9,.2))
        cam.location=target+offset;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
        d.ortho_scale=1.35 if mode=='Portrait' else 3.65
        if mode=='Portrait':scene.render.resolution_x=1024;scene.render.resolution_y=1024
        else:scene.render.resolution_x=768;scene.render.resolution_y=768
        dest=out/(name+'_Preview.png') if mode=='Preview' else views/(name+'_'+mode+'.png')
        scene.render.filepath=str(dest);bpy.ops.render.render(write_still=True)
        print('RENDERED',name,mode,flush=True)
    root.scale=(1,1,1);root.location=(0,0,0);col.hide_render=True
