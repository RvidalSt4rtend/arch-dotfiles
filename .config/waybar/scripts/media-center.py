#!/usr/bin/env python3
"""media-center.py — GTK4 layer-shell popup for MPRIS media control.

A floating overlay window (layer-shell, no taskbar entry, no focus steal)
that shows the current playing track with album art (when available),
title/artist, and prev / play-pause / next buttons. Updates live via
`playerctl --all-players --follow metadata`.

Toggle visibility by sending SIGUSR1 to the running process (see
media-toggle.sh bound to a Hyprland key).

Requires: python-gobject, gtk4, gtk4-layer-shell, playerctl.
"""

import os
import signal
import sys
import urllib.request
import tempfile

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf, Gtk4LayerShell as Layer


# ---- palette (matches waybar/swaync) ----
BG        = "rgba(10, 12, 18, 0.92)"
BG_ALT    = "rgba(20, 22, 30, 0.8)"
FG        = "#c0caf5"
DIM       = "#565f89"
ACCENT    = "#00c8c8"
FONT      = '"JetBrains Mono Nerd Font", "Noto Sans", sans-serif'

PLAYERCTL_FMT = "{{playerName}}\t{{status}}\t{{title}}\t{{artist}}\t{{mpris:artUrl}}"


def run(cmd):
    """Spawn a shell command detached."""
    try:
        GLib.spawn_async(
            ["sh", "-c", cmd],
            flags=GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
        )
    except Exception as e:
        print(f"spawn err: {e}", file=sys.stderr)


def fetch_image(url):
    """Return a local path for an art URL (file:// or http(s)://), or None."""
    if not url:
        return None
    if url.startswith("file://"):
        path = url[len("file://"):]
        return path if os.path.exists(path) else None
    if url.startswith(("http://", "https://")):
        try:
            fd, tmp = tempfile.mkstemp(suffix=".art")
            os.close(fd)
            urllib.request.urlretrieve(url, tmp)
            return tmp
        except Exception:
            return None
    return None


class MediaCenter(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="ardal.media-center")

    def do_activate(self):
        win = MediaWindow()
        self.add_window(win)
        win.present()
        # start with no player content; populate once playerctl fires
        win.update_empty()


