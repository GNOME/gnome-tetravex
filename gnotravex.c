/* -*- mode:C; indent-tabs-mode: nil; tab-width: 8; c-basic-offset: 2; -*- */

/* 
 *   Gnome Tetravex: Tetravex clone
 *   Written by Lars Rydlinge <lars.rydlinge@hig.se>
 * 
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <config.h>
#include <gnome.h>
#include <string.h>
#include <libgnomeui/gnome-window-icon.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <games-clock.h>
#include <time.h>
#include <gconf/gconf-client.h>

#define APPNAME "gnotravex"
#define APPNAME_LONG "GNOME Tetravex"

/* This is based on the point where the numbers become unreadable on my
 * screen at 3x3. - Callum */
#define MINIMUM_TILE_SIZE 40

#define RELEASE 4
#define PRESS 3
#define MOVING 2
#define UNUSED 1
#define USED 0

#define KEY_GRID_SIZE "/apps/gnotravex/grid_size"
#define KEY_WINDOW_WIDTH "/apps/gnotravex/width"
#define KEY_WINDOW_HEIGHT "/apps/gnotravex/height"

GtkWidget *window;
GtkWidget *statusbar;
GtkWidget *space;
GtkWidget *bit;
GtkWidget *timer;

int xborder;
int yborder;
int gap;

GdkPixmap *buffer = NULL;

GConfClient *gconf_client;

typedef struct _mover {
  GdkWindow *window;
  GdkPixmap *pixmap;
  gint xstart, ystart;
  gint xtarget, ytarget;
  gint xoff, yoff;
} Mover;

Mover mover;

typedef struct _tile {
  gint n, w, e, s;
  gint status;
} tile;

tile tiles[9][18];
tile orig_tiles[9][9];

enum {
  gameover,
  paused,
  playing,
};

gint size = 3;
gint game_state = gameover;
gint have_been_hinted = 0;
gint solve_me = 0;
gint hint_moving = 0;
gint session_flag = 0;
gint session_xpos = 0;
gint session_ypos = 0;
gint session_position = 0;
guint timer_timeout = 0;
gint tile_size = 0;

void make_buffer (GtkWidget *);
void create_window (void);
void create_menu (void);
void create_space (void);
void create_mover (void);
void create_statusbar (void);

gint expose_space (GtkWidget *, GdkEventExpose *);
gint button_press_space (GtkWidget *, GdkEventButton *);
gint button_release_space (GtkWidget *, GdkEventButton *);
gint button_motion_space (GtkWidget *, GdkEventButton *);

void gui_draw_piece (GdkPixmap *, GdkGC *, gboolean, gint, gint);
void gui_draw_text_int (GdkPixmap *, GdkGC *, gint, gint, gint);
void gui_draw_pixmap (GdkPixmap *, gint, gint);
void gui_draw_pause (void);

void get_pixeltilexy (gint, gint, gint *, gint *);
void get_tilexy (gint, gint, gint *, gint *);
void get_offsetxy (gint, gint, gint *, gint *);
GdkColor *get_bg_color (void);

void message (gchar *);
void new_board (gint);
void redraw_all (void);
void redraw_left (void);
gint setup_mover (gint, gint, gint);
gint valid_drop (gint, gint);

void update_tile_size (gint, gint);
gint configure_space (GtkWidget *, GdkEventConfigure *);
gint compare_tile (tile *, tile *);
void find_first_tile (gint, gint *, gint *);
void move_tile (gint, gint, gint, gint);
void move_column (unsigned char);
gint game_over (void);
void game_score (void);
void update_score_state (void);
gint timer_cb (void);
void timer_start (void);
void pause_game (void);
void resume_game (void);
void pause_cb (void);
void hint_move_cb (void);
void hint_move (gint, gint, gint, gint);
void show_score_dialog (const gchar *, gint);
static gint save_state (GnomeClient*, gint, GnomeRestartStyle,
                        gint, GnomeInteractStyle, gint, gpointer);

/* ------------------------- MENU ------------------------ */
void new_game_cb (GtkWidget *, gpointer);
void quit_game_cb (GtkWidget *, gpointer);
void size_cb (GtkWidget *, gpointer);
void move_cb (GtkWidget *, gpointer);
void about_cb (GtkWidget *, gpointer);
void score_cb (GtkWidget *, gpointer);
void hint_cb (GtkWidget *, gpointer);
void solve_cb (GtkWidget *, gpointer);

GnomeUIInfo game_menu[] = {
  GNOMEUIINFO_MENU_NEW_GAME_ITEM (new_game_cb, NULL),

  GNOMEUIINFO_MENU_PAUSE_GAME_ITEM (pause_cb, NULL),

  GNOMEUIINFO_SEPARATOR,

  GNOMEUIINFO_MENU_HINT_ITEM (hint_cb, NULL),

  { GNOME_APP_UI_ITEM, N_("Sol_ve"), N_("Solve the game"),
    solve_cb, NULL, NULL,GNOME_APP_PIXMAP_STOCK,
    GTK_STOCK_REFRESH, 0, 0, NULL },

  GNOMEUIINFO_SEPARATOR,

  GNOMEUIINFO_MENU_SCORES_ITEM (score_cb, NULL),

  GNOMEUIINFO_SEPARATOR,

  GNOMEUIINFO_MENU_QUIT_ITEM (quit_game_cb, NULL),

  GNOMEUIINFO_END
};

GnomeUIInfo size_radio_list[] = {
  { GNOME_APP_UI_ITEM, N_("_2x2"), N_("Play on a 2x2 board"),
    size_cb, "2", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },

  { GNOME_APP_UI_ITEM, N_("_3x3"), N_("Play on a 3x3 board"),
    size_cb, "3", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },

  { GNOME_APP_UI_ITEM, N_("_4x4"), N_("Play on a 4x4 board"),
    size_cb, "4", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },

  { GNOME_APP_UI_ITEM, N_("_5x5"), N_("Play on a 5x5 board"),
    size_cb, "5", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },

  { GNOME_APP_UI_ITEM, N_("_6x6"), N_("Play on a 6x6 board"),
    size_cb, "6", NULL, GNOME_APP_PIXMAP_DATA, NULL, 0, 0, NULL },

  GNOMEUIINFO_END
};

