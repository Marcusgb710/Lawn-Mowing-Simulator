"""Render the five fixed models and export their FBX alternatives.

Render-only cameras and lights are added after all asset exports.
"""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector,Matrix
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));S=.28
NAMES=['DeliveryCrate','SmallOffice','GloriaYard_Stage1','GloriaYard_Stage2','GloriaYard_Stage3']
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT/'ALL/40_Fixes.gltf'))
roots={name:bpy.data.objects[name] for name in NAMES}
grid={name:root.location.copy() for name,root in roots.items()}
for image in bpy.data.images:
    if image.source=='FILE' and not image.packed_file:image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'Surface_Fixes.blend'),compress=True)
for name in NAMES:
    root=roots[name];root.location=(0,0,0)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for child in root.children_recursive:child.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.fbx(filepath=str(OUT/'Models'/name/(name+'.fbx')),use_selection=True,object_types={'MESH','EMPTY'},apply_unit_scale=True,add_leaf_bones=False,bake_anim=False,axis_forward='-Z',axis_up='Y',path_mode='RELATIVE',use_custom_props=True)
    root.location=grid[name]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.cycles.use_adaptive_sampling=True;scene.cycles.adaptive_threshold=.035
scene.render.resolution_x=1280;scene.render.resolution_y=1280;scene.render.resolution_percentage=100;scene.render.image_settings.color_mode='RGB';scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.74,.85,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
floor_material=bpy.data.materials.new('Review floor only');floor_material.diffuse_color=(.27,.29,.27,1)
bpy.ops.mesh.primitive_plane_add(size=1000);floor=bpy.context.object;floor.location.z=-.002;floor.data.materials.append(floor_material)
lights=[]
for position,energy,size in [((-4,3,7),1200,5),((5,-4,6),1500,4),((0,5,3),400,5)]:
    light=bpy.data.lights.new('Review softbox','AREA');light.energy=energy;light.size=size;obj=bpy.data.objects.new(light.name,light);scene.collection.objects.link(obj);obj.location=position;lights.append(obj)
camera_data=bpy.data.cameras.new('Fixed surface review');cam=bpy.data.objects.new(camera_data.name,camera_data);scene.collection.objects.link(cam);scene.camera=cam;camera_data.type='ORTHO'
specs=[('DeliveryCrate','DeliveryCrate_Side',(14,5,-6),(0,2.2,0),9),('SmallOffice','SmallOffice_Front',(-11,9,-55),(0,8,-7),45),('SmallOffice','SmallOffice_Inside',(6,0,22),(9.5,7.5,-12),0)]
for stage in [1,2,3]:
    name=f'GloriaYard_Stage{stage}';specs.append((name,name+'_Lawn',(-24,50,-65),(0,0,-33),55))
for name,filename,offset,target,ortho in specs:
    for other,root in roots.items():
        for obj in [root]+list(root.children_recursive):obj.hide_render=other!=name
    root=roots[name];root.location=(0,0,0)
    # Normalize the review scene uniformly; exported units and pivots are intact.
    factor=1 if name=='DeliveryCrate' else .25 if name=='SmallOffice' else .18
    root.scale=(factor,)*3;target=C@Vector(target)*S*factor
    cam.location=target+C@Vector(offset)*S*factor;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO' if ortho else 'PERSP';camera_data.clip_start=.002;camera_data.clip_end=1000
    if ortho:camera_data.ortho_scale=ortho*S*factor
    else:camera_data.lens=23
    for light in lights:light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
    interior=[]
    if filename=='SmallOffice_Inside':
        for position,aim in [((12,13,0),(12,6,-13)),((15,10,1),(7,8,0))]:
            light=bpy.data.lights.new('Interior review softbox','AREA');light.energy=40;light.size=.6
            obj=bpy.data.objects.new(light.name,light);scene.collection.objects.link(obj);obj.location=C@Vector(position)*S*factor
            obj.rotation_euler=(C@Vector(aim)*S*factor-obj.location).to_track_quat('-Z','Y').to_euler();interior.append(obj)
    scene.render.filepath=str(OUT/'Previews'/(filename+'.png'));bpy.ops.render.render(write_still=True);print('PREVIEW',filename,flush=True)
    for obj in interior:bpy.data.objects.remove(obj,do_unlink=True)
    root.scale=(1,1,1);root.location=grid[name]