class MediaWindow(Gtk.ApplicationWindow):
    def __init__(self):
        super().__init__()
        self.set_title("Media Center")
        self.set_default_size(360, 480)

        # ---- layer-shell setup ----
        Layer.init_for_window(self)
        Layer.set_layer(self, Layer.Layer.TOP)
        Layer.set_anchor(self, Layer.Edge.TOP, True)
        Layer.set_anchor(self, Layer.Edge.RIGHT, True)
        Layer.set_margin(self, Layer.Edge.TOP, 36)
        Layer.set_margin(self, Layer.Edge.RIGHT, 12)
        Layer.set_keyboard_mode(self, Layer.KeyboardMode.ON_DEMAND)
        # close on Escape
        ctrl = Gtk.EventControllerKey()
        ctrl.connect("key-pressed", self._on_key)
        self.add_controller(ctrl)

        # ---- build UI ----
        css = Gtk.CssProvider()
        css.load_from_string(f"""
            window {{
                background: {BG};
                border-radius: 12px;
                border: 1px solid rgba(0, 200, 200, 0.3);
                color: {FG};
            }}
            .art   {{ border-radius: 10px; }}
            .title {{ font-family: {FONT}; font-size: 16px; font-weight: bold; color: {FG}; }}
            .artist{{ font-family: {FONT}; font-size: 13px; color: {DIM}; }}
            .ctrl  {{ font-family: {FONT}; font-size: 20px; color: {FG};
                      background: {BG_ALT}; border-radius: 10px;
                      padding: 6px 14px; min-width: 40px; }}
            .ctrl:hover {{ color: {ACCENT}; background: rgba(0,200,200,0.15); }}
            .player {{ font-family: {FONT}; font-size: 10px; color: {DIM}; }}
            .placeholder {{
                font-family: {FONT}; font-size: 96px; color: {DIM};
                padding: 64px 0;
            }}
            .empty {{ font-family: {FONT}; font-size: 14px; color: {DIM};
                      padding: 80px 16px; }}
        """)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        outer.set_margin_top(12); outer.set_margin_bottom(12)
        outer.set_margin_start(14); outer.set_margin_end(14)
        self.set_child(outer)

        # player name (small)
        self.player_label = Gtk.Label(label="")
        self.player_label.add_css_class("player")
        self.player_label.set_halign(Gtk.Align.END)
        outer.append(self.player_label)

        # art image
        self.art = Gtk.Picture()
        self.art.set_size_request(220, 220)
        self.art.set_halign(Gtk.Align.CENTER)
        self.art.add_css_class("art")
        outer.append(self.art)

        # placeholder shown when no art
        self.placeholder = Gtk.Label(label="󰝚")
        self.placeholder.add_css_class("placeholder")
        self.placeholder.set_halign(Gtk.Align.CENTER)
        outer.append(self.placeholder)

        # title / artist
        self.title_label = Gtk.Label(label="")
        self.title_label.add_css_class("title")
        self.title_label.set_halign(Gtk.Align.CENTER)
        self.title_label.set_justify(Gtk.Justification.CENTER)
        self.title_label.set_wrap(True)
        self.title_label.set_max_width_chars(28)
        outer.append(self.title_label)

        self.artist_label = Gtk.Label(label="")
        self.artist_label.add_css_class("artist")
        self.artist_label.set_halign(Gtk.Align.CENTER)
        outer.append(self.artist_label)

        # spacer
        outer.append(Gtk.Box())

        # controls row
        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        controls.set_halign(Gtk.Align.CENTER)
        outer.append(controls)

        self.btn_prev = Gtk.Button(label="󰒮")
        self.btn_play = Gtk.Button(label="󰝚")
        self.btn_next = Gtk.Button(label="󰒭")
        for b in (self.btn_prev, self.btn_play, self.btn_next):
            b.add_css_class("ctrl")
            controls.append(b)
        self.btn_prev.connect("clicked", lambda *_: run("playerctl previous"))
        self.btn_play.connect("clicked", lambda *_: run("playerctl play-pause"))
        self.btn_next.connect("clicked", lambda *_: run("playerctl next"))

        # track state
        self._watch = None
        self._has_art = False
        self._poll()

        # SIGUSR1 → toggle visibility
        signal.signal(signal.SIGUSR1, self._on_sigusr1)

    # ---- visibility toggle ----
    def _on_sigusr1(self, *_):
        GLib.idle_add(self._toggle_visible)

    def _toggle_visible(self):
        self.set_visible(not self.get_visible())

    # ---- escape to hide ----
    def _on_key(self, _ctrl, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            self.set_visible(False)
            return True
        return False

    # ---- playerctl --follow poller ----
    def _poll(self):
        """Spawn playerctl --all-players --follow and pipe updates via io watch."""
        try:
            argv = ["playerctl", "--all-players", "--follow", "metadata",
                    "--format", PLAYERCTL_FMT]
            flags = GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.STDIN_FROM_DEV_NULL
            pid, stdin, stdout, stderr = GLib.spawn_async(
                argv, flags=flags,
                standard_output=True, standard_error=True)
            if stdin is not None:
                os.close(stdin)
            self._stdout_fd = stdout
            self._watch = GLib.io_add_watch(
                self._stdout_fd, GLib.IO_IN | GLib.IO_HUP, self._on_metadata)
        except Exception as e:
            print(f"playerctl spawn err: {e}", file=sys.stderr)
            self.update_empty()

    def _on_metadata(self, _fd, cond):
        if cond & GLib.IO_HUP:
            return False
        try:
            line = os.read(self._stdout_fd, 4096).decode("utf-8", "replace")
        except Exception:
            return True
        # playerctl --follow emits multiple lines per change; pick the LAST one that parses
        line = line.strip()
        if not line:
            return True
        # take last non-empty line in the chunk
        parts = line.splitlines()[-1].split("\t")
        if len(parts) < 5:
            return True
        player, status, title, artist, arturl = parts[:5]
        self.update_track(player, status, title, artist, arturl)
        return True

    # ---- UI state refresh ----
    def update_track(self, player, status, title, artist, arturl):
        self.player_label.set_label(f"{player} · {status}")
        self.title_label.set_label(title or "(no title)")
        self.artist_label.set_label(artist or "")
        self.btn_play.set_label("󰏥" if status == "Playing" else "󰝚")
        # art
        path = fetch_image(arturl)
        if path:
            try:
                texture = Gdk.Texture.new_from_filename(path)
                self.art.set_paintable(texture)
                self.art.set_visible(True)
                self.placeholder.set_visible(False)
                self._has_art = True
            except Exception:
                self._set_placeholder()
        else:
            self._set_placeholder()
        # cleanup temp http arts
        if path and arturl.startswith(("http://", "https://")):
            def _del():
                try: os.unlink(path)
                except Exception: pass
                return False
            GLib.timeout_add_seconds(60, _del)
        self.set_visible(True)

    def update_empty(self):
        self.player_label.set_label("no player")
        self.title_label.set_label("")
        self.artist_label.set_label("")
        self._set_placeholder()
        self.btn_play.set_label("󰝚")

    def _set_placeholder(self):
        self.art.set_paintable(None)
        self.art.set_visible(False)
        self.placeholder.set_visible(True)
        self._has_art = False


def main():
    app = MediaCenter()
    app.run(sys.argv)


if __name__ == "__main__":
    main()