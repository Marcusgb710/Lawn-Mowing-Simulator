"""Rebuild the title art using the unchanged HighPoly glTF model sources.

blender -b -t 4 --python Source/build_scene.py -- --draft
Omit --draft for the 2048 x 1152 final. Run from any directory.
"""
import bpy
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
OUT = HERE.parent
REPO = OUT.parents[1]
DRAFT = '--draft' in sys.argv
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
S = .28
def xyz(v): return C @ Vector(v) * S

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for col in list(bpy.data.collections):
    if col.name != 'Collection': bpy.data.collections.remove(col)
scene = bpy.context.scene
stage = bpy.data.collections.get('Collection')
stage.name = 'TITLE CARD • staging only'
inventory = []
templates = {}
def asset(pack, name):
    key = (pack, name)
    if key not in templates:
        folder = next((REPO / 'model-source/HighPoly').glob(str(pack)+'_*'))
        path = folder / 'Models' / name / (name+'.gltf')
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        objects = list(set(bpy.data.objects) - before)
        meshes = []
        for o in objects:
            if o.type == 'MESH':
                mat = o.matrix_world.copy()
                o.parent = None
                o.matrix_world = mat
                meshes.append(o)
        for o in objects:
            if o.type != 'MESH': bpy.data.objects.remove(o, do_unlink=True)
        for o in meshes:
            for col in list(o.users_collection): col.objects.unlink(o)
        templates[key] = meshes
    return templates[key]

def place(pack, name, pos, yaw=0, label=None):
    col = bpy.data.collections.new(label or name)
    scene.collection.children.link(col)
    root = bpy.data.objects.new(col.name+' • placement', None)
    col.objects.link(root)
    root.location = xyz(pos)
    root.rotation_euler = (C @ Matrix.Rotation(math.radians(yaw), 3, 'Y') @ C.inverted()).to_euler()
    copies = []
    for obj in asset(pack, name):
        copy = obj.copy()
        copy.data = obj.data
        col.objects.link(copy)
        copy.parent = root
        copies.append(copy)
    inventory.append(dict(model=name, pack=pack, position_studs=pos, yaw_degrees=yaw, placement=col.name))
    return root, copies

