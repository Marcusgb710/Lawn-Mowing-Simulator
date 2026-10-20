"""Make output paths relative and audit the two editable packed Blender scenes.
blender -b -t 1 --python Source/prepare_sources.py
"""
import bpy
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
reports={}
for name,output,expected_size,projection in [
    ('TitleCard.blend','Background_Master.png',[2048,1152],'PERSP'),
    ('Mower.blend','Mower.png',[512,512],'ORTHO')]:
    path=HERE/name
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene=bpy.context.scene
    assert [scene.render.resolution_x,scene.render.resolution_y]==expected_size
    assert scene.camera.data.type==projection
    external=[im for im in bpy.data.images if im.source=='FILE']
    assert external and all(im.packed_file for im in external)
    scene.render.filepath='//../'+output
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    reports[name]=dict(size_px=expected_size,camera_projection=projection,
                      packed_texture_images=len(external),missing_external_textures=0,
                      output_path=scene.render.filepath,
                      transparent_background=scene.render.film_transparent)
    backup=path.with_suffix('.blend1')
    if backup.exists():backup.unlink()
(HERE/'native_scene_review.json').write_text(json.dumps(reports,indent=2)+'\n')
print('PASS: both editable scenes open, all file textures packed, outputs relative, correct cameras and sizes.')
