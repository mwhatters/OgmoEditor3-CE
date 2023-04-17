package level.editor.ui;

import io.FileSystem;
import js.node.fs.Stats;
import js.Browser;
import js.node.Fs;
import js.node.Path;
import electron.Shell;
import util.ItemList;
import util.Chokidar;
import util.RightClickMenu;
import util.Popup;

typedef PanelItem =
{
	path:String,
	dirname:String,
	?children:Array<PanelItem>,
	?node:ItemListNode
}

class LevelsPanel extends SidePanel
{
	public var searchbar:JQuery;
	public var levels:JQuery;
	public var newbutton:JQuery;
	public var opened: Map<String, Bool> = new Map();
	public var currentSearch:String = "";
	public var refreshTimer:Int;
	public var itemlist:ItemList;
	public var unsavedFolder:ItemListFolder = null;

	var items:Array<PanelItem> = [];
	var watchers:Array<FSWatcher> = [];
	var item_count:Int;
	var warning_displayed:Bool;

	override public function populate(into:JQuery):Void
	{
		into.empty();

		var options = new JQuery('<div class="options">');
		into.append(options);

		// new levels button
		newbutton = new JQuery('<div class="button"><div class="button_icon icon icon-new-file"></div></div>');
		newbutton.on('click', function() { EDITOR.levelManager.create(); });
		options.append(newbutton);

		// search bar
		searchbar = new JQuery('<div class="searchbar"><div class="searchbar_icon icon icon-magnify-glass"></div><input class="searchbar_field" tabindex="-1"/></div>');
		searchbar.find("input").on("change keyup", refresh);
		options.append(searchbar);

		// levels list
		levels = new JQuery('<div class="levelsPanel">');
		into.append(levels);

		var paths = OGMO.project.getAbsoluteLevelDirectories();

		for (watcher in watchers) watcher.close();
		watchers.resize(0);

		itemlist = new ItemList(levels);
		items.resize(0);
		item_count = 0;
		warning_displayed = false;

		if (OGMO.project != null) {
			function recursiveAdd(path:String, stats:Stats, parent:PanelItem):Bool
			{
				if (OGMO.project == null) return false;
				if (stats == null) stats = FileSystem.stat(path);

				// if item's directory is the root folder, add to that
				var dirname = Path.dirname(path);
				if (dirname == parent.path)
				{
					// Remove any duplicates
					for (child in parent.children) if (path == child.path) parent.children.remove(child);

					if (stats.isDirectory())
					{
						// Add Folder
						parent.children.push({
							path: path,
							dirname: dirname,
							children: []
						});

						item_count++;
					}
					else if (stats.isFile() && path != OGMO.project.path)
					{
						// Add File
						parent.children.push({
							path: path,
							dirname: dirname,
						});

						item_count++;
					}

					if (!warning_displayed && item_count > 10000)
					{
						Popup.open('Large Project Directory Detected', 'warning', 'The Project is currently in a directory with over 10000 files/sub-directories. This may impact negatively Ogmo Editor\'s performance. Consider moving the Project to a smaller directory, or limiting the Project\'s Directory Depth (located in the Project Editor).', ['Okay']);
						warning_displayed = true;
					}

					refresh();
					return true;
				}
				// otherwise search for directory to add
				else {
					var found = false;
					if (parent.children != null)
					{
						var i = 0;
						while (i < parent.children.length && !found)
						{
							found = recursiveAdd(path, stats, parent.children[i]);
							i++;
						}
					}
					return found;
				}
			}

			function recursiveRemove(path:String, parent:PanelItem)
			{
				if (parent.children == null) return;
				for (child in parent.children)
				{
					if (path == child.path)
					{
						parent.children.remove(child);
					}
					else if (child.children != null) for (c in child.children)
					{
						if (path == c.path) child.children.remove(c);
						recursiveRemove(path, c);
					}
				}
			}

			for(i in 0...paths.length)
			{
				items[i] = {
					path: paths[i],
					dirname: Path.dirname(paths[i]),
					children: FileSystem.stat(paths[i]).isDirectory() ? [] : null
				}

				watchers[i] = Chokidar.watch(paths[i], {depth: OGMO.project.directoryDepth })
				.on('add', (path:String, stats:Stats) ->
				{
					if (path != paths[i] && items[i].children != null) recursiveAdd(path, stats, items[i]);
				})
				.on('addDir', (path:String, stats:Stats) ->
				{
					if (path != paths[i] && items[i].children != null) recursiveAdd(path, stats, items[i]);
				})
				.on('change', (path:String, stats:Stats) ->
				{
					// TODO: use this event to notify user of opened level changes? - austin
				})
				.on('unlink', (path:String) ->
				{
					if (path != paths[i] && items[i].children != null) recursiveRemove(path, items[i]);
				})
				.on('unlinkDir', (path:String) ->
				{
					if (path != paths[i] && items[i].children != null) recursiveRemove(path, items[i]);
				});
			}
		}
		refresh();
	}

