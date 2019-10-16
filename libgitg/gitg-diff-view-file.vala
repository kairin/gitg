/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-file.ui")]
class Gitg.DiffViewFile : Gtk.Grid
{
	[GtkChild( name = "expander" )]
	private unowned Gtk.Expander d_expander;

	[GtkChild( name = "label_file_header" )]
	private unowned Gtk.Label d_label_file_header;

	[GtkChild( name = "diff_stat_file" )]
	private unowned DiffStat d_diff_stat_file;

	[GtkChild( name = "revealer_content" )]
	private unowned Gtk.Revealer d_revealer_content;

	[GtkChild( name = "stack_switcher" )]
	private unowned Gtk.StackSwitcher? d_stack_switcher;

	[GtkChild( name = "stack_file_renderer" )]
	private unowned Gtk.Stack? d_stack_file_renderer;

	private bool d_expanded;

	public DiffViewFileRendererText? renderer_text {get; private set;}

	public void add_renderer(Gtk.Widget widget, string name, string title)
	{
		d_stack_file_renderer.add_titled(widget, name, title);
		bool visible = d_stack_file_renderer.get_children().length() > 1;
		d_stack_switcher.set_visible(visible);
	}

	public bool new_is_workdir { get; construct set; }

	public bool expanded
	{
		get
		{
			return d_expanded;
		}

		set
		{
			if (d_expanded != value)
			{
				d_expanded = value;
				d_revealer_content.reveal_child = d_expanded;

				var ctx = get_style_context();

				if (d_expanded)
				{
					ctx.add_class("expanded");
				}
				else
				{
					ctx.remove_class("expanded");
				}
			}
		}
	}

	public DiffViewFileInfo? info {get; construct set;}

	public DiffViewFile(DiffViewFileInfo? info)
	{
		Object(info: info);
		bind_property("vexpand", d_stack_file_renderer, "vexpand", BindingFlags.SYNC_CREATE);
	}

	public void add_text_renderer(bool handle_selection)
	{
		renderer_text = new DiffViewFileRendererText(info, handle_selection);
		renderer_text.show();
		var scrolled_window = new Gtk.ScrolledWindow (null, null);
		scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
		scrolled_window.add(renderer_text);
		scrolled_window.show();

		renderer_text.bind_property("added", d_diff_stat_file, "added");
		renderer_text.bind_property("removed", d_diff_stat_file, "removed");
		add_renderer(scrolled_window, "text", _("Text"));
	}

	public void add_binary_renderer()
	{
		var renderer = new DiffViewFileRendererBinary();
		renderer.show();
		add_renderer(renderer, "binary", _("Binary"));

		//TODO: Only for text page
		//d_diff_stat_file.hide();
	}

	public void add_image_renderer()
	{
		var renderer = new DiffViewFileRendererImage(info.repository, info.delta);
		renderer.show();
		add_renderer(renderer, "image", _("Image"));

		//TODO: Only for text page
		//d_diff_stat_file.hide();
	}

	protected override void constructed()
	{
		base.constructed();

		var delta = info.delta;
		var oldfile = delta.get_old_file();
		var newfile = delta.get_new_file();

		var oldpath = (oldfile != null ? oldfile.get_path() : null);
		var newpath = (newfile != null ? newfile.get_path() : null);

		if (delta.get_similarity() > 0)
		{
			d_label_file_header.label = @"$(newfile.get_path()) ← $(oldfile.get_path())";
		}
		else if (newpath != null)
		{
			d_label_file_header.label = newpath;
		}
		else
		{
			d_label_file_header.label = oldpath;
		}

		d_expander.bind_property("expanded", this, "expanded", BindingFlags.BIDIRECTIONAL);

		var repository = info.repository;
		if (repository != null && !repository.is_bare)
		{
			d_expander.popup_menu.connect(expander_popup_menu);
			d_expander.button_press_event.connect(expander_button_press_event);
		}
	}

	private void show_popup(Gdk.EventButton? event)
	{
		var menu = new Gtk.Menu();

		var delta  = info.delta;
		var oldpath = delta.get_old_file().get_path();
		var newpath = delta.get_new_file().get_path();

		var open_file = new Gtk.MenuItem.with_mnemonic(_("_Open file"));
		open_file.show();

		File? location = null;

		var repository = info.repository;
		if (newpath != null && newpath != "")
		{
			location = repository.get_workdir().get_child(newpath);
		}
		else if (oldpath != null && oldpath != "")
		{
			location = repository.get_workdir().get_child(oldpath);
		}

		if (location == null)
		{
			return;
		}

		open_file.activate.connect(() => {
			try
			{
				Gtk.show_uri(d_expander.get_screen(), location.get_uri(), Gdk.CURRENT_TIME);
			}
			catch (Error e)
			{
				stderr.printf(@"Failed to open file: $(e.message)\n");
			}
		});

		menu.add(open_file);

		var open_folder = new Gtk.MenuItem.with_mnemonic(_("Open containing _folder"));
		open_folder.show();

		open_folder.activate.connect(() => {
			try
			{
				Gtk.show_uri(d_expander.get_screen(), location.get_parent().get_uri(), Gdk.CURRENT_TIME);
			}
			catch (Error e)
			{
				stderr.printf(@"Failed to open folder: $(e.message)\n");
			}
		});

		menu.add(open_folder);

		var separator = new Gtk.SeparatorMenuItem();
		separator.show();
		menu.add(separator);

		var copy_file_path = new Gtk.MenuItem.with_mnemonic(_("_Copy file path"));
		copy_file_path.show();

		copy_file_path.activate.connect(() => {
			var clip = d_expander.get_clipboard(Gdk.SELECTION_CLIPBOARD);
			clip.set_text(location.get_path(), -1);
		});

		menu.add(copy_file_path);

		menu.attach_to_widget(d_expander, null);
		menu.popup_at_pointer(event);
	}

	private bool expander_button_press_event(Gtk.Widget widget, Gdk.EventButton? event)
	{
		if (event.triggers_context_menu())
		{
			show_popup(event);
			return true;
		}

		return false;
	}

	private bool expander_popup_menu(Gtk.Widget widget)
	{
		show_popup(null);
		return true;
	}

	public void add_hunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		if (renderer_text != null) {
			renderer_text.add_hunk(hunk, lines);
		}
		foreach (Gtk.Widget page in d_stack_file_renderer.get_children())
		{
			if (page is DiffViewFileRenderer)
			{
				var renderer = (DiffViewFileRenderer)page;
				renderer.add_hunk(hunk, lines);
			}
		}
	}
}

// ex:ts=4 noet
