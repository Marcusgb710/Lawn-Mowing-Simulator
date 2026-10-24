"""127 real model renders, consistent front-left camera and studio lighting.
blender -b -t 2 --python Source/render_items.py
"""
import bpy,json,math,sys
import numpy as np
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;REPO=OUT.parents[1]
specs=json.loads((HERE/'items.json').read_text())
BUSINESS='--business' in sys.argv
if BUSINESS:specs=[dict(id='BusinessDesk_RenderOnly',model='JobComputerDesk',path='model-source/HighPoly/33_ShopDesksAndDeliveries/Models/JobComputerDesk/JobComputerDesk.gltf',finish=None)]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False
scene.cycles.use_adaptive_sampling=True;scene.cycles.adaptive_threshold=.035
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=True
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.60,.70,.85,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Studio contact shadow only';floor.location.z=-.009;floor.is_shadow_catcher=True
for label,pos,energy,color,size in [('Warm key',(-3,4,6),950,(1,.87,.69),5),('Cool rim',(3,-4,5),1200,(.63,.78,1),4),('Soft front',(-1,5,2),300,(1,1,1),4)]:
    d=bpy.data.lights.new(label,'AREA');d.energy=energy;d.color=color;d.size=size
    o=bpy.data.objects.new(label,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Common front-left view');cam=bpy.data.objects.new(d.name,d);scene.collection.objects.link(cam);scene.camera=cam;d.type='ORTHO'
target=Vector((0,0,1.25));cam.location=target+Vector((-6,9,5.0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
reviews=json.loads((HERE/'item_render_review.json').read_text()) if (HERE/'item_render_review.json').exists() else []
HERO='--hero' in sys.argv
if HERO or BUSINESS:scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.cycles.samples=64
def finish_material(finish):
    m=bpy.data.materials.new('Render-only '+str(finish));m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
    if isinstance(finish,list):
        def linear(v):v=v/255;return v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4
        rgb=[linear(v) for v in finish];metal=.35;rough=.30
    elif finish=='gold':rgb=(.83,.53,.12);metal=1;rough=.20
    elif finish=='chrome':rgb=(.75,.79,.83);metal=1;rough=.13
    else:rgb=(.014,.017,.021);metal=.35;rough=.51
    p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
for row in specs:
    name=row['id'];dest=HERE/'BusinessDesk.png' if BUSINESS else HERE/'TrophyHero.png' if HERO else OUT/'Items'/(name+'.png')
    if '--only' in sys.argv and name not in sys.argv[sys.argv.index('--only')+1].split(','):continue
    if dest.exists() and '--overwrite' not in sys.argv:continue
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(REPO/row['path']))
    imported=list(set(bpy.data.objects)-before);meshes=[o for o in imported if o.type=='MESH']
    if BUSINESS:
        for obj in meshes:
            if '__Screen' not in obj.name:continue
            material=bpy.data.materials.new('Render-only shop desktop on screen');material.use_nodes=True
            bs=material.node_tree.nodes.get('Principled BSDF');tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/'StyleFrames/Computer_Orders.png'))
            material.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);material.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.3;bs.inputs['Roughness'].default_value=.4
            obj.data.materials.clear();obj.data.materials.append(material)
            points=[v.co for v in obj.data.vertices];lo=min(v.x for v in points);hi=max(v.x for v in points);bottom=min(v.z for v in points);top=max(v.z for v in points)
            uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='Screen')
            for loop in obj.data.loops:
                v=obj.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(1-(v.x-lo)/max(hi-lo,.001),(v.z-bottom)/max(top-bottom,.001))
    bpy.context.view_layer.update()
    root=bpy.data.objects.new('Item placement',None);scene.collection.objects.link(root)
    for o in imported:
        if o.parent not in imported:o.parent=root
    if row['finish']:
        finish=finish_material(row['finish']);cache={};changed=0
        for obj in meshes:
            if any(token in obj.name.lower() for token in ['wheel','glass','tire','tyre','lens']):continue
            mesh=obj.data
            slot=len(mesh.materials);mesh.materials.append(finish)
            for face in mesh.polygons:
                old=mesh.materials[face.material_index]
                if not old or not old.use_nodes:continue
                bs=next((n for n in old.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                if bs and bs.inputs['Alpha'].default_value<.98:continue
                tex=next((n.image for n in old.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.colorspace_settings.name=='sRGB'),None)
                if tex and mesh.uv_layers.active:
                    if tex.name not in cache:
                        a=np.empty(tex.size[0]*tex.size[1]*4,dtype=np.float32);tex.pixels.foreach_get(a);cache[tex.name]=a.reshape(tex.size[1],tex.size[0],4)
                    arr=cache[tex.name];uv=sum((mesh.uv_layers.active.data[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
                    rgb=arr[int(uv.y*arr.shape[0])%arr.shape[0],int(uv.x*arr.shape[1])%arr.shape[1],:3]
                elif bs:rgb=np.array(bs.inputs['Base Color'].default_value[:3])
                else:continue
                # WorkPickup's factory panels are off-white. Saturation alone
                # selects its lamps while missing the paint; identify that
                # atlas colour explicitly and preserve trim, wheels and glass.
                white_srgb=np.array([221,226,220])/255
                white_linear=np.where(white_srgb<=.04045,white_srgb/12.92,((white_srgb+.055)/1.055)**2.4)
                # Loaded image.pixels exposes the encoded atlas samples here;
                # untextured Principled base colours are linear values.
                white_target=white_srgb if tex and mesh.uv_layers.active else white_linear
                painted=(np.linalg.norm(rgb-white_target)<.045) if row['model']=='WorkPickup' else (max(rgb)-min(rgb)>.055 and max(rgb)>.10)
                if painted:
                    face.material_index=slot;changed+=1
        assert changed>(2000 if row['model']=='WorkPickup' else 0),('Paint mask missed body panels',name,changed)
    points=[o.matrix_world@Vector(p) for o in meshes for p in o.bound_box]
    lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
    factor=2.7/max(hi-lo);root.scale=(factor,)*3;root.location=-(lo+hi)/2*factor+Vector((0,0,(hi.z-lo.z)*factor/2))
    bpy.context.view_layer.update();inv=cam.matrix_world.inverted()
    points=[inv@(o.matrix_world@Vector(p)) for o in meshes for p in o.bound_box]
    low=[min(p[i] for p in points) for i in [0,1]];high=[max(p[i] for p in points) for i in [0,1]]
    cam.location+=cam.matrix_world.to_quaternion()@Vector(((low[0]+high[0])/2,(low[1]+high[1])/2,0))
    d.ortho_scale=max(high[0]-low[0],high[1]-low[1])/.80
    scene.render.filepath=str(dest)
    if name=='ReelMower':
        for im in bpy.data.images:
            if im.source=='FILE':im.pack()
        scene.render.filepath='//../Items/ReelMower.png';bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'ItemStudio.blend'),compress=True);scene.render.filepath=str(dest)
    bpy.ops.render.render(write_still=True)
    record=dict(id=name,projection='ORTHO',view_vector=[-6,9,5],longest_projected_occupancy=.8,finish=row['finish'],source=row['path'])
    if row['finish']:record['painted_faces']=changed
    if not HERO and not BUSINESS:
        reviews=[r for r in reviews if r['id']!=name]+[record]
        (HERE/'item_render_review.json').write_text(json.dumps(reviews,indent=2)+'\n')
    for obj in imported+[root]:bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.orphans_purge(do_recursive=True)
    cam.location=target+Vector((-6,9,5));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    print('ITEM',name,flush=True)