	override function refresh():Void
	{
		if (refreshTimer == null) refreshTimer = Browser.window.setTimeout(() ->
		{
			refreshTimer = null;
			if (levels == null) return;

			var scroll = levels.scrollTop();
			currentSearch = getSearchQuery();

			itemlist.empty();

			//Add unsaved levels
			unsavedFolder = new ItemListFolder("Unsaved Levels", ":Unsaved");
			unsavedFolder.setFolderIcons("folder-star-open", "folder-star-closed");
			unsavedFolder.onrightclick = inspectUnsavedFolder;
			itemlist.add(unsavedFolder);

			var unsaved = EDITOR.levelManager.getUnsavedLevels();
			if (unsaved.length > 0)
			{
				for (i in 0...unsaved.length)
				{
					var path = unsaved[i].managerPath;
					var item = new ItemListItem(unsaved[i].displayName, path);

					//Icon
					item.setKylesetIcon("radio-on");

					//Selected?
					if (EDITOR.level != null) item.selected = (EDITOR.level.managerPath == path);

					//Events
					item.onclick = selectLevel;
					item.onrightclick = inspectUnsavedLevel;

					unsavedFolder.add(item);
				}
			}

			//Add root folders if necessary, and recursively populate them
			if (OGMO.project != null) {
				for (panelItem in items)
				{
					panelItem.node = null;
					var path = panelItem.path;
					if (!FileSystem.exists(path))
					{
						var broken = panelItem.node = new ItemListFolder(Path.basename(path), path);
						broken.onrightclick = inspectBrokenFolder;
						broken.setFolderIcons("folder-broken", "folder-broken");
						itemlist.add(broken);
					}
					else if (panelItem.children != null)
					{
						function recursiveAdd(item:PanelItem, parent:PanelItem)
						{
							item.node = null;
							// if item's directory is the root folder, add to that
							if (item.dirname == parent.path)
							{
								var filename = EDITOR.levelManager.getDisplayName(item.path);
								if (item.children != null)
								{
									// Add Folder
									var foldernode = item.node = parent.node.add(new ItemListFolder(filename, item.path));
									// Events
									foldernode.onrightclick = inspectFolder;
								}
								else if (item.path != OGMO.project.path)
								{
									// Add File
									var filenode = item.node = parent.node.add(new ItemListItem(filename, item.path));
									// Events
									filenode.onclick = selectLevel;
									filenode.onrightclick = inspectLevel;
								}
							}
							// search for directory to add
							if (item.children != null) for (child in item.children) recursiveAdd(child, item);
						}

						var addTo = panelItem.node = itemlist.add(new ItemListFolder(Path.basename(path), path));
						addTo.onrightclick = inspectFolder;
						addTo.setFolderIcons("folder-dot-open", "folder-dot-closed");
						for (item in panelItem.children) recursiveAdd(item, panelItem);
					}
				}
				// Search or use remembered expand states
				if (currentSearch != "")
				{
					var i = itemlist.children.length - 1;
					while (i >= 0)
					{
						recursiveFilter(itemlist, itemlist.children[i], currentSearch);
						i--;
					}
				}
				else recursiveFolderExpandCheck(itemlist);

				//Sort folders to the top
				itemlist.foldersToTop(true);

				//Figure out labels and icons
				refreshLabelsAndIcons();
			}
		 }, 150);
	}