def material(name, color, rough=.8, noise=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = rough
    if noise:
        nodes = m.node_tree.nodes
        tex = nodes.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value = noise
        tex.inputs['Detail'].default_value = 3
        geo = nodes.new('ShaderNodeNewGeometry')
        ramp = nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = .2
        ramp.color_ramp.elements[1].position = .8
        ramp.color_ramp.elements[0].color = (*(c*.75 for c in color), 1)
        ramp.color_ramp.elements[1].color = (*(min(1, c*1.17) for c in color), 1)
        bump = nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .18
        bump.inputs['Distance'].default_value = .018
        m.node_tree.links.new(geo.outputs['Position'], tex.inputs['Vector'])
        m.node_tree.links.new(tex.outputs['Fac'], ramp.inputs[0])
        m.node_tree.links.new(ramp.outputs[0], bs.inputs['Base Color'])
        m.node_tree.links.new(tex.outputs['Fac'], bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs[0], bs.inputs['Normal'])
    return m

def box(name, center, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(center))
    o = bpy.context.object; o.name = name
    o.dimensions = (size[0]*S, size[2]*S, size[1]*S)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    if bevel:
        mod = o.modifiers.new('Soft edges', 'BEVEL'); mod.width = bevel*S; mod.segments = 2
        o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return o

# Actual model sources: no remodelling or export changes.
place(24, 'Shed', (-10, 0, 8), 0)
truck, pieces = place(25, 'RustyPickup', (8.3, .035, 8.5), 148)
for o in pieces:
    if o.name.split('.')[0] == 'RustyPickup__Tailgate':
        # The source hinge is X in Roblox space, also X in Blender space.
        basis=o.matrix_basis.copy()
        o.matrix_basis=Matrix.Translation(basis.translation) @ Matrix.Rotation(math.pi/2,4,'X') @ basis.to_3x3().to_4x4()
place(26, 'SelfPropelledMower', (-12.6, .015, -4.5), -90, 'Mower • last cut stripe')
# The second mower is placed on the actual truck bed floor.
bpy.context.view_layer.update()
bed_origin = truck.matrix_local @ xyz((0, 2.91, 4.8))
bed_pos = list(C.inverted() @ bed_origin / S)
place(26, 'SelfPropelledMower', bed_pos, 148, 'Mower • truck bed')
# A back-wall pegboard is visible through the existing open shed door.
place(32, 'StoragePegboard', (-10, 3.25, 13.7), 0)
place(32, 'StorageWallRack', (-6.7, 3.1, 13.7), 0)
for n, x, yaw in [('GardenSpade', -10.9, 0), ('WideRake', -9.4, 0)]:
    place(30, n, (x, .32, 13.1), yaw)
place(29, 'HandTrowel', (-11.7, 4.6, 13.0), 0)
for x in [-20, -28.6]: place(34, 'PicketFenceSection', (x, 0, 10))
for x in [19.8, 28.4]: place(34, 'PicketFenceSection', (x, 0, 12))
place(34, 'Mailbox', (17.8, 0, 5), -16)
place(34, 'TerracottaPlanter', (-16.4, 0, 2))
place(34, 'TerracottaPlanter', (-3.3, 0, 2))
for x in [-17.0, -15.0, -3.4]: place(24, 'FlowerPatch', (x, .03, -.5))
place(34, 'HydrangeaBush', (-18.4, 0, 4.0))

grass = material('Staging • uncut lawn', (.105, .235, .045), noise=65)
cut_a = material('Staging • mown stripe light', (.19, .34, .075), noise=100)
cut_b = material('Staging • mown stripe dark', (.12, .255, .049), noise=100)
concrete = material('Staging • aged warm concrete', (.38, .36, .31), noise=48)
asphalt = material('Staging • neighborhood street', (.095, .105, .11), noise=85)
soil = material('Staging • bed soil', (.085, .038, .014), noise=40)
box('Lawn foundation', (0, -.16, 45), (240, .3, 220), grass)
for i in range(11):
    box('Mown pass %02d'%i, (-17.5, .002, -29+i*3), (17, .012, 3), cut_a if i%2 else cut_b)
box('Driveway', (10, .015, -7), (17, .08, 45), concrete)
for z in [-26, -19, -12, -5]:
    box('Concrete expansion joint', (10, .06, z), (17, .006, .035), asphalt)
box('Shed doorstep', (-10, .11, .2), (6.5, .22, 2.4), concrete, .04)
box('Flower bed', (-18.6, .018, 1.5), (7.5, .08, 4.5), soil, .15)
# Quiet distant street and recognizable houses with optical depth of field.
box('Suburban street', (0, -.08, 37), (180, .12, 14), asphalt)
box('Far sidewalk', (0, .02, 46), (180, .15, 4), concrete)
for i, x in enumerate([-61, -24, 20, 59]):
    place(24, 'House', (x, 0, 110 + (i%2)*9), 0, 'Distant house %d'%i)

# Curved, solid blades make the cut/uncut edge legible without alpha cards.
rng = random.Random(3501)
verts, faces, mids = [], [], []
blade_mats = [material('Staging • long grass '+str(i), c) for i,c in enumerate([
    (.10,.235,.035),(.15,.30,.055),(.23,.355,.075),(.12,.27,.043)])]
for k in range(44000):
    x = rng.uniform(-26, 27); z = rng.uniform(-30, 4)
    if x < -9 or 1.5 < x < 18.5: continue
    if x < -14 and z > -1: continue
    h = rng.uniform(.23, .51); w = rng.uniform(.022, .045)
    angle = rng.uniform(0, math.tau); dx, dz = math.cos(angle), math.sin(angle)
    bend = rng.uniform(.06,.18)
    start = len(verts)
    for q in [(x-dx*w, .02, z-dz*w), (x+dx*w,.02,z+dz*w),
              (x+dx*w*.45+bend,.02+h*.6,z+dz*w*.45),
              (x-dx*w*.45+bend,.02+h*.6,z-dz*w*.45),
              (x+bend*1.5,.02+h,z+bend*.3)]: verts.append(xyz(q))
    faces.extend([(start,start+1,start+2,start+3),(start+3,start+2,start+4)])
    mids.extend([rng.randrange(4)]*2)
mesh = bpy.data.meshes.new('Curved uncut lawn blades'); mesh.from_pydata(verts, [], faces); mesh.update()
o = bpy.data.objects.new('Long lawn • edge of the last pass', mesh); stage.objects.link(o)
for m in blade_mats: mesh.materials.append(m)
for p, mi in zip(mesh.polygons, mids): p.material_index = mi

# Sunny morning: warm low sun and a clear blue sky.
world = bpy.data.worlds.new('Clear morning sky'); scene.world = world; world.use_nodes = True
nodes = world.node_tree.nodes
sky = nodes.new('ShaderNodeTexSky'); sky.sky_type = 'NISHITA'
sky.sun_elevation = math.radians(13); sky.sun_rotation = math.radians(128)
sky.sun_disc = False; sky.altitude = .1; sky.air_density = 1.1; sky.dust_density = .6
nodes['Background'].inputs['Strength'].default_value = .32
world.node_tree.links.new(sky.outputs[0], nodes['Background'].inputs[0])
# A restrained photographic sky gradient for camera rays; the physically based
# Nishita sky still illuminates every material and reflection.
camera_sky=nodes.new('ShaderNodeBackground');camera_sky.inputs['Strength'].default_value=.8
coord=nodes.new('ShaderNodeTexCoord');sep=nodes.new('ShaderNodeSeparateXYZ')
mapping=nodes.new('ShaderNodeMapRange');mapping.inputs['From Min'].default_value=0;mapping.inputs['From Max'].default_value=-.48
ramp=nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].color=(.8,.65,.44,1)
ramp.color_ramp.elements[1].color=(.14,.36,.64,1)
mid=ramp.color_ramp.elements.new(.25);mid.color=(.32,.55,.72,1)
path=nodes.new('ShaderNodeLightPath');mix=nodes.new('ShaderNodeMixShader')
links=world.node_tree.links
links.new(coord.outputs['Normal'],sep.inputs[0]);links.new(sep.outputs['Z'],mapping.inputs['Value'])
links.new(mapping.outputs['Result'],ramp.inputs[0]);links.new(ramp.outputs[0],camera_sky.inputs[0])
links.new(path.outputs['Is Camera Ray'],mix.inputs[0]);links.new(nodes['Background'].outputs[0],mix.inputs[1])
links.new(camera_sky.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],nodes['World Output'].inputs[0])
d = bpy.data.lights.new('Low warm morning sun', 'SUN'); d.energy = 2.3
d.color = (1, .78, .53); d.angle = math.radians(5)
sun = bpy.data.objects.new(d.name, d); stage.objects.link(sun)
sun.rotation_euler = Vector((-.65,.6,-.35)).to_track_quat('-Z','Y').to_euler()
d = bpy.data.lights.new('Shed doorway soft bounce', 'AREA'); d.energy=38; d.shape='DISK'; d.size=1.7
light=bpy.data.objects.new(d.name,d);stage.objects.link(light);light.location=xyz((-10,6,-1))
light.rotation_euler=(xyz((-10,4,10))-light.location).to_track_quat('-Z','Y').to_euler()
cam_data=bpy.data.cameras.new('Title card • eye height');cam=bpy.data.objects.new(cam_data.name,cam_data)
stage.objects.link(cam);scene.camera=cam
cam.location=xyz((1,6.7,-39));target=xyz((0,9.2,1))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.lens=27;cam_data.sensor_width=36
focus=bpy.data.objects.new('Focus • shop and equipment',None);stage.objects.link(focus);focus.location=xyz((0,3,-1))
cam_data.dof.use_dof=True;cam_data.dof.focus_object=focus;cam_data.dof.aperture_fstop=2.2
scene.render.engine='CYCLES';scene.cycles.samples=24 if DRAFT else 192
scene.cycles.use_adaptive_sampling=True;scene.cycles.adaptive_threshold=.035 if DRAFT else .012
scene.cycles.max_bounces=6;scene.cycles.transparent_max_bounces=6
scene.cycles.use_denoising=False
scene.render.resolution_x=1280 if DRAFT else 2048
scene.render.resolution_y=720 if DRAFT else 1152
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='8'
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=.3
scene.render.film_transparent=False
bpy.context.view_layer.update()
from bpy_extras.object_utils import world_to_camera_view
projected={}
for row in inventory:
    col=bpy.data.collections[row['placement']]
    coords=[world_to_camera_view(scene,cam,o.matrix_world@v.co) for o in col.objects if o.type=='MESH' for v in o.data.vertices]
    projected[row['placement']]=[round(min(p.x for p in coords)*2048,2),round((1-max(p.y for p in coords))*1152,2),round(max(p.x for p in coords)*2048,2),round((1-min(p.y for p in coords))*1152,2)]
(HERE/'composition_review.json').write_text(json.dumps(dict(master_size_px=[2048,1152],common_safe_rect_px=[256,103.5,1792,1048.5],projected_model_bounds_px=projected),indent=2)+'\n')
# Pack textures and purge hidden template originals so the native scene is portable.
for objects in templates.values():
    for o in objects: bpy.data.objects.remove(o, do_unlink=True)
for image in bpy.data.images:
    if image.source=='FILE': image.pack()
scene.render.filepath=str(OUT/('Source/Background_Draft.png' if DRAFT else 'Background_Master.png'))
if not DRAFT:
    (HERE/'scene_inventory.json').write_text(json.dumps(dict(models=inventory,camera_position_studs=[1,6.7,-39],camera_target_studs=[0,9.2,1],note='All source-model geometry is unchanged; the truck tailgate uses its authored hinge. Other geometry is render-only staging.'),indent=2)+'\n')
    scene.render.filepath='//../Background_Master.png'
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'TitleCard.blend'),compress=True)
bpy.ops.render.render(write_still=True)
