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
#include <libgnomeui/gnome-window-icon.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <games-clock.h>
#include <time.h>
#include <gconf/gconf-client.h>

#define APPNAME "gnotravex"
#define APPNAME_LONG "GNOME Tetravex"

#define DEFAULT_TILE_SIZE 51
/* This is based on the point where the numbers become unreadable on my
 * screen. - Callum */
#define MINIMUM_TILE_SIZE 40

#define CORNER 25
#define GAP 30

#define RELEASE 4
#define PRESS 3
#define MOVING 2
#define UNUSED 1
#define USED 0

GtkWidget *window;
GtkWidget *statusbar;
GtkWidget *space;
GtkWidget *bit;
GtkWidget *timer;

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

gint SIZE = 3;
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
void create_window ();
void create_menu ();
void create_space ();
void create_mover ();
void create_statusbar ();
GdkColor *get_bg_color ();
void get_tile_size ();
void message (gchar *);
void new_board (gint);
void redraw_all ();
void redraw_left ();
void gui_draw_pixmap (GdkPixmap *, gint, gint);
gint setup_mover (gint, gint, gint);
gint valid_drop (gint, gint);
void move_column (unsigned char);
gint game_over ();
void game_score ();
void update_score_state ();
gint timer_cb ();
void timer_start ();
void pause_game ();
void resume_game ();
void pause_cb ();
void gui_draw_pause ();
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
  {GNOME_APP_UI_ITEM, N_("_Up"), N_("Move the selected piece up"),
   move_cb, "n", NULL, GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

  {GNOME_APP_UI_ITEM, N_("_Left"), N_("Move the selected piece left"),
   move_cb, "w", NULL, GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

  {GNOME_APP_UI_ITEM, N_("_Right"), N_("Move the selected piece right"),
   move_cb, "e", NULL, GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

  {GNOME_APP_UI_ITEM, N_("_Down"), N_("Move the selected piece down"),
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
  { "size", 's', POPT_ARG_INT, &SIZE,0,
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
     
  gnome_window_icon_set_default_from_file (GNOME_ICONDIR"/gnotravex/gnome-gnotravex.png");
  client = gnome_master_client ();
  g_object_ref (G_OBJECT (client));
  
  g_signal_connect (G_OBJECT (client), "save_yourself",
                    G_CALLBACK (save_state), argv[0]);
  g_signal_connect (G_OBJECT (client), "die",
                    G_CALLBACK (quit_game_cb), argv[0]);

  gconf_client = gconf_client_get_default();

  SIZE = gconf_client_get_int (gconf_client,
                               "/apps/gnotravex/grid_size", NULL);
  
  if (SIZE < 2 || SIZE > 6) 
    SIZE = 3;

  get_tile_size ();
  
  create_window ();
  create_menu ();

  create_space (); 
  create_statusbar ();

  update_score_state ();

  if (session_xpos >= 0 && session_ypos >= 0)
    gtk_widget_set_uposition (window, session_xpos, session_ypos);
    
  gtk_widget_show_all (window);
  create_mover ();

  new_game_cb (space,NULL);
  
  gtk_check_menu_item_set_active (GTK_CHECK_MENU_ITEM (size_radio_list[SIZE-2].widget),TRUE);

  gtk_main ();
  
  return 0;
}

gint
get_space_width ()
{
  return (CORNER*2 + GAP + SIZE * tile_size * 2);
}

gint
get_space_min_width ()
{
  return (CORNER*2 + GAP + SIZE * MINIMUM_TILE_SIZE * 2);
}

gint
get_space_height ()
{
  return (CORNER*2 + SIZE * tile_size);
}

gint
get_space_min_height ()
{
  return (CORNER*2 + SIZE * MINIMUM_TILE_SIZE);
}

void
create_window ()
{
  window = gnome_app_new (APPNAME, N_(APPNAME_LONG));
  gtk_window_set_resizable (GTK_WINDOW (window), TRUE);
  /* FIXME:
   * This is a bit of a hack because I can't find a way to give a
   * gtk_drawing_area (or any widget but a window) anything but a
   * minimum size. The hardcoded 64 will come back and bite us, but
   * the widgets we're allowing for haven't been allocated yet. */
  gtk_window_set_default_size (GTK_WINDOW (window), get_space_width (),
                               get_space_height () + 64);
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
  static gint x = -1, y = -1;
  gint newx, newy;
  
  if (button_down == 1) {
    /* This is convoluted but it minimises the number of gtk_window_clear
     * calls that are made. This is important with remote X connections. */
    newx = event->x - mover.xoff;
    newy = event->y - mover.yoff;
    gdk_window_move (mover.window, newx, newy);
    if ((x < 0)
        || (y < 0)
        || (x > (get_space_width () - tile_size))
        || (y > (get_space_height () - tile_size)))
      gdk_window_clear (mover.window);
    x = newx;
    y = newy;
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
  gint which, xadd, yadd;
  GdkGC *gc;

  which = tiles[y][x].status;

  if (target == buffer) {
    xadd = x * tile_size + CORNER + (x >= SIZE) * GAP;
    yadd = y * tile_size + CORNER;
    gc = space->style->black_gc;
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
    gdk_gc_unref (gc);
}

void
get_pixeltilexy (gint x, gint y, gint *xx, gint *yy)
{
  gint sumx = CORNER, sumy = CORNER;
  
  if (x >= SIZE)
    sumx += GAP;
  
  sumx += x * tile_size;
  sumy += y * tile_size;
  *xx = sumx;
  *yy = sumy;
}

void
get_tilexy (gint x, gint y, gint *xx, gint *yy)
{
  x = x - CORNER; y = y - CORNER;
  if (x / tile_size < SIZE)
    *xx = x / tile_size;
  else 
    *xx = SIZE + (x - (GAP + tile_size * SIZE)) / tile_size;
  *yy = (y / tile_size);
}

void
get_offsetxy (gint x, gint y, gint *xoff, gint *yoff)
{

  x = x - CORNER; y = y - CORNER;
  if (x / tile_size < SIZE)
    *xoff = x % tile_size;
  else 
    *xoff = (x - (GAP + tile_size * SIZE)) % tile_size;
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
        || yy >= SIZE || xx >= SIZE * 2)
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
        && xx >= 0 && xx < SIZE * 2
        && yy >= 0 && yy < SIZE
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
    if (mover.pixmap) gdk_drawable_unref (mover.pixmap);
    mover.pixmap = NULL;
    if (game_over ()) {
      game_state = gameover;
      games_clock_stop (GAMES_CLOCK (timer));
      if (! have_been_hinted) {
	message (_("Puzzle solved! Well done!"));
	game_score ();
      } else {
	message (_("Puzzle solved!"));
      }
    }
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

  if (x >= SIZE)
    return 1;
  
  /* West */
  if (x != 0 && tiles[y][x-1].status == USED 
      && tiles[y][x-1].e != tiles[yy][xx].w) 
    return 0; 
  /* East */
  if (x != SIZE - 1 && tiles[y][x+1].status == USED 
      && tiles[y][x+1].w != tiles[yy][xx].e)
    return 0;
  /* North */
  if (y != 0 && tiles[y-1][x].status == USED 
      && tiles[y-1][x].s != tiles[yy][xx].n)
    return 0; 
  /* South */
  if (y != SIZE - 1 && tiles[y+1][x].status == USED 
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
    for (x = 0; x < SIZE; x++)
      if (tiles[0][x].status == USED)
        return;
    for (y = 1; y < SIZE; y++)
      for (x = 0; x < SIZE; x++)
	move_tile (x, y - 1, x, y); 
    redraw_left ();
    break;
  case 's':
    for (x = 0; x < SIZE; x++)
      if (tiles[SIZE-1][x].status == USED)
        return;
    for (y = SIZE - 2; y >= 0; y--)
      for (x = 0; x < SIZE; x++)
	move_tile (x, y + 1, x, y); 
    redraw_left ();
    break;
  case 'w':
    for (y = 0; y < SIZE; y++)
      if (tiles[y][0].status == USED)
        return;
    for (y = 0; y < SIZE; y++)
      for (x = 1; x < SIZE; x++)
	move_tile (x - 1, y, x, y); 
    redraw_left ();
    break;
  case 'e':
    for (y = 0; y < SIZE; y++)
      if (tiles[y][SIZE-1].status == USED)
        return;
    for (y = 0; y < SIZE; y++)
      for (x = SIZE - 2; x >= 0; x--)
	move_tile (x + 1, y, x, y); 
    redraw_left ();
    break;
  default:
    break;
  }
}

gint
game_over ()
{
  gint x, y;
  for (y = 0; y < SIZE; y++)
    for (x = 0; x < SIZE; x++)
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
  gchar level[5];
  sprintf (level,"%dx%d",SIZE,SIZE);
  show_score_dialog (level, 0);
}

void
game_score ()
{
  gint pos;
  time_t seconds;
  gfloat score;
  gchar level[5];
  
  sprintf (level,"%dx%d",SIZE,SIZE);
  seconds = GAMES_CLOCK (timer)->stopped;
  games_clock_set_seconds (GAMES_CLOCK (timer), (int) seconds);
  score = (gfloat) (seconds / 60) + (gfloat) (seconds % 60) / 100;
  pos = gnome_score_log (score,level,FALSE);
  update_score_state ();
  show_score_dialog (level, pos);
}

void
update_score_state ()
{
  gchar **names = NULL;
  gfloat *scores = NULL;
  time_t *scoretimes = NULL;
  gint top;
  gchar level[5];
  
  sprintf (level,"%dx%d",SIZE,SIZE);
  
  top = gnome_score_get_notable (APPNAME, level, &names, &scores, &scoretimes);
  if (top > 0) {
    gtk_widget_set_sensitive (game_menu[6].widget, TRUE);
    g_strfreev (names);
    g_free (scores);
    g_free (scoretimes);
  } else {
    gtk_widget_set_sensitive (game_menu[6].widget, FALSE);
  }
}

void
get_tile_size (void)
{
  gint max;

  if (tile_size == 0)
    tile_size = gconf_client_get_int (gconf_client,
                                      "/apps/gnotravex/tile_size",
                                      NULL);

  /* 100 is really just a guess as to what the window border, menu and
   * status bar might take up. */
  max = (gdk_screen_get_height (gdk_screen_get_default ()) - 2*GAP - 100)/SIZE;
  if (tile_size < MINIMUM_TILE_SIZE || tile_size > max)
    tile_size = DEFAULT_TILE_SIZE;
}

void
update_tile_size (gint screen_width, gint screen_height)
{
  gint xt_size, yt_size;

  xt_size = (screen_width - 3 * GAP) / (2 * SIZE) ;
  yt_size = (screen_height - 2 * GAP) / SIZE;
  tile_size = MIN (xt_size, yt_size);

  gconf_client_set_int (gconf_client, "/apps/gnotravex/tile_size", tile_size,
                        NULL);
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
redraw_all ()
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
  for (y = 0; y < SIZE; y++)
    for (x = 0; x < SIZE*2; x++)
      gui_draw_pixmap (buffer, x, y);
  if (draw_gc)
    gdk_gc_unref (draw_gc);
  
  gdk_window_end_paint (space->window);
  gdk_region_destroy (region);
}

void
redraw_left ()
{
  gint x, y;
  GdkRegion *region;
  GdkRectangle rect = {CORNER, CORNER,
                       tile_size * SIZE, tile_size * SIZE};

  region = gdk_region_rectangle (&rect);

  gdk_window_begin_paint_region (space->window, region); 

  for (y = 0; y < SIZE; y++)
    for (x = 0; x < SIZE; x++)
      gui_draw_pixmap (buffer, x, y);

  gdk_window_end_paint (space->window);
  gdk_region_destroy (region);
}

void
create_space ()
{
  space = gtk_drawing_area_new ();
  gnome_app_set_contents (GNOME_APP (window), space);

  gtk_widget_set_size_request (space, get_space_min_width (),
                               get_space_min_height ());
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
create_statusbar ()
{
  GtkWidget *time_label,*time_box;
  time_box = gtk_hbox_new (FALSE, 0);
  time_label = gtk_label_new (_("Time : "));
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
create_mover ()
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
  } while (tiles[0][SIZE].e == tiles[0][SIZE+1].w && j++ < 8);
}

GdkColor *
get_bg_color () 
{
  GtkStyle *style;
  GdkColor *color;
  style = gtk_widget_get_style (space);
  color = gdk_color_copy (&style->bg[GTK_STATE_NORMAL]);
  return color;
}

void
pause_game ()
{
  if (game_state != paused) {
    game_state = paused;
    message (_("Game paused"));
    gui_draw_pause ();
    games_clock_stop (GAMES_CLOCK (timer));
  }
}

void
resume_game ()
{
  if (game_state == paused) {
    game_state = playing;
    message ("");
    redraw_all ();
    games_clock_start (GAMES_CLOCK (timer));
  }
}

void
pause_cb ()
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
gui_draw_pause ()
{
  guint x, y, xadd, yadd, which;
  GdkRegion *region;
  GdkGC *gc;

  region = gdk_drawable_get_clip_region (GDK_DRAWABLE (space->window));
  gdk_window_begin_paint_region (space->window, region);

  for (y = 0; y < SIZE; y++) {
    for (x = 0; x < SIZE*2; x++) {
      which = tiles[y][x].status;

      xadd = x * tile_size + CORNER + (x >= SIZE)*GAP;
      yadd = y * tile_size + CORNER;
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
timer_start ()
{
  games_clock_stop (GAMES_CLOCK (timer));
  games_clock_set_seconds (GAMES_CLOCK (timer), 0);
  games_clock_start (GAMES_CLOCK (timer));
}

/* --------------------------- MENU --------------------- */
void
create_menu ()
{
  gnome_app_create_menus (GNOME_APP (window), main_menu);
}

void
make_buffer (GtkWidget *widget)
{

  if (buffer)
    gdk_drawable_unref (buffer);
  
  buffer = gdk_pixmap_new (widget->window, widget->allocation.width,
                           widget->allocation.height, -1);

}

void
new_game_cb (GtkWidget *widget, gpointer data)
{
  char str[40];
  widget = space;
  
  new_board (SIZE);
  gtk_widget_freeze_child_notify (space);
  /*
  gtk_drawing_area_size (GTK_DRAWING_AREA (space),
                         CORNER * 2 + GAP + SIZE * tile_size * 2,
                         SIZE * tile_size + CORNER * 2);
  */
  make_buffer (widget);
  redraw_all ();
  gtk_widget_thaw_child_notify (space);
  game_state = playing;
  timer_start ();
  sprintf (str, _("Playing %dx%d board"), SIZE, SIZE);
  message (str);
}

void
quit_game_cb (GtkWidget *widget, gpointer data)
{
  if (buffer)
    gdk_drawable_unref (buffer);
  if (mover.pixmap)
    gdk_drawable_unref (mover.pixmap);

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
  gint size;
  gint width, height;
  gdk_drawable_get_size (space->window, &width, &height);
  size = atoi ((gchar *)data);
  SIZE = size;
  update_tile_size (width, height);
  update_score_state ();
  gconf_client_set_int (gconf_client, "/apps/gnotravex/grid_size", SIZE, NULL);
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
  gint x, y, size = SIZE;
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
hint_move_cb ()
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
  gint x1, y1, x2, y2, x, y, size = SIZE;
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
  if (x2 != SIZE-1 && tiles[y2][x2+1].status == USED
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
  if (y2 != SIZE - 1 && tiles[y2+1][x2].status == USED
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
                                          "gnotravex/gnome-gnotravex.png",
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