	public function refreshLabelsAndIcons():Void
	{
		//Set level icons and selected state
		itemlist.perform(function (node)
		{
			if (Std.is(node,ItemListItem))
			{
				node.label = EDITOR.levelManager.getDisplayName(node.data);
				var lev = EDITOR.levelManager.get(node.data);
				if (lev != null)
				{
					node.selected = (EDITOR.level != null && EDITOR.level.managerPath == node.data);
					if (lev.deleted) node.setKylesetIcon("level-broken");
					else node.setKylesetIcon("level-on");
				}
				else
				{
					node.selected = false;
					node.setKylesetIcon("level-off");
				}
			}
		});

		//Remove unsaved levels that aren't open (they're lost forever)
		if (unsavedFolder != null)
		{
			var i = unsavedFolder.children.length - 1;
			while (i >= 0)
			{
				if (!EDITOR.levelManager.isOpen(unsavedFolder.children[i].data)) unsavedFolder.removeAt(i);
				i--;
			}
		}

		//Expand folders that contain the selected level
		itemlist.performIfChildSelected(function (item)
		{
			item.expandNoSlide(true);
			opened[item.data] = true;
		});
	}

	function recursiveFolderExpandCheck(node: ItemListNode):Void
	{
			for (i in 0...node.children.length)
			{
				var n = node.children[i];
				if (Std.is(n, ItemListFolder))
				{
					// default to open?
					if (opened[n.data] != null) n.expandNoSlide(opened[n.data]);

					// Toggle opened flag
					if (n.children.length > 0)	n.onclick = function(current) { opened[n.data] = n.expanded; }

					recursiveFolderExpandCheck(n);
				}
			}
	}

	function recursiveFilter(parent:ItemListNode, node:ItemListNode, search:String):Bool
	{
		if (node.label.indexOf(search) != -1)
		{
			if (node.isFolder) node.expandNoSlide(true);
			return true;
		}
		else
		{
			var childMatch = false;
			var i = node.children.length - 1;
			while (i >= 0)
			{
				if (recursiveFilter(node, node.children[i], search)) childMatch = true;
				i--;
			}

			if (!childMatch) parent.remove(node);
			else if (node.isFolder) node.expandNoSlide(true);

			return childMatch;
		}
	}

	function getSearchQuery():String
	{
		return searchbar.find("input").val();
	}

	/*
		CLICKS
	*/

	function selectLevel(node: ItemListNode):Void
	{
		inline function openLevel(data:String) {
			EDITOR.levelManager.open(data, null,
			function (error)
			{
				Popup.open("Invalid Level File", "warning", "<span class='monospace'>" + Path.basename(data) + "</span> is not a valid level file!<br /><span class='monospace'>" + error + "</span>", ["Okay", "Delete It", "Open With Default Program"], function(i)
				{
					if (i == 2) Shell.openPath(data);
					else if (i == 1)
					{
						EDITOR.levelManager.delete(data);
						EDITOR.levelsPanel.refresh();
					}
				});
			});
		}

		inline function openImage(data:String) {
			var message = '<img src="file:${data}" style="display: block; margin: 0 auto;"/>';
			Popup.open('Image File: ' + Path.basename(data), "info", message, ["Okay", "Open With Default Program"], function(i)
			{
				if (i == 1) Shell.openPath(data);
			});
		}

		// open the level if its unsaved
		if ((cast node.data : String).indexOf('#') == 0) {
			openLevel(node.data);
			return;
		}

		var split = (cast node.data : String).split(".");

		switch (split[split.length -1]){
			default:
				Popup.open('Unsupported File Extension', 'warning', 'Ogmo can\'t open .${split[split.length -1]} files... Yet!', ["Okay", "Delete It", "Open With Default Program"], function(i)
				{
					if (i == 2) Shell.openPath(node.data);
					else if (i == 1)
					{
						EDITOR.levelManager.delete(node.data);
						EDITOR.levelsPanel.refresh();
					}
				});
			case "json":
			openLevel(node.data);
			case "png":
			openImage(node.data);
			case "jpg":
			openImage(node.data);
			case "jpeg":
			openImage(node.data);
		}
	}