GnomeUIInfo move_menu[] = {
  {GNOME_APP_UI_ITEM, N_("_Up"), N_("Move the pieces up"),
   move_cb, "n", NULL, GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

  {GNOME_APP_UI_ITEM, N_("_Left"), N_("Move the pieces left"),
   move_cb, "w", NULL, GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

  {GNOME_APP_UI_ITEM, N_("_Right"), N_("Move the pieces right"),
   move_cb, "e", NULL, GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

  {GNOME_APP_UI_ITEM, N_("_Down"), N_("Move the pieces down"),
   move_cb, "s", NULL, GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

  GNOMEUIINFO_END
};

GnomeUIInfo help_menu[] = {
  GNOMEUIINFO_HELP ("gnotravex"),
  GNOMEUIINFO_MENU_ABOUT_ITEM (about_cb, NULL),
  GNOMEUIINFO_END
};

GnomeUIInfo settings_menu[] = {
  GNOMEUIINFO_RADIOLIST (size_radio_list),
  GNOMEUIINFO_END
};

GnomeUIInfo main_menu[] = {
  GNOMEUIINFO_MENU_GAME_TREE (game_menu),
  GNOMEUIINFO_SUBTREE (N_("_Move"), move_menu),
  GNOMEUIINFO_MENU_SETTINGS_TREE (settings_menu),
  GNOMEUIINFO_MENU_HELP_TREE (help_menu),
  GNOMEUIINFO_END
};

static const struct poptOption options[] = {
  {NULL, 'x', POPT_ARG_INT, &session_xpos, 0, NULL, NULL},
  {NULL, 'y', POPT_ARG_INT, &session_ypos, 0, NULL, NULL},
  { "size", 's', POPT_ARG_INT, &size,0,
    N_("Size of board (2-6)"),
    N_("SIZE") },
  { NULL, '\0', 0, NULL, 0 }
};

/* ------------------------------------------------------- */

int 
main (int argc, char **argv)
{
  GnomeClient *client;

  gnome_score_init (APPNAME);

  bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
  bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
  textdomain (GETTEXT_PACKAGE);

  gnome_program_init (APPNAME, VERSION,
      		      LIBGNOMEUI_MODULE, 
       		      argc, argv,
       		      GNOME_PARAM_POPT_TABLE, options,
       		      GNOME_PARAM_APP_DATADIR, DATADIR, NULL);
     
  gnome_window_icon_set_default_from_file (GNOME_ICONDIR"/gnome-gnotravex.png");
  client = gnome_master_client ();
  g_object_ref (G_OBJECT (client));
  
  g_signal_connect (G_OBJECT (client), "save_yourself",
                    G_CALLBACK (save_state), argv[0]);
  g_signal_connect (G_OBJECT (client), "die",
                    G_CALLBACK (quit_game_cb), argv[0]);

  gconf_client = gconf_client_get_default();

  size = gconf_client_get_int (gconf_client, KEY_GRID_SIZE, NULL);
  if (size < 2 || size > 6) 
    size = 3;

  create_window ();
  create_menu ();

  create_space (); 
  create_statusbar ();

  update_score_state ();

  if (session_xpos >= 0 && session_ypos >= 0)
    gtk_window_move (GTK_WINDOW (window), session_xpos, session_ypos);
    
  gtk_widget_show_all (window);
  create_mover ();

  new_game_cb (space,NULL);
  
  gtk_check_menu_item_set_active (GTK_CHECK_MENU_ITEM (size_radio_list[size-2].widget),TRUE);

  gtk_main ();
  
  return 0;
}

/* Enable or disable the game menu items that are only relevant
 * during a game. */
static
void set_game_menu_items_sensitive (gboolean state)
{
  gtk_widget_set_sensitive (game_menu[1].widget, state);
  gtk_widget_set_sensitive (game_menu[3].widget, state);
  gtk_widget_set_sensitive (game_menu[4].widget, state);
}

/* Show only valid options in the move menu. */
static
void update_move_menu_sensitivity (void)
{
  int x,y;
  gboolean clear;
  gboolean n, w, e, s;
  
  n = w = e = s = TRUE;

  clear = TRUE;
  for (x = 0; x < size; x++) {
    if (tiles[0][x].status == USED)
      n = FALSE;
    if (tiles[x][0].status == USED)
      w = FALSE;
    if (tiles[x][size-1].status == USED)
      e = FALSE;
    if (tiles[size-1][x].status == USED)
      s = FALSE;
    for (y = 0; y<size; y++)
      if (tiles[x][y].status == USED)
        clear = FALSE;
  }

  if (clear) /* Can't move nothing. */
    n = w = e = s = FALSE;
  
  gtk_widget_set_sensitive (move_menu[0].widget, n);
  gtk_widget_set_sensitive (move_menu[1].widget, w);
  gtk_widget_set_sensitive (move_menu[2].widget, e);
  gtk_widget_set_sensitive (move_menu[3].widget, s);
}

static gint
get_window_width (void)
{
  int width;
  int screen_width;
  
  width = gconf_client_get_int (gconf_client, KEY_WINDOW_WIDTH, NULL);
  if (width < 320)
    width = 320;
  screen_width = gdk_screen_get_width (gtk_window_get_screen (GTK_WINDOW (window)));
  if (width > screen_width)
    width = screen_width;
  
  return width;
}

static gint
get_window_height (void)
{
  int height;
  int screen_height;

  height = gconf_client_get_int (gconf_client, KEY_WINDOW_HEIGHT, NULL);
  if (height < 240)
    height = 240;
  screen_height = gdk_screen_get_height (gtk_window_get_screen (GTK_WINDOW (window)));
  if (height > screen_height)
    height = screen_height;
  
  return height;
}

void
create_window (void)
{
  window = gnome_app_new (APPNAME, N_(APPNAME_LONG));
  gtk_window_set_resizable (GTK_WINDOW (window), TRUE);
  gtk_widget_set_size_request (window, 320, 240);
  gtk_window_set_default_size (GTK_WINDOW (window), get_window_width (),
                               get_window_height ());
  gtk_widget_realize (window);
  g_signal_connect (G_OBJECT (window), "delete_event",
                    G_CALLBACK (quit_game_cb), NULL);
}

gint
expose_space (GtkWidget *widget, GdkEventExpose *event)
{ 
  gdk_draw_drawable (widget->window, 
                     widget->style->fg_gc[GTK_WIDGET_STATE (widget)], 
                     buffer, event->area.x, event->area.y, 
                     event->area.x, event->area.y, 
                     event->area.width, event->area.height);
  return FALSE; 
}

gint button_down = 0;

gint
button_press_space (GtkWidget *widget, GdkEventButton *event)
{
  if (game_state == paused) {
    resume_game ();
  }
  if (game_state == playing) {
    if (event->button == 1) {
      if (button_down == 1) {
	setup_mover (event->x,event->y, RELEASE); /* Seen it happened */
	button_down = 0;
	return FALSE;
      }
      if (setup_mover (event->x, event->y, PRESS)) {
	button_down = 1;
      }
    }
  }
  return FALSE;
}

gint
button_release_space (GtkWidget *widget, GdkEventButton *event)
{ 
  if (event->button == 1) {
    if (button_down==1) {
      setup_mover (event->x,event->y,RELEASE);
    }
    button_down = 0;
  }
  return FALSE;
}

gint
button_motion_space (GtkWidget *widget, GdkEventButton *event)
{
  gint x,y;
  
  if (button_down == 1) {
    x = event->x - mover.xoff;
    y = event->y - mover.yoff;
    gdk_window_move (mover.window, x, y);
    gdk_window_clear (mover.window);
  }
  return FALSE;
}

void
gui_draw_piece (GdkPixmap *target, GdkGC *gc,
                gboolean which, gint xadd, gint yadd)
{
  GtkStyle *style;
  GdkColor fg_color;
  GdkColor highlight_color;
  GdkColor shadow_color;
  GdkColormap *cmap;
  gint line_thickness = 3;
  gint shadow_offset;
  gint i;
  GdkColor *bg_color;

  style = gtk_widget_get_style (space);
  fg_color = style->fg[GTK_STATE_NORMAL];
  gdk_color_parse ("white", &highlight_color);
  gdk_color_parse ("#666666", &shadow_color);
  cmap = gtk_widget_get_colormap (space);
  gdk_colormap_alloc_color (cmap, &highlight_color,
			    FALSE, TRUE);
  gdk_colormap_alloc_color (cmap, &shadow_color,
                            FALSE, TRUE);

  /* Blank the piece */
  bg_color = get_bg_color ();
  gdk_gc_set_foreground (gc, bg_color);
  gdk_color_free (bg_color);
  gdk_draw_rectangle (target, gc, TRUE, xadd, yadd,
                      tile_size, tile_size);
  /* Draw outline */
  gdk_gc_set_foreground (gc, &fg_color);
  gdk_draw_rectangle (target, gc, FALSE, xadd, yadd,
                      tile_size-1, tile_size-1);

  /* shadow offset exposes fg color border around used pieces */
  shadow_offset = (which == USED) ? 1 : 0;

  if (which == USED) {
    /* Draw crossed lines */
    gdk_gc_set_foreground (gc, &shadow_color);
    for (i = 0; i < line_thickness; i++) {
      gdk_draw_line (target, gc,
                     xadd + shadow_offset,
                     yadd + i + shadow_offset,
                     xadd + tile_size - 1 - i - shadow_offset,
                     yadd + tile_size - 1 - shadow_offset);
      gdk_draw_line (target, gc,
                     xadd + shadow_offset,
                     yadd + tile_size - 1 - i - shadow_offset,
                     xadd + tile_size - 1 - i - shadow_offset,
                     yadd + shadow_offset);
    }
    gdk_gc_set_foreground (gc, &highlight_color);
    for (i = 0; i < line_thickness; i++) {
      gdk_draw_line (target, gc,
                     xadd + 1 + i + shadow_offset,
                     yadd + shadow_offset,
                     xadd + tile_size - 1 - shadow_offset,
                     yadd + tile_size - 2 - shadow_offset - i);
      gdk_draw_line (target, gc,
                     xadd + 1 + shadow_offset+ i,
                     yadd + tile_size - 1 - shadow_offset,
                     xadd + tile_size - 1 - shadow_offset,
                     yadd + 1 + shadow_offset + i);
    }
  }

  /* Draw highlights */
  gdk_gc_set_foreground (gc, (which == USED) ? &shadow_color : &highlight_color);
  for (i = 0; i < line_thickness; i++) {
    /* bottom edge */
    gdk_draw_line (target, gc,
                   xadd + shadow_offset,
                   yadd + tile_size - 1 - shadow_offset - i,
                   xadd + tile_size - 1 - shadow_offset,
                   yadd + tile_size - 1 - shadow_offset - i);
    /* right edge */
    gdk_draw_line (target, gc,
                   xadd + tile_size - 1 - shadow_offset - i,
                   yadd + shadow_offset,
                   xadd + tile_size - 1 - shadow_offset - i,
                   yadd + tile_size - 1 - shadow_offset);
  }
  gdk_gc_set_foreground (gc, (which == USED) ? &highlight_color : &shadow_color);
  for (i = 0; i < line_thickness; i++) {
    /* top edge */
    gdk_draw_line (target, gc,
                   xadd + shadow_offset,
                   yadd + i + shadow_offset,
                   xadd + tile_size - 2 - i - shadow_offset, 
                   yadd + i + shadow_offset);
    /* left edge */
    gdk_draw_line (target, gc,
                   xadd + i + shadow_offset,
                   yadd + shadow_offset,
                   xadd + i + shadow_offset,
                   yadd + tile_size - 2 - i - shadow_offset);
  }
  gdk_gc_set_foreground (gc, &fg_color);
}

void
gui_draw_text_int (GdkPixmap *target, GdkGC *gc,
                   gint value, gint x, gint y)
{
  PangoLayout *layout;
  gchar *markup;
  gint font_size;

  if (! target) 
    return;
  if (! space) 
    return;

  font_size = (tile_size / 5) * PANGO_SCALE * 0.8;
  markup = g_strdup_printf ("<span size=\"%d\" weight=\"bold\" font_family=\"sans-serif\">%d</span>",
                            font_size, value);
  layout = gtk_widget_create_pango_layout (space, "");
  pango_layout_set_markup (layout, markup, -1);
  gdk_draw_layout (target, gc, x, y, layout);
  g_object_unref (layout);
  g_free (markup);
}

void
gui_draw_pixmap (GdkPixmap *target, gint x, gint y)
{
  gint which, xadd = 0, yadd = 0;
  GdkGC *gc = space->style->black_gc;

  which = tiles[y][x].status;

  if (target == buffer) {
    xadd = x * tile_size + xborder + (x >= size) * gap;
    yadd = y * tile_size + yborder;
  }

  if (target == mover.pixmap) {
    xadd = 0;
    yadd = 0;
    gc = gdk_gc_new (mover.pixmap);
    gdk_window_set_back_pixmap (mover.window, mover.pixmap, 0);
  }

  gui_draw_piece (target, gc, which, xadd, yadd);

  if (which == USED) {
    /* North */
    gui_draw_text_int (target, gc, tiles[y][x].n,
                       xadd + tile_size / 2 - tile_size / 12,
                       yadd + tile_size / 9);

    /* South */
    gui_draw_text_int (target, gc, tiles[y][x].s,
                       xadd + tile_size / 2 - tile_size / 12,
                       yadd + tile_size * 2 / 3);
    
    /* West */
    gui_draw_text_int (target, gc, tiles[y][x].w,
                       xadd + tile_size / 9,
                       yadd + tile_size / 2 - tile_size / 9);
  
    /* East */
    gui_draw_text_int (target, gc, tiles[y][x].e,
                       xadd + tile_size * 3 / 4,
                       yadd + tile_size / 2 - tile_size / 9);
  }
  gtk_widget_queue_draw_area (space, xadd, yadd, tile_size, tile_size);

  if (target==mover.pixmap)
    g_object_unref (gc);
}

void
get_pixeltilexy (gint x, gint y, gint *xx, gint *yy)
{
  gint sumx = xborder, sumy = yborder;
  
  if (x >= size)
    sumx += gap;
  
  sumx += x * tile_size;
  sumy += y * tile_size;
  *xx = sumx;
  *yy = sumy;
}

void
get_tilexy (gint x, gint y, gint *xx, gint *yy)
{
  x = x - xborder; y = y - yborder;
  if (x / tile_size < size)
    *xx = x / tile_size;
  else 
    *xx = size + (x - (gap + tile_size * size)) / tile_size;
  *yy = (y / tile_size);
}

void
get_offsetxy (gint x, gint y, gint *xoff, gint *yoff)
{

  x = x - xborder; y = y - yborder;
  if (x / tile_size < size)
    *xoff = x % tile_size;
  else 
    *xoff = (x - (gap + tile_size * size)) % tile_size;
  *yoff = y % tile_size;
}

gint
setup_mover (gint x, gint y, gint status)
{
  gint xx, yy;
  
  if (status == PRESS) {
    get_tilexy (x, y, &xx, &yy);
    get_offsetxy (x, y, &mover.xoff, &mover.yoff);
    if (tiles[yy][xx].status == UNUSED
        || mover.yoff < 0 || mover.xoff < 0
        || yy >= size || xx >= size * 2)
      return 0; /* No move */

    mover.xstart = xx; 
    mover.ystart = yy;
    gdk_window_resize (mover.window, tile_size, tile_size);
    mover.pixmap = gdk_pixmap_new (mover.window, tile_size,tile_size,
                                   gdk_drawable_get_visual (mover.window)->depth);
    gdk_window_move (mover.window,x - mover.xoff,y - mover.yoff);
    gui_draw_pixmap (mover.pixmap, xx, yy);
    gdk_window_show (mover.window);

    tiles[yy][xx].status = UNUSED;
    gui_draw_pixmap (buffer, xx, yy);
    return 1;
  }

  if (status == RELEASE) {
    get_tilexy (x - mover.xoff + tile_size / 2,
                y - mover.yoff + tile_size / 2,
                &xx, &yy);
    if (tiles[yy][xx].status == UNUSED
        && xx >= 0 && xx < size * 2
        && yy >= 0 && yy < size
        && valid_drop (xx, yy)) {
      tiles[yy][xx] = tiles[mover.ystart][mover.xstart];
      tiles[yy][xx].status = USED;
      gui_draw_pixmap (buffer, xx, yy);
      gui_draw_pixmap (buffer, mover.xstart, mover.ystart);
    } else {
      tiles[mover.ystart][mover.xstart].status = USED;
      gui_draw_pixmap (buffer, mover.xstart, mover.ystart);
    }
    gdk_window_hide (mover.window);
    if (mover.pixmap) 
      g_object_unref (mover.pixmap);
    mover.pixmap = NULL;
    if (game_over ()) {
      game_state = gameover;
      games_clock_stop (GAMES_CLOCK (timer));
      set_game_menu_items_sensitive (FALSE);
      if (! have_been_hinted) {
	message (_("Puzzle solved! Well done!"));
	game_score ();
      } else {
	message (_("Puzzle solved!"));
      }
    }
    update_move_menu_sensitivity ();
    return 1;
  }
  return 0;
}

gint
valid_drop (gint x, gint y)
{
  gint xx, yy;
  xx = mover.xstart;
  yy = mover.ystart;

  if (x >= size)
    return 1;
  
  /* West */
  if (x != 0 && tiles[y][x-1].status == USED 
      && tiles[y][x-1].e != tiles[yy][xx].w) 
    return 0; 
  /* East */
  if (x != size - 1 && tiles[y][x+1].status == USED 
      && tiles[y][x+1].w != tiles[yy][xx].e)
    return 0;
  /* North */
  if (y != 0 && tiles[y-1][x].status == USED 
      && tiles[y-1][x].s != tiles[yy][xx].n)
    return 0; 
  /* South */
  if (y != size - 1 && tiles[y+1][x].status == USED 
      && tiles[y+1][x].n != tiles[yy][xx].s)
    return 0;

  return 1;
}

void
move_tile (gint xx, gint yy, gint x, gint y)
{
  tiles[yy][xx] = tiles[y][x];
  tiles[y][x].status = UNUSED;
}

void
move_column (unsigned char dir)
{
  gint x, y;
  switch (dir) {
  case 'n':
    for (x = 0; x < size; x++)
      if (tiles[0][x].status == USED)
        return;
    for (y = 1; y < size; y++)
      for (x = 0; x < size; x++)
	move_tile (x, y - 1, x, y); 
    redraw_left ();
    break;
  case 's':
    for (x = 0; x < size; x++)
      if (tiles[size-1][x].status == USED)
        return;
    for (y = size - 2; y >= 0; y--)
      for (x = 0; x < size; x++)
	move_tile (x, y + 1, x, y); 
    redraw_left ();
    break;
  case 'w':
    for (y = 0; y < size; y++)
      if (tiles[y][0].status == USED)
        return;
    for (y = 0; y < size; y++)
      for (x = 1; x < size; x++)
	move_tile (x - 1, y, x, y); 
    redraw_left ();
    break;
  case 'e':
    for (y = 0; y < size; y++)
      if (tiles[y][size-1].status == USED)
        return;
    for (y = 0; y < size; y++)
      for (x = size - 2; x >= 0; x--)
	move_tile (x + 1, y, x, y); 
    redraw_left ();
    break;
  default:
    break;
  }
  update_move_menu_sensitivity ();
}

gint
game_over (void)
{
  gint x, y;
  for (y = 0; y < size; y++)
    for (x = 0; x < size; x++)
      if (tiles[y][x].status == UNUSED)
        return 0;

  return 1;
}

void
show_score_dialog (const gchar *level, gint pos)
{
  GtkWidget *dialog;

  dialog = gnome_scores_display (_(APPNAME_LONG), APPNAME, level, pos);
  if (dialog != NULL) {
    gtk_window_set_transient_for (GTK_WINDOW (dialog), GTK_WINDOW (window));
    gtk_window_set_modal (GTK_WINDOW (dialog), TRUE);
  }
}

void
score_cb (GtkWidget *widget, gpointer data)
{
  gchar *level;
  level = g_strdup_printf ("%dx%d", size, size);
  show_score_dialog (level, 0);
  g_free (level);
}

void
game_score (void)
{
  gint pos;
  time_t seconds;
  gfloat score;
  gchar *level;
  
  level = g_strdup_printf ("%dx%d", size, size);
  seconds = GAMES_CLOCK (timer)->stopped;
  games_clock_set_seconds (GAMES_CLOCK (timer), (int) seconds);
  score = (gfloat) (seconds / 60) + (gfloat) (seconds % 60) / 100;
  pos = gnome_score_log (score, level, FALSE);
  update_score_state ();
  show_score_dialog (level, pos);
  g_free (level);
}

void
update_score_state (void)
{
  gchar **names = NULL;
  gfloat *scores = NULL;
  time_t *scoretimes = NULL;
  gint top;
  gchar *level;
  
  level = g_strdup_printf ("%dx%d", size, size);
  
  top = gnome_score_get_notable (APPNAME, level, &names, &scores, &scoretimes);
  g_free (level);

  gtk_widget_set_sensitive (game_menu[6].widget, top > 0);
  g_strfreev (names);
  g_free (scores);
  g_free (scoretimes);
}


void
update_tile_size (gint screen_width, gint screen_height)
{
  gint xt_size, yt_size;
  gint window_width, window_height;
  
  /* We aim for the gap and the corners to be 1/2 a tile wide. */
  xt_size = (2 * screen_width) / (4 * size + 3);
  yt_size = screen_height / (size + 1);
  tile_size = MIN (xt_size, yt_size);
  gap = (screen_width - 2*size*tile_size) / 3;
  xborder = gap;
  yborder = (screen_height - size*tile_size) / 2;

  gtk_window_get_size (GTK_WINDOW (window), &window_width, &window_height);
  gconf_client_set_int (gconf_client, KEY_WINDOW_WIDTH, window_width, NULL);
  gconf_client_set_int (gconf_client, KEY_WINDOW_HEIGHT, window_height, NULL);
}

gint
configure_space (GtkWidget *widget, GdkEventConfigure *event)
{
  gtk_widget_freeze_child_notify (widget);
  update_tile_size (event->width, event->height);
  make_buffer (widget);
  redraw_all ();
  if (game_state == paused)
    gui_draw_pause ();
  gtk_widget_thaw_child_notify (widget);
  
  return FALSE;
}

void
redraw_all (void)
{
  guint x, y;
  GdkGC *draw_gc;
  GdkRegion *region;
  GdkColor *bg_color;

  region = gdk_drawable_get_clip_region (GDK_DRAWABLE (space->window));
  gdk_window_begin_paint_region (space->window, region); 

  draw_gc = gdk_gc_new (space->window);
  bg_color = get_bg_color ();
  gdk_window_set_background (space->window, bg_color);
  gdk_gc_set_background (draw_gc, bg_color);
  gdk_gc_set_foreground (draw_gc, bg_color);
  gdk_color_free (bg_color);
  gdk_draw_rectangle (buffer, draw_gc, TRUE, 0, 0, -1, -1);
  gdk_window_clear (space->window);
  for (y = 0; y < size; y++)
    for (x = 0; x < size*2; x++)
      gui_draw_pixmap (buffer, x, y);
  if (draw_gc)
    g_object_unref (draw_gc);
  
  gdk_window_end_paint (space->window);
  gdk_region_destroy (region);
}

void
redraw_left (void)
{
  gint x, y;
  GdkRegion *region;
  GdkRectangle rect = {xborder, yborder,
                       tile_size * size, tile_size * size};

  region = gdk_region_rectangle (&rect);

  gdk_window_begin_paint_region (space->window, region); 

  for (y = 0; y < size; y++)
    for (x = 0; x < size; x++)
      gui_draw_pixmap (buffer, x, y);

  gdk_window_end_paint (space->window);
  gdk_region_destroy (region);
}

void
create_space (void)
{
  space = gtk_drawing_area_new ();
  gnome_app_set_contents (GNOME_APP (window), space);

  gtk_widget_set_events (space,
			 GDK_EXPOSURE_MASK | GDK_BUTTON_PRESS_MASK
			 | GDK_POINTER_MOTION_MASK | GDK_BUTTON_RELEASE_MASK);
  gtk_widget_realize (space);
  
  g_signal_connect (G_OBJECT (space), "expose_event", 
                    G_CALLBACK (expose_space), NULL);
  g_signal_connect (G_OBJECT (space), "configure_event", 
                    G_CALLBACK (configure_space), NULL);
  g_signal_connect (G_OBJECT (space), "button_press_event", 
                    G_CALLBACK (button_press_space), NULL);
  g_signal_connect (G_OBJECT (space),"button_release_event",
                    G_CALLBACK (button_release_space), NULL);
  g_signal_connect (G_OBJECT (space), "motion_notify_event",
                    G_CALLBACK (button_motion_space), NULL);
  gtk_widget_show (space);
}


void
create_statusbar (void)
{
  GtkWidget *time_label,*time_box;
  time_box = gtk_hbox_new (FALSE, 0);
  time_label = gtk_label_new (_("Time:"));
  gtk_box_pack_start (GTK_BOX (time_box), time_label, FALSE, FALSE, 0);
  time_label = gtk_label_new (" ");
  gtk_box_pack_start (GTK_BOX (time_box), time_label, FALSE, FALSE, 0);
  timer = games_clock_new ();
  gtk_box_pack_start (GTK_BOX (time_box), timer, FALSE, FALSE, 0);

  statusbar = gnome_appbar_new (FALSE, TRUE, GNOME_PREFERENCES_USER);
  gtk_box_pack_start (GTK_BOX (statusbar), time_box, FALSE, FALSE, 0);
  gnome_app_set_statusbar (GNOME_APP (window), statusbar);

  gnome_app_install_menu_hints (GNOME_APP (window), main_menu);
}

void
message (gchar *message)
{
  gnome_appbar_pop (GNOME_APPBAR (statusbar));
  gnome_appbar_push (GNOME_APPBAR (statusbar), message);
}

void
create_mover (void)
{
  GdkWindowAttr attributes;

  attributes.wclass = GDK_INPUT_OUTPUT;
  attributes.window_type = GDK_WINDOW_CHILD;
  attributes.event_mask = 0;
  attributes.width = tile_size;
  attributes.height = tile_size;
  attributes.colormap = gdk_drawable_get_colormap (space->window);
  attributes.visual = gdk_drawable_get_visual (space->window);
  
  mover.window = gdk_window_new(space->window, &attributes,
                                (GDK_WA_VISUAL | GDK_WA_COLORMAP));
  mover.pixmap = NULL;
}

void
new_board (gint size)
{
  static gint myrand = 498;
  gint x, y, x1, y1, i, j;
  tile tmp;

  have_been_hinted = 0;
  solve_me = 0;

  if (timer_timeout) {
    gtk_timeout_remove (timer_timeout);
    gtk_widget_set_sensitive (GTK_WIDGET (space), TRUE);
  }
  
  if (button_down || hint_moving) {
    setup_mover (0, 0, RELEASE);
    button_down = 0;
    hint_moving = 0;
  }

  g_random_set_seed (time (NULL) + myrand);

  myrand += 17;

  for (y=0; y < size; y++)
    for (x = 0; x < size; x++)
      tiles[y][x].status = UNUSED;

  for (y=0; y < size; y++)
    for (x = size; x < size * 2; x++) {
      tiles[y][x].status = USED;
      tiles[y][x].n = g_random_int () % 10;
      tiles[y][x].s = g_random_int () % 10;
      tiles[y][x].w = g_random_int () % 10;
      tiles[y][x].e = g_random_int () % 10;
    }

  /* Sort */
  for (y = 0; y < size; y++)
    for (x = size; x < size * 2 - 1; x++)
      tiles[y][x].e = tiles[y][x+1].w;
  for (y = 0; y < size - 1; y++)
    for (x = size; x < size * 2; x++)
      tiles[y][x].s = tiles[y+1][x].n;

  /* Copy tiles to orig_tiles */
  for (y = 0; y<size; y++)
    for (x = 0; x<size; x++)
      orig_tiles[y][x] = tiles[y][x+size];

  /* Unsort */
  j = 0;
  do {
    for (i = 0; i < size * size * size; i++) {
      x = g_random_int () % size +size;
      y = g_random_int () % size;
      x1 = g_random_int () % size + size;
      y1 = g_random_int () % size;
      tmp = tiles[y1][x1];
      tiles[y1][x1] = tiles[y][x];
      tiles[y][x] = tmp;
    }
  } while (tiles[0][size].e == tiles[0][size+1].w && j++ < 8);
}

GdkColor *
get_bg_color (void) 
{
  GtkStyle *style;
  GdkColor *color;
  style = gtk_widget_get_style (space);
  color = gdk_color_copy (&style->bg[GTK_STATE_NORMAL]);
  return color;
}

void
pause_game (void)
{
  if (game_state != paused) {
    game_state = paused;
    message (_("Game paused"));
    gui_draw_pause ();
    games_clock_stop (GAMES_CLOCK (timer));
  }
}

void
resume_game (void)
{
  if (game_state == paused) {
    game_state = playing;
    message ("");
    redraw_all ();
    games_clock_start (GAMES_CLOCK (timer));
  }
}

void
pause_cb (void)
{
  if (game_state == gameover)
    return;

  if (game_state != paused) {
    pause_game ();
  } else {
    resume_game ();
  }
}

void
gui_draw_pause (void)
{
  guint x, y, xadd, yadd, which;
  GdkRegion *region;
  GdkGC *gc;

  region = gdk_drawable_get_clip_region (GDK_DRAWABLE (space->window));
  gdk_window_begin_paint_region (space->window, region);

  for (y = 0; y < size; y++) {
    for (x = 0; x < size*2; x++) {
      which = tiles[y][x].status;

      xadd = x * tile_size + xborder + (x >= size)*gap;
      yadd = y * tile_size + yborder;
      gc = space->style->black_gc;

      gui_draw_piece (buffer, gc, which, xadd, yadd);

      if (which == USED) {
        /* North */
        gui_draw_text_int (buffer, gc, 0,
                           xadd + tile_size / 2 - tile_size / 12,
                           yadd + tile_size / 9);
        
        /* South */
        gui_draw_text_int (buffer, gc, 0,
                           xadd + tile_size / 2 - tile_size / 12,
                           yadd + tile_size * 2 / 3);

        /* West */
        gui_draw_text_int (buffer, gc, 0,
                           xadd + tile_size / 9,
                           yadd + tile_size / 2 - tile_size / 9);
        
        /* East */
        gui_draw_text_int (buffer, gc, 0,
                           xadd + tile_size * 3 / 4,
                           yadd + tile_size / 2 - tile_size / 9);
      }
      
      gtk_widget_queue_draw_area (space, xadd, yadd, tile_size, tile_size);
    }
  }
  
  gdk_window_end_paint (space->window);
  gdk_region_destroy (region);
}

void
timer_start (void)
{
  games_clock_stop (GAMES_CLOCK (timer));
  games_clock_set_seconds (GAMES_CLOCK (timer), 0);
  games_clock_start (GAMES_CLOCK (timer));
}

/* --------------------------- MENU --------------------- */
void
create_menu (void)
{
  gnome_app_create_menus (GNOME_APP (window), main_menu);
}

void
make_buffer (GtkWidget *widget)
{

  if (buffer)
    g_object_unref (buffer);
  
  buffer = gdk_pixmap_new (widget->window, widget->allocation.width,
                           widget->allocation.height, -1);

}

void
new_game_cb (GtkWidget *widget, gpointer data)
{
  gchar *str;
  widget = space;
  
  new_board (size);
  gtk_widget_freeze_child_notify (space);
  make_buffer (widget);
  redraw_all ();
  gtk_widget_thaw_child_notify (space);
  game_state = playing;
  timer_start ();
  set_game_menu_items_sensitive (TRUE);
  update_move_menu_sensitivity ();
  str = g_strdup_printf (_("Playing %dx%d board"), size, size);
  message (str);
  g_free (str);
}

void
quit_game_cb (GtkWidget *widget, gpointer data)
{
  if (buffer)
    g_object_unref (buffer);
  if (mover.pixmap)
    g_object_unref (mover.pixmap);

  gtk_main_quit ();
}

static gint
save_state (GnomeClient *client, gint phase, 
            GnomeRestartStyle save_style, gint shutdown,
            GnomeInteractStyle interact_style, gint fast,
            gpointer client_data)
{
  gchar *argv[20];
  gint i;
  gint xpos, ypos;

  gdk_window_get_origin (window->window, &xpos, &ypos);
  
  i = 0;
  argv[i++] = (char *)client_data;
  argv[i++] = "-x";
  argv[i++] = g_strdup_printf ("%d",xpos);
  argv[i++] = "-y";
  argv[i++] = g_strdup_printf ("%d",ypos);

  gnome_client_set_restart_command (client, i, argv);
  gnome_client_set_clone_command (client, 0, NULL);
  
  g_free (argv[2]);
  g_free (argv[4]);
  
  return TRUE;
}


void
size_cb (GtkWidget *widget, gpointer data)
{
  gint newsize;
  gint width, height;

  /* Ignore de-activation events. */
  if (!gtk_check_menu_item_get_active (GTK_CHECK_MENU_ITEM (widget)))
    return;
  
  gdk_drawable_get_size (space->window, &width, &height);
  newsize = atoi ((gchar *)data);
  if (size == newsize)
    return;
  size = newsize;
  update_tile_size (width, height);
  update_score_state ();
  gconf_client_set_int (gconf_client, KEY_GRID_SIZE, size, NULL);
  new_game_cb (space, NULL);
}

void
move_cb (GtkWidget *widget, gpointer data)
{
  move_column ((unsigned char)* ((gchar *) data));
}

gint
compare_tile (tile *t1, tile *t2)
{
  if (t1->e == t2->e
      && t1->w == t2->w 
      && t1->s == t2->s
      && t1->n == t2->n)
    return 0;
  return 1;
}

void
find_first_tile (gint status, gint *xx, gint *yy)
{
  gint x, y, size = size;
  for (y = 0; y < size; y++)
    for (x = size; x < size * 2; x++)
      if (tiles[y][x].status == status) {
	*xx = x; *yy = y;
	return;
      }
}

#define COUNT 15
#define DELAY 10

gint hint_src_x, hint_src_y, hint_dest_x, hint_dest_y;

void
hint_move_cb (void)
{
  float dx, dy;
  static gint count = 0;
  dx = (float) (hint_src_x - hint_dest_x) / COUNT; 
  dy = (float) (hint_src_y - hint_dest_y) / COUNT; 
  if (count <= COUNT) {
    gdk_window_move (mover.window, hint_src_x - (gint) (count*dx),
                     (gint) hint_src_y - (gint) (count*dy));
    count++;
  }
  if (count > COUNT) {
    hint_moving = 0;
    count = 0;
    setup_mover (hint_dest_x + 1, hint_dest_y + 1, RELEASE);
    gtk_timeout_remove (timer_timeout);
    gtk_widget_set_sensitive (GTK_WIDGET (space), TRUE);
    if (game_state != playing) return;
    if (solve_me)
      hint_cb (NULL,NULL);
  }
}

void
hint_move (gint x1, gint y1, gint x2, gint y2)
{
  have_been_hinted = 1;
  get_pixeltilexy (x1, y1, &hint_src_x, &hint_src_y);
  get_pixeltilexy (x2, y2, &hint_dest_x, &hint_dest_y);
  setup_mover (hint_src_x + 1, hint_src_y + 1, PRESS);
  hint_moving = 1;
  gtk_widget_set_sensitive (GTK_WIDGET (space), FALSE);
  timer_timeout = gtk_timeout_add (DELAY, (GtkFunction) (hint_move_cb), NULL);
}

void
hint_cb (GtkWidget *widget, gpointer data)
{
  gint x1, y1, x2 = 0, y2 = 0, x, y, size = size;
  tile hint_tile;

  if ((game_state != playing) || button_down || hint_moving)
    return;
  
  find_first_tile (USED, &x, &y);
  x1 = x;
  y1 = y;
  hint_tile = tiles[y][x];

  /* Find position in original map */
  for (y = 0; y < size; y++)
    for (x = 0; x < size; x++)
      if (compare_tile (&hint_tile, &orig_tiles[y][x]) == 0) {
	if (tiles[y][x].status == USED
            && compare_tile (&hint_tile, &tiles[y][x]) == 0) {
	  /* Do Nothing */
	} else {
	  x2 = x; 
          y2 = y;
	  x = size;
          y = size;
	}
      }
  
  /* Tile I want to hint about is busy. Move the busy tile away! */
  if (tiles[y2][x2].status == USED) {
    find_first_tile (UNUSED, &x1, &y1);
    hint_move (x2, y2, x1, y1);
    return;
  }
  
  /* West */
  if (x2 != 0 && tiles[y2][x2-1].status == USED
      && tiles[y2][x2-1].e != hint_tile.w) {
    find_first_tile (UNUSED, &x1, &y1);
    hint_move (x2 - 1, y2, x1, y1);
    return;
  }

  /* East */
  if (x2 != size-1 && tiles[y2][x2+1].status == USED
      && tiles[y2][x2+1].w != hint_tile.e) {
    find_first_tile (UNUSED, &x1, &y1);
    hint_move (x2 + 1, y2, x1, y1);
    return;
  }

  /* North */
  if (y2 != 0 && tiles[y2-1][x2].status == USED
      && tiles[y2-1][x2].s != hint_tile.n) {
    find_first_tile (UNUSED, &x1, &y1);
    hint_move (x2, y2 - 1, x1, y1);
    return;
  }
  
  /* South */
  if (y2 != size - 1 && tiles[y2+1][x2].status == USED
      && tiles[y2+1][x2].n != hint_tile.s) {
    find_first_tile (UNUSED, &x1, &y1);
    hint_move (x2, y2 + 1, x1, y1);
    return;
  }

  hint_move (x1, y1, x2, y2);
}

void
solve_cb (GtkWidget *widget, gpointer data)
{
  solve_me = 1;
  hint_cb (widget, NULL);
}

void
about_cb (GtkWidget *widget, gpointer data)
{
  static GtkWidget *about = NULL;
  GdkPixbuf *pixbuf = NULL;
  
  const gchar *authors[] = { "Lars Rydlinge", NULL };
  gchar *documenters[] = {
    NULL
  };
  /* Translator credits */
  gchar *translator_credits = _("translator_credits");
  
  if (about != NULL) {
    gtk_window_present (GTK_WINDOW (about));
    return;
  }
  {
    gchar *filename = NULL;
    
    filename = gnome_program_locate_file (NULL,
                                          GNOME_FILE_DOMAIN_APP_PIXMAP,
                                          "gnome-gnotravex.png",
                                          TRUE, NULL);
    if (filename != NULL)
      {
        pixbuf = gdk_pixbuf_new_from_file (filename, NULL);
        g_free (filename);
      }
  }
  
  about = gnome_about_new (_(APPNAME_LONG), VERSION, 
                           "Copyright \xc2\xa9 1998-2003 Lars Rydlinge",
                           _("A Tetravex clone."), 
                           (const gchar **)authors,
                           (const gchar **)documenters,
                           strcmp (translator_credits, "translator_credits") != 0 ? translator_credits : NULL,
                           pixbuf);
	
  if (pixbuf != NULL)
    gdk_pixbuf_unref (pixbuf);	  
  
  gtk_window_set_transient_for (GTK_WINDOW (about), GTK_WINDOW (window));
  g_signal_connect (G_OBJECT (about), "destroy",
                    G_CALLBACK (gtk_widget_destroyed), &about);
  gtk_widget_show_all (about);
}
