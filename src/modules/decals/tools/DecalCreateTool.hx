package modules.decals.tools;

import level.data.Value;

class DecalCreateTool extends DecalTool
{
	public var canPreview:Bool;
	public var previewAt:Vector = new Vector();
	public var scale:Vector = new Vector(1, 1);
	public var origin:Vector = new Vector(0.5, 0.5);
	public var created:Decal = null;

	public var deleting:Bool = false;
	public var firstDelete:Bool = false;
	public var lastDeletePos:Vector = new Vector();

	override public function drawOverlay()
	{
		if (layerEditor.brush != null && created == null && !deleting && canPreview)
		{
			EDITOR.overlay.drawTexture(previewAt.x, previewAt.y, layerEditor.brush, layerEditor.brush.center, scale);
		}
	}

	override public function activated()
	{
		canPreview = false;
		scale = new Vector(1, 1);
	}

	override public function onMouseLeave()
	{
		canPreview = false;
	}

	override public function onMouseDown(pos:Vector)
	{
		deleting = false;

		if (layerEditor.brush == null) return;
		if (!OGMO.ctrl) {
			layer.snapToGrid(pos, pos);
		} else {
			layer.snapToInt(pos, pos);
		}

		EDITOR.level.store("create decal");
		EDITOR.locked = true;
		EDITOR.dirty();

		var path = js.node.Path.relative((cast layerEditor.template:DecalLayerTemplate).folder, layerEditor.brush.path);
		var values = [for (template in (cast layerEditor.template:DecalLayerTemplate).values) new Value(template)];
		created = new Decal(pos, path, layerEditor.brush, origin, scale, 0, values);
		layer.decals.push(created);

		if (OGMO.keyCheckMap[Keys.Shift])
			layerEditor.selected.push(created);
		else
			layerEditor.selected = [created];

		layerEditor.selectedChanged = true;
	}

	override public function onMouseUp(pos:Vector)
	{
		if (created != null)
		{
			created = null;
			EDITOR.locked = false;

			if (!OGMO.shift)
				EDITOR.toolBelt.setTool(0);
		}
	}

	override public function onRightDown(pos:Vector)
	{
		created = null;
		deleting = true;
		lastDeletePos = pos;
		EDITOR.locked = true;

		doDelete(pos);
	}

	override public function onRightUp(pos:Vector)
	{
		deleting = false;
		EDITOR.locked = false;
	}

	public function doDelete(pos:Vector)
	{
		var hit = layer.getAt(pos);

		if (hit.length > 0)
		{
			if (!firstDelete)
			{
				firstDelete = true;
				EDITOR.level.store("delete decals");
			}

			layerEditor.remove(hit[hit.length - 1]);
			EDITOR.dirty();
		}
	}

	override public function onMouseMove(pos:Vector)
	{
		if (created != null)
		{
			if (!OGMO.ctrl) {
				layer.snapToGrid(pos, pos);
			} else {
				layer.snapToInt(pos, pos);
			}

			if (!pos.equals(created.position))
			{
				pos.clone(created.position);
				EDITOR.dirty();
			}
		}
		else if (deleting)
		{
			if (!pos.equals(lastDeletePos))
			{
				pos.clone(lastDeletePos);
				doDelete(pos);
			}
		}
		else if (layerEditor.brush != null && !pos.equals(previewAt))
		{
			if (!OGMO.ctrl) {
				layer.snapToGrid(pos, pos);
			} else {
				layer.snapToInt(pos, pos);
			}

			canPreview = true;
			previewAt = pos;
			EDITOR.overlayDirty();
		}
	}

	override public function onKeyPress(key:Int)
	{
		if (key == Keys.H)
		{
			if ((cast layerEditor.template : DecalLayerTemplate).scaleable)
			{
				scale.x = -scale.x;
				EDITOR.dirty();
			}
		}
		else if (key == Keys.V)
		{
			if ((cast layerEditor.template : DecalLayerTemplate).scaleable)
			{
				scale.y = -scale.y;
				EDITOR.dirty();
			}
		}
		// TODO - Prep for UX overhaul PR!
		/*else if (key == Keys.B)
		{
			EDITOR.level.store("move decal to back");
			for (decal in layerEditor.selected) moveDecalToBack(decal);
			EDITOR.dirty();
		}
		else if (key == Keys.F)
		{
			EDITOR.level.store("move decal to front");
			for (decal in layerEditor.selected) moveDecalToFront(decal);
			EDITOR.dirty();
		}
	}

	function moveDecalToBack(decal:Decal)
	{
		var index = layer.decals.indexOf(decal);
		if (index < 0) return;
		layer.decals.splice(index, 1);
		layer.decals.unshift(decal);
	}

	function moveDecalToFront(decal:Decal)
	{
		var index = layer.decals.indexOf(decal);
		if (index < 0) return;
		layer.decals.splice(index, 1);
		layer.decals.push(decal);*/
	}

	override public function getIcon():String return "entity-create";
	override public function getName():String return "Create";

}