	function inspectFolder(node: ItemListNode):Void
	{
		var menu = new RightClickMenu(OGMO.mouse);
		menu.onClosed(function() { node.highlighted = false; });

		menu.addOption("Create Level Here", "new-file", function()
		{
			//Get the default name
			var n = 0;
			var name:String;
			var path:String;
			do
			{
				name = "NewLevel" + n + OGMO.project.defaultExportMode;
				path = Path.join(node.data, name);
				n++;
			}
			while (FileSystem.exists(path));

			//Ask the user for a name
			Popup.openText("Create Level", "new-file", name, "Create", "Cancel", function (str)
			{
				if (str != null && str != "")
				{
					path = Path.join(node.data, str);
					if (FileSystem.exists(path))
					{
						Popup.open("Rename Folder", "warning", "A level named <span class='monospace'>" + str + "</span> already exists here. Delete it first or try a different name.", ["Okay"], null);
					}
					else
					{
						EDITOR.levelManager.create(function (level)
						{
							level.path = path;
							level.doSave();
						});
					}
				}
			}, 0, name.length - OGMO.project.defaultExportMode.length);
		});

		menu.addOption("Create Subfolder", "folder-closed", function()
		{
			Popup.openText("Create Subfolder", "folder-closed", "New Folder", "Create", "Cancel", function (str)
			{
				if (str != null && str != "")
				{
					Fs.mkdirSync(Path.join(node.data, str));
					EDITOR.levelsPanel.refresh();
				}
			});
		});

		menu.addOption("Rename Folder", "pencil", function()
		{
			Popup.openText("Rename Folder", "pencil", node.label, "Rename", "Cancel", function (str)
			{
				if (str != null && str != "")
				{
					var oldPath = node.data;
					var newPath = Path.join(Path.dirname(node.data), str);

					if (FileSystem.exists(newPath))
					{
						Popup.open("Rename Folder", "warning", "A folder named <span class='monospace'>" + str + "</span> already exists here. Delete it first or try a different name.", ["Okay"], null);
					}
					else
					{
						Fs.renameSync(oldPath, newPath);
						EDITOR.levelManager.onFolderRename(oldPath, newPath);
						OGMO.project.renameAbsoluteLevelPathAndSave(oldPath, newPath);
						EDITOR.levelsPanel.refresh();
					}
				}
			});
		});

		if (OGMO.project.levelPaths.length > 1)
		{
			menu.addOption("Delete Folder", "trash", function()
			{
				Popup.open("Delete Folder", "trash", "Permanently delete <span class='monospace'>" + node.label + "</span> and all of its contents? This cannot be undone!", ["Delete", "Cancel"], function (i)
				{
					if (i == 0)
					{
						FileSystem.removeFolder(node.data);

						EDITOR.levelManager.onFolderDelete(node.data);
						OGMO.project.removeAbsoluteLevelPathAndSave(node.data);
						EDITOR.levelsPanel.refresh();
					}
				});
			});
		}

		//Explore
		{
			menu.addOption("Explore", "folder-open", function()
			{
				Shell.openPath(node.data);
			});
		}

		node.highlighted = true;
		menu.open();
	}

	function inspectUnsavedFolder(node: ItemListNode):Void
	{
		var menu = new RightClickMenu(OGMO.mouse);
		menu.onClosed(function() { node.highlighted = false; });

		menu.addOption("Create Level", "new-file", function()
		{
			EDITOR.levelManager.create();
			EDITOR.levelsPanel.refresh();
		});

		node.highlighted = true;
		menu.open();
	}

	function inspectBrokenFolder(node: ItemListNode):Void
	{
		var menu = new RightClickMenu(OGMO.mouse);
		menu.onClosed(function() { node.highlighted = false; });

		menu.addOption("Recreate Missing Folder", "folder-closed", function()
		{
			Fs.mkdirSync(node.data);
			EDITOR.levelsPanel.refresh();
		});

		if (OGMO.project.levelPaths.length > 1)
		{
			menu.addOption("Remove From Project", "trash", function()
			{
				OGMO.project.removeAbsoluteLevelPathAndSave(node.data);
				EDITOR.levelsPanel.refresh();
			});
		}

		node.highlighted = true;
		menu.open();
	}

