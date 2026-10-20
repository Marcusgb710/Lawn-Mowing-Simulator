"""Render the actual SelfPropelledMower exactly side-on, facing right.
blender -b -t 4 --python Source/build_mower.py
"""
import bpy
import json
from pathlib import Path
from mathutils import Vector

HERE=Path(__file__).resolve().parent
OUT=HERE.parent
REPO=OUT.parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
src=REPO/'model-source/HighPoly/26_MowersAndRideOns/Models/SelfPropelledMower/SelfPropelledMower.gltf'
bpy.ops.import_scene.gltf(filepath=str(src))
scene=bpy.context.scene
bpy.context.view_layer.update()
verts=[o.matrix_world@Vector(v) for o in scene.objects if o.type=='MESH' for v in o.bound_box]
lo=Vector(tuple(min(v[i] for v in verts) for i in range(3)))
hi=Vector(tuple(max(v[i] for v in verts) for i in range(3)))
scale=(hi.y-lo.y)*512/480
target=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z+scale*(.5-16/512)))
d=bpy.data.cameras.new('Mower • orthographic right-facing side');cam=bpy.data.objects.new(d.name,d)
scene.collection.objects.link(cam);scene.camera=cam
cam.location=target+Vector((5,0,0))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
d.type='ORTHO';d.ortho_scale=scale
for pos,energy,size in [((3,3,5),650,5),((-2,-3,3),380,4)]:
    light=bpy.data.lights.new('Soft studio light','AREA');light.energy=energy;light.size=size
    o=bpy.data.objects.new(light.name,light);scene.collection.objects.link(o);o.location=pos
    o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.75,.9,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.render.engine='CYCLES';scene.cycles.samples=128;scene.cycles.use_denoising=False
scene.cycles.use_adaptive_sampling=True;scene.cycles.adaptive_threshold=.015
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
scene.render.filepath=str(OUT/'Mower.png')
for image in bpy.data.images:
    if image.source=='FILE':image.pack()
(HERE/'mower_camera.json').write_text(json.dumps(dict(projection='ORTHO',view='exact right-facing side; Blender +X view; Z up',target_meters=list(target),orthographic_scale_meters=scale,bottom_padding_px=16,horizontal_padding_px=16),indent=2)+'\n')
scene.render.filepath='//../Mower.png'
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'Mower.blend'),compress=True)
bpy.ops.render.render(write_still=True)
