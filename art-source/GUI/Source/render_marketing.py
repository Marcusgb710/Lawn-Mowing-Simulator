"""Render marketing compositions from the actual game and story models."""
import bpy,math,sys,subprocess,re,os
from pathlib import Path
from mathutils import Vector,Matrix
HERE=Path(__file__).resolve().parent;OUT=HERE.parent;REPO=OUT.parents[1];C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));S=.28
def capture(name,size=(1920,1080)):
    if '--only' in sys.argv and name not in sys.argv[sys.argv.index('--only')+1].split(','):return
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False;scene.cycles.use_adaptive_sampling=True;scene.cycles.adaptive_threshold=.035
    other_threads=0
    for line in subprocess.run(['ps','-C','blender','-o','pid=,args='],capture_output=True,text=True).stdout.splitlines():
        pid,args=line.strip().split(maxsplit=1)
        if int(pid)==os.getpid() or '<defunct>' in args:continue
        match=re.search(r'(?:^| )-t (\d+)',args);other_threads+=int(match.group(1)) if match else 1
    scene.render.threads_mode='FIXED';scene.render.threads=max(1,4-other_threads)
    scene.render.resolution_x=size[0];scene.render.resolution_y=size[1];scene.render.resolution_percentage=100;scene.render.image_settings.color_mode='RGB';scene.render.film_transparent=False
    for im in bpy.data.images:
        if im.source=='FILE' and not im.packed_file:im.pack()
    scene.render.filepath='//'+name+'.png';bpy.ops.wm.save_as_mainfile(filepath=str(HERE/(name+'.blend')),compress=True)
    scene.render.filepath=str(HERE/(name+'.png'));bpy.ops.render.render(write_still=True);print('MARKETING',name,flush=True)
def camera(pos,target,lens):
    cam=bpy.context.scene.camera;cam.location=C@Vector(pos)*S;cam.rotation_euler=(C@Vector(target)*S-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=lens;cam.data.dof.use_dof=False
bpy.ops.wm.open_mainfile(filepath=str(REPO/'art-source/TitleCard/Source/TitleCard.blend'))
camera((-3,5.5,-25),(-3,.6,-7),33)
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(REPO/'model-source/HighPoly/29_HandTools/Models/GardenShears/GardenShears.gltf'))
imported=list(set(bpy.data.objects)-before);cam=bpy.context.scene.camera
root=bpy.data.objects.new('Render-only first-person shears',None);bpy.context.scene.collection.objects.link(root);root.parent=cam;root.location=(.15,-.20,-1.25);root.rotation_euler=(math.pi/2,0,-.35);root.scale=(1.05,)*3
for obj in imported:
    if obj.parent not in imported:obj.parent=root
capture('Marketing_Shears')
bpy.ops.wm.open_mainfile(filepath=str(REPO/'model-source/HighPoly/37_Story/Source/Scene_Porch.blend'))
camera((8,5,-17),(-3,.1,-9),30);capture('Marketing_Wallpaper',(1024,576))
bpy.ops.wm.open_mainfile(filepath=str(REPO/'model-source/HighPoly/37_Story/Source/Scene_Contest.blend'))
scene=bpy.context.scene
def hide_model(token):
    for obj in list(scene.objects):
        if obj.type=='EMPTY' and obj.name.startswith('Scene '+token):
            obj.hide_render=True
            for child in obj.children_recursive:child.hide_render=True
for token in ['NPC_Judge1','NPC_Judge2','BestYardTrophy']:hide_model(token)
mat=bpy.data.materials.new('Marketing white fence');mat.diffuse_color=(.8,.83,.77,1)
def visible_fence_part(obj):
    # The imported library's active collection is hidden in these scene files.
    # Put review-scene additions in the visible scene root explicitly.
    for collection in list(obj.users_collection):collection.objects.unlink(obj)
    scene.collection.objects.link(obj)
for z in [-2,-1,0,1,2,3]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=C@Vector((0,1.45,z))*S);o=bpy.context.object;o.dimensions=(.15*S,.30*S,2.9*S);o.data.materials.append(mat)
    visible_fence_part(o)
for y in [1,2.2]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=C@Vector((0,y,.5))*S);o=bpy.context.object;o.dimensions=(.18*S,5.5*S,.14*S);o.data.materials.append(mat)
    visible_fence_part(o)
camera((10,7.2,-21),(0,3,1),42);capture('Marketing_Rivals')
bpy.ops.wm.open_mainfile(filepath=str(REPO/'model-source/HighPoly/37_Story/Source/Scene_Contest.blend'))
scene=bpy.context.scene
for token in ['NPC_Judge1','NPC_Judge2','NPC_June','NPC_Gloria']:hide_model(token)
camera((9,6,-13),(0,3,-1),40);capture('Marketing_TrophyYard')