	function inspectUnsavedLevel(node:ItemListNode):Void
	{
		var level = EDITOR.levelManager.get(node.data);
		var menu = new RightClickMenu(OGMO.mouse);
		menu.onClosed(function() { node.highlighted = false; });

		menu.addOption("Close Level", "no", function()
		{
			EDITOR.levelManager.close(level);
		});

		node.highlighted = true;
		menu.open();
	}

	function inspectLevel(node:ItemListNode):Void
	{
		var menu = new RightClickMenu(OGMO.mouse);
		menu.onClosed(function() { node.highlighted = false; });

		var name = node.label;
		if (name.charAt(name.length - 1) == "*") name = name.substr(0, name.length - 1);

		if (EDITOR.levelManager.isOpen(node.data))
		{
			menu.addOption("Close", "no", function()
			{
				var level = EDITOR.levelManager.get(node.data);
				if (level != null) EDITOR.levelManager.close(level);
			});
		}

		menu.addOption("Rename", "pencil", function()
		{
			var endSel = name.lastIndexOf(".");
			if (endSel == -1) endSel = null;

			Popup.openText("Rename Level", "pencil", name, "Rename", "Cancel", function (str)
			{
				if (str != null && str != "")
				{
					var oldPath = node.data;
					var newPath = Path.join(Path.dirname(oldPath), str);

					var rename = function(from:String, to:String)
					{
						Fs.renameSync(from, to);
						EDITOR.levelManager.onLevelRename(from, to);
					};

					var swap = function()
					{
						var temp = newPath + "-temp";
						rename(oldPath, temp);
						rename(newPath, oldPath);
						rename(temp, newPath);
					}

					var finalize = function()
					{
						EDITOR.levelsPanel.refresh();
						OGMO.updateWindowTitle();
					}

					if (FileSystem.exists(newPath))
					{
						var base = Path.basename(newPath);
						Popup.open("Level already exists!", "warning", "<span class='monospace'>" + base + "</span> already exists! What do you want to do?", ["Swap Names", "Overwrite", "Cancel"], function (i)
						{
							if (i == 0)
							{
								swap();
								finalize();
							}
							else if (i == 1)
							{
								rename(oldPath, newPath);
								finalize();
							}
						});
					}
					else
					{
						rename(oldPath, newPath);
						finalize();
					}
				}
			}, 0, endSel);
		});

		menu.addOption("Duplicate", "new-file", function()
		{
			var ext:String = Path.extname(node.data);
			var base:String = Path.basename(node.data, ext);
			var dir:String = Path.dirname(node.data);
			var check = 0;
			var add:String;
			var save:String;

			//Figure out the save name
			do
			{
				add = "-copy" + check;
				check++;
				save = Path.join(dir, base + add + ext);
			}
			while (FileSystem.exists(save));

			//Save it!
			Fs.createReadStream(node.data).pipe(Fs.createWriteStream(save));

			//Refresh
			EDITOR.levelsPanel.refresh();
		});

		if (EDITOR.levelManager.isOpen(node.data))
		{
			menu.addOption("Properties", "gear", function()
			{
				var level = EDITOR.levelManager.get(node.data);
				if (level != null) Popup.openLevelProperties(level);
			});
		}

		menu.addOption("Delete", "trash", function()
		{
			Popup.open("Delete Level", "trash", "Permanently delete <span class='monospace'>" + name + "</span>? This cannot be undone!", ["Delete", "Cancel"], function (i)
			{
				if (i == 0)
				{
					EDITOR.levelManager.delete(node.data);
					EDITOR.levelsPanel.refresh();
				}
			});
		});

		menu.addOption("Open in Text Editor", "book", function()
		{
			Shell.openPath(node.data);
		});

		if (EDITOR.levelManager.isOpen(node.data))
		{
			menu.addOption("Save as Image", "image", function()
			{
				EDITOR.saveLevelAsImage();
			});
		}

		node.highlighted = true;
		menu.open();
	}
}
