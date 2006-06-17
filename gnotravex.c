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
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <games-clock.h>
#include <time.h>
#include <gconf/gconf-client.h>
#include <games-stock.h>
#include <games-scores.h>
#include <games-scores-dialog.h>

#define APPNAME "gnotravex"
#define APPNAME_LONG "Tetravex"

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

/* i18n in-game numbers, replaceable with single-character local ideograms. */
const char *translatable_number[10] = { N_("0"), N_("1"), N_("2"), N_("3"), N_("4"), N_("5"), N_("6"), N_("7"), N_("8"), N_("9") }; 

GtkWidget *window;
GtkWidget *statusbar;
GtkWidget *space;
GtkWidget *bit;
GtkWidget *timer;

static const GamesScoresCategory scorecats[] = {{"2x2", N_("2\303\2272")},
                                                {"3x3", N_("3\303\2273")},
                                                {"4x4", N_("4\303\2274")},
                                                {"5x5", N_("5\303\2275")},
                                                {"6x6", N_("6\303\2276")},
                                                GAMES_SCORES_LAST_CATEGORY};
static const GamesScoresDescription scoredesc = {scorecats,
                                                 "3x3",
                                                 "gnotravex",
                                                 GAMES_SCORES_STYLE_TIME_ASCENDING};

GamesScores *highscores;

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

gint size = -1;
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
GtkWidget * create_menu (GtkUIManager *);
void create_mover (void);
GtkWidget * create_statusbar (void);

gint expose_space (GtkWidget *, GdkEventExpose *);
gint button_press_space (GtkWidget *, GdkEventButton *);
gint button_release_space (GtkWidget *, GdkEventButton *);
gint button_motion_space (GtkWidget *, GdkEventButton *);

void gui_draw_piece (GdkPixmap *, GtkStateType, gboolean, gint, gint);
void gui_draw_text_int (GdkPixmap *, gint, GtkStateType, gint, gint);
void gui_draw_pixmap (GdkPixmap *, gint, gint, gboolean);
void gui_draw_pause (void);

void get_pixeltilexy (gint, gint, gint *, gint *);
void get_tilexy (gint, gint, gint *, gint *);
void get_offsetxy (gint, gint, gint *, gint *);

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
gint timer_cb (void);
void timer_start (void);
void pause_game (void);
void resume_game (void);
void pause_cb (void);
void hint_move_cb (void);
void hint_move (gint, gint, gint, gint);
void show_score_dialog (gint);
static gint save_state (GnomeClient*, gint, GnomeRestartStyle,
                        gint, GnomeInteractStyle, gint, gpointer);

GtkAction *new_game_action;
GtkAction *pause_action;
GtkAction *resume_action;
GtkAction *hint_action;
GtkAction *solve_action;
GtkAction *scores_action;
GtkAction *move_up_action;
GtkAction *move_left_action;
GtkAction *move_right_action;
GtkAction *move_down_action;

/* ------------------------- MENU ------------------------ */
void new_game_cb (GtkAction *, gpointer);
void size_cb (GtkAction *, gpointer);
void about_cb (GtkAction *, gpointer);
void score_cb (GtkAction *, gpointer);
void hint_cb (GtkAction *, gpointer);
void solve_cb (GtkAction *, gpointer);
void move_up_cb (GtkAction *, gpointer);
void move_left_cb (GtkAction *, gpointer);
void move_right_cb (GtkAction *, gpointer);
void move_down_cb (GtkAction *, gpointer);
void help_cb (GtkAction *, gpointer);
void quit_game_cb (void);

const GtkActionEntry action_entry[] = {
  { "GameMenu", NULL, N_("_Game") },
  { "MoveMenu", NULL, N_("_Move") },
  { "SizeMenu", NULL, N_("_Size") },
  { "HelpMenu", NULL, N_("_Help") },
  { "NewGame", GAMES_STOCK_NEW_GAME, NULL, NULL, NULL, G_CALLBACK (new_game_cb) },
  { "PauseGame", GAMES_STOCK_PAUSE_GAME, NULL, NULL, NULL, G_CALLBACK (pause_cb) },
  { "ResumeGame", GAMES_STOCK_RESUME_GAME, NULL, NULL, NULL, G_CALLBACK (pause_cb) },
  { "Hint", GAMES_STOCK_HINT, NULL, NULL, NULL, G_CALLBACK (hint_cb) },
  { "Solve", GTK_STOCK_REFRESH, N_("Sol_ve"), NULL, N_("Solve the game"), G_CALLBACK (solve_cb) },
  { "Scores", GAMES_STOCK_SCORES, NULL, NULL, NULL, G_CALLBACK (score_cb) },
  { "Quit", GTK_STOCK_QUIT, NULL, NULL, NULL, G_CALLBACK (quit_game_cb) },
  { "MoveUp", GTK_STOCK_GO_UP, N_("_Up"), "<control>Up", N_("Move the pieces up"), G_CALLBACK (move_up_cb) },
  { "MoveLeft", GTK_STOCK_GO_BACK, N_("_Left"), "<control>Left", N_("Move the pieces left"), G_CALLBACK (move_left_cb) },
  { "MoveRight", GTK_STOCK_GO_FORWARD, N_("_Right"), "<control>Right", N_("Move the pieces right"), G_CALLBACK (move_right_cb) },
  { "MoveDown", GTK_STOCK_GO_DOWN, N_("_Down"), "<control>Down", N_("Move the pieces down"), G_CALLBACK (move_down_cb) },
  { "Contents", GAMES_STOCK_CONTENTS, NULL, NULL, NULL, G_CALLBACK (help_cb) },
  { "About", GTK_STOCK_ABOUT, NULL, NULL, NULL, G_CALLBACK (about_cb) }
};

const GtkRadioActionEntry size_action_entry[] = {
  { "Size2x2", NULL, N_("_2\303\2272"), NULL, N_("Play on a 2\303\2272 board"), 2 },
  { "Size3x3", NULL, N_("_3\303\2273"), NULL, N_("Play on a 3\303\2273 board"), 3 },
  { "Size4x4", NULL, N_("_4\303\2274"), NULL, N_("Play on a 4\303\2274 board"), 4 },
  { "Size5x5", NULL, N_("_5\303\2275"), NULL, N_("Play on a 5\303\2275 board"), 5 },
  { "Size6x6", NULL, N_("_6\303\2276"), NULL, N_("Play on a 6\303\2276 board"), 6 }
};

GtkAction *size_action[G_N_ELEMENTS(size_action_entry)];

const char ui_description[] =
"<ui>"
"  <menubar name='MainMenu'>"
"    <menu action='GameMenu'>"
"      <menuitem action='NewGame'/>"
"      <menuitem action='PauseGame'/>"
"      <menuitem action='ResumeGame'/>"
"      <separator/>"
"      <menuitem action='Hint'/>"
"      <menuitem action='Solve'/>"
"      <separator/>"
"      <menuitem action='Scores'/>"
"      <separator/>"
"      <menuitem action='Quit'/>"
"    </menu>"
"    <menu action='MoveMenu'>"
"      <menuitem action='MoveUp'/>"
"      <menuitem action='MoveLeft'/>"
"      <menuitem action='MoveRight'/>"
"      <menuitem action='MoveDown'/>"
"    </menu>"
"    <menu action='SizeMenu'>"
"      <menuitem action='Size2x2'/>"
"      <menuitem action='Size3x3'/>"
"      <menuitem action='Size4x4'/>"
"      <menuitem action='Size5x5'/>"
"      <menuitem action='Size6x6'/>"
"    </menu>"
"    <menu action='HelpMenu'>"
"      <menuitem action='Contents'/>"
"      <menuitem action='About'/>"
"    </menu>"
"  </menubar>"
"</ui>";


static const GOptionEntry options[] = {
  {"x", 'x', 0, G_OPTION_ARG_INT, &session_xpos, N_("X location of window"), 
   N_("X")},
  {"y", 'y', 0, G_OPTION_ARG_INT, &session_ypos, N_("Y location of window"), 
   N_("Y")},
  {"size", 's', 0, G_OPTION_ARG_INT, &size, N_("Size of board (2-6)"),
    N_("SIZE")},
  {NULL}
};

/* ------------------------------------------------------- */

int 
main (int argc, char **argv)
{
  GnomeClient *client;
  GnomeProgram *program;
  GOptionContext *context;
  GtkWidget *vbox;
  GtkWidget *menubar;
  GtkUIManager *ui_manager;
  GtkAccelGroup *accel_group;  

  setgid_io_init ();

  bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
  bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
  textdomain (GETTEXT_PACKAGE);

  context = g_option_context_new ("");
  g_option_context_add_main_entries (context, options, GETTEXT_PACKAGE);
  program = gnome_program_init (APPNAME, VERSION,
                                LIBGNOMEUI_MODULE, 
       		                argc, argv,
       		                GNOME_PARAM_GOPTION_CONTEXT, context,
       		                GNOME_PARAM_APP_DATADIR, DATADIR, NULL);

  highscores = games_scores_new (&scoredesc);
     
  gtk_window_set_default_icon_name ("gnome-tetravex");
  client = gnome_master_client ();
  g_object_ref (G_OBJECT (client));
  
  g_signal_connect (G_OBJECT (client), "save_yourself",
                    G_CALLBACK (save_state), argv[0]);
  g_signal_connect (G_OBJECT (client), "die",
                    G_CALLBACK (quit_game_cb), argv[0]);

  games_stock_init();

  gconf_client = gconf_client_get_default();

  if (size == -1)
    size = gconf_client_get_int (gconf_client, KEY_GRID_SIZE, NULL);
  if (size < 2 || size > 6) 
    size = 3;

  create_window ();

  space = gtk_drawing_area_new ();


  statusbar = create_statusbar ();

  ui_manager = gtk_ui_manager_new ();
  games_stock_prepare_for_statusbar_tooltips (ui_manager, statusbar);

  menubar = create_menu (ui_manager);

  vbox = gtk_vbox_new (FALSE, 0);

  gnome_app_set_contents (GNOME_APP (window), vbox);
  gtk_box_pack_start (GTK_BOX(vbox), menubar, FALSE, FALSE, 0);
  gtk_box_pack_start (GTK_BOX (vbox), space, TRUE, TRUE, 0);
  gtk_box_pack_start (GTK_BOX(vbox), statusbar, FALSE, FALSE, 0);

  accel_group = gtk_ui_manager_get_accel_group (ui_manager);
  gtk_window_add_accel_group (GTK_WINDOW (window), accel_group);

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
  /* We do our own double-buffering. */
  gtk_widget_set_double_buffered(space, FALSE);

  gtk_widget_show (space);


  if (session_xpos >= 0 && session_ypos >= 0)
    gtk_window_move (GTK_WINDOW (window), session_xpos, session_ypos);
    
  gtk_widget_show_all (window);
  create_mover ();

  gtk_action_activate (new_game_action);
 
  gtk_action_activate (size_action[size-2]); 

  gtk_main ();

  gnome_accelerators_sync();

  g_object_unref (program);
  
  return 0;
}

/* Enable or disable the game menu items that are only relevant
 * during a game. */
static
void set_game_menu_items_sensitive (gboolean state)
{
  gtk_action_set_sensitive (pause_action, state);
  gtk_action_set_sensitive (hint_action, state);
  gtk_action_set_sensitive (solve_action, state);
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

  if (clear || (game_state == paused))
    n = w = e = s = FALSE;
  
  gtk_action_set_sensitive (move_up_action, n);
  gtk_action_set_sensitive (move_left_action, w);
  gtk_action_set_sensitive (move_right_action, e);
  gtk_action_set_sensitive (move_down_action, s);
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
  if (game_state == paused)
    gtk_action_activate (resume_action);
  
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

void
gui_draw_piece (GdkPixmap *target, GtkStateType state,
                gboolean which, gint xadd, gint yadd)
{
  GdkGC *fg;
  GdkGC *bg;
  GdkGC *highlight;
  GdkGC *shadow;
  GdkGC *whichgc;
  GtkStyle *style;
  gint line_thickness = 3;
  gint shadow_offset;
  gint i;

  style = gtk_widget_get_style (space);
  fg = style->fg_gc[state];
  bg = style->bg_gc[state];
  highlight = style->light_gc[state];
  shadow = style->dark_gc[state];

  /* Blank the piece */
  gdk_draw_rectangle (target, bg, TRUE, xadd, yadd,
                      tile_size, tile_size);
  /* Draw outline */
  gdk_draw_rectangle (target, fg, FALSE, xadd, yadd,
                      tile_size-1, tile_size-1);

  /* shadow offset exposes fg color border around used pieces */
  shadow_offset = (which == USED) ? 1 : 0;

  if (which == USED) {
    /* Draw crossed lines */
    for (i = 0; i < line_thickness; i++) {
      gdk_draw_line (target, shadow,
                     xadd + shadow_offset,
                     yadd + i + shadow_offset,
                     xadd + tile_size - 1 - i - shadow_offset,
                     yadd + tile_size - 1 - shadow_offset);
      gdk_draw_line (target, shadow,
                     xadd + shadow_offset,
                     yadd + tile_size - 1 - i - shadow_offset,
                     xadd + tile_size - 1 - i - shadow_offset,
                     yadd + shadow_offset);
    }
    for (i = 0; i < line_thickness; i++) {
      gdk_draw_line (target, highlight,
                     xadd + 1 + i + shadow_offset,
                     yadd + shadow_offset,
                     xadd + tile_size - 1 - shadow_offset,
                     yadd + tile_size - 2 - shadow_offset - i);
      gdk_draw_line (target, highlight,
                     xadd + 1 + shadow_offset+ i,
                     yadd + tile_size - 1 - shadow_offset,
                     xadd + tile_size - 1 - shadow_offset,
                     yadd + 1 + shadow_offset + i);
    }
  }

  /* Draw highlights */
  whichgc = which == USED ? shadow : highlight;

  for (i = 0; i < line_thickness; i++) {
    /* bottom edge */
    gdk_draw_line (target, whichgc,
                   xadd + shadow_offset,
                   yadd + tile_size - 1 - shadow_offset - i,
                   xadd + tile_size - 1 - shadow_offset,
                   yadd + tile_size - 1 - shadow_offset - i);
    /* right edge */
    gdk_draw_line (target, whichgc,
                   xadd + tile_size - 1 - shadow_offset - i,
                   yadd + shadow_offset,
                   xadd + tile_size - 1 - shadow_offset - i,
                   yadd + tile_size - 1 - shadow_offset);
  }

  whichgc = which == USED ? highlight : shadow;

  for (i = 0; i < line_thickness; i++) {
    /* top edge */
    gdk_draw_line (target, whichgc,
                   xadd + shadow_offset,
                   yadd + i + shadow_offset,
                   xadd + tile_size - 2 - i - shadow_offset, 
                   yadd + i + shadow_offset);
    /* left edge */
    gdk_draw_line (target, whichgc,
                   xadd + i + shadow_offset,
                   yadd + shadow_offset,
                   xadd + i + shadow_offset,
                   yadd + tile_size - 2 - i - shadow_offset);
  }
}

gint
button_motion_space (GtkWidget *widget, GdkEventButton *event)
{
  static int oldx = -1, oldy = -1;
  gint x,y;

  if (game_state == paused)
    return FALSE;

  if (button_down == 1) {
    x = event->x - mover.xoff;
    y = event->y - mover.yoff;
    gdk_window_move (mover.window, x, y);
    gdk_window_clear (mover.window);
  } else {
    /* This code hilights pieces as the mouse moves over them
     * in general imitation of "prelight" in GTK. */
    get_tilexy (event->x, event->y, &x, &y);
    if ((x != oldx) || (y != oldy)) {
      if ((oldx != -1) && (tiles[oldy][oldx].status == USED)) {
        gui_draw_pixmap (buffer, oldx, oldy, FALSE);
      }
      if ((x != -1) && (tiles[y][x].status == USED)) {
        gui_draw_pixmap (buffer, x, y, TRUE);
      }
      oldx = x;
      oldy = y;
    }
  }
  return FALSE;
}

/* Note that x and y are the *center* of the digit to be placed. */
void
gui_draw_text_int (GdkPixmap *target, gint value, GtkStateType state,
                   gint x, gint y)
{
  PangoLayout *layout;
  PangoAttrList *alist;
  PangoAttribute *attr;
  PangoFontDescription *font_desc;
  PangoRectangle extent;
  gchar *text;
  guint64 font_size;

  if (! target) 
    return;
  if (! space) 
    return;

  font_size = tile_size / 3.5 * PANGO_SCALE;

  text = _(translatable_number[value]);
  layout = gtk_widget_create_pango_layout (space, text);

  font_desc = pango_font_description_new();
  pango_font_description_set_family(font_desc, "Sans");
  pango_font_description_set_absolute_size(font_desc, font_size);
  pango_font_description_set_weight(font_desc, PANGO_WEIGHT_BOLD);
  
  alist = pango_attr_list_new ();
  attr = pango_attr_font_desc_new(font_desc);
  attr->start_index = 0;
  attr->end_index = strlen(text);
  pango_attr_list_insert (alist, attr);
  pango_layout_set_attributes (layout, alist);
  pango_attr_list_unref (alist);

  pango_layout_get_extents (layout, NULL, &extent);
  x = x - ((guint)extent.width)/(2*PANGO_SCALE);
  y = y - ((guint)extent.height)/(2*PANGO_SCALE);

  gdk_draw_layout (target, space->style->text_gc[state], 
                   x, y, layout);

  pango_font_description_free(font_desc);
  g_object_unref (layout);
}

void
gui_draw_pixmap (GdkPixmap *target, gint x, gint y, gboolean prelight)
{
  gint which, xadd = 0, yadd = 0;
  GtkStateType state;

  which = tiles[y][x].status;
  state = GTK_STATE_NORMAL;

  if (target == buffer) {
    xadd = x * tile_size + xborder  + (x >= size) * gap;
    yadd = y * tile_size + yborder; 
  }

  if (target == mover.pixmap) {
    xadd = 0;
    yadd = 0;
    gdk_window_set_back_pixmap (mover.window, mover.pixmap, 0);
    state = GTK_STATE_PRELIGHT;
  }

  if (prelight)
    state = GTK_STATE_PRELIGHT;

  gui_draw_piece (target, state, which, xadd, yadd);

  if (which == USED) {
    /* North */
    gui_draw_text_int (target, tiles[y][x].n,
                       state,
                       xadd + tile_size / 2,
                       yadd + tile_size / 5);

    /* South */
    gui_draw_text_int (target, tiles[y][x].s,
                       state,
                       xadd + tile_size / 2,
                       yadd + tile_size * 4 / 5);
    
    /* West */
    gui_draw_text_int (target, tiles[y][x].w,
                       state,
                       xadd + tile_size / 5,
                       yadd + tile_size / 2);
  
    /* East */
    gui_draw_text_int (target, tiles[y][x].e,
                       state,
                       xadd + tile_size * 4 / 5,
                       yadd + tile_size / 2);
  }
  gtk_widget_queue_draw_area (space, xadd, yadd, tile_size, tile_size);
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

/* We use this slightly less strict version when dropping tiles. */
static void
get_tilexy_lazy (gint x, gint y, gint *xx, gint *yy)
{
  x = x - xborder; y = y - yborder;
  if (x / tile_size < size)
    *xx = x / tile_size;
  else
    *xx = size + (x - (gap + tile_size * size)) / tile_size;
  *yy = (y / tile_size);
}

void
get_tilexy (gint x, gint y, gint *xx, gint *yy)
{
  /* We return -1, -1 if the location doesn't correspond to a tile. */

  x = x - xborder; 
  y = y - yborder;

  if ((x < 0) || (y < 0) || 
      ((x >= size*tile_size) && (x < size*tile_size + gap))) {
    *xx = -1;
    *yy = -1;
    return;
  }

  if (x / tile_size < size)
    *xx = x / tile_size;
  else 
    *xx = size + (x - (gap + tile_size * size)) / tile_size;
  *yy = (y / tile_size);

  if ((*xx >= 2*size) || (*yy >= size)) {
    *xx = -1;
    *yy = -1;
  }
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
    if (xx == -1)
      return 0; /* No move */
    if (tiles[yy][xx].status == UNUSED)
      return 0; /* No move */
    get_offsetxy (x, y, &mover.xoff, &mover.yoff);

    mover.xstart = xx; 
    mover.ystart = yy;
    gdk_window_resize (mover.window, tile_size, tile_size);
    /* We assume elsewhere that this has the same depth as the parent. */
    mover.pixmap = gdk_pixmap_new (mover.window, tile_size,tile_size, -1);

    gdk_window_move (mover.window,x - mover.xoff,y - mover.yoff);
    gui_draw_pixmap (mover.pixmap, xx, yy, FALSE);
    gdk_window_show (mover.window);

    tiles[yy][xx].status = UNUSED;
    gui_draw_pixmap (buffer, xx, yy, FALSE);
    return 1;
  }

  if (status == RELEASE) {
    get_tilexy_lazy (x - mover.xoff + tile_size / 2,
                     y - mover.yoff + tile_size / 2,
                     &xx, &yy);
    if (tiles[yy][xx].status == UNUSED
        && xx >= 0 && xx < size * 2
        && yy >= 0 && yy < size
        && valid_drop (xx, yy)) {
      tiles[yy][xx] = tiles[mover.ystart][mover.xstart];
      tiles[yy][xx].status = USED;
      gui_draw_pixmap (buffer, xx, yy, FALSE);
      gui_draw_pixmap (buffer, mover.xstart, mover.ystart, FALSE);
    } else {
      tiles[mover.ystart][mover.xstart].status = USED;
      gui_draw_pixmap (buffer, mover.xstart, mover.ystart, FALSE);
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
show_score_dialog (gint pos)
{
  static GtkWidget *scoresdialog = NULL;
  gchar *message;

  if (!scoresdialog) {
    scoresdialog = games_scores_dialog_new (highscores, _("Tetravex Scores"));
    games_scores_dialog_set_category_description (GAMES_SCORES_DIALOG (scoresdialog), _("Size:"));
  }
  if (pos > 0) {
    games_scores_dialog_set_hilight (GAMES_SCORES_DIALOG (scoresdialog), pos);
    message = g_strdup_printf ("<b>%s</b>\n\n%s",
                               _("Congratulations!"),
                               _("Your score has made the top ten."));
    games_scores_dialog_set_message (GAMES_SCORES_DIALOG (scoresdialog), message);
    g_free (message);
  } else {
    games_scores_dialog_set_message (GAMES_SCORES_DIALOG (scoresdialog), NULL);
  }
  
  gtk_dialog_run (GTK_DIALOG (scoresdialog));
  gtk_widget_hide (scoresdialog);
}

void
score_cb (GtkAction *action, gpointer data)
{
  gchar *level;
  level = g_strdup_printf ("%dx%d", size, size);
  show_score_dialog (0);
  g_free (level);
}

void
game_score (void)
{
  gint pos;
  time_t seconds;
  GamesScoreValue score;
  
  seconds = GAMES_CLOCK (timer)->stopped;
  games_clock_set_seconds (GAMES_CLOCK (timer), (int) seconds);
  score.time_double = (gfloat) (seconds / 60) + (gfloat) (seconds % 60) / 100;
  pos = games_scores_add_score (highscores, score);
  show_score_dialog (pos);
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
  GdkRegion *region;

  region = gdk_drawable_get_clip_region (GDK_DRAWABLE (space->window));
  gdk_window_begin_paint_region (space->window, region); 

  gdk_draw_rectangle (buffer, space->style->bg_gc[GTK_STATE_NORMAL], 
                      TRUE, 0, 0, -1, -1);
  gdk_window_clear (space->window);
  for (y = 0; y < size; y++)
    for (x = 0; x < size*2; x++)
      gui_draw_pixmap (buffer, x, y, FALSE);
  
  gdk_window_end_paint (space->window);
  gdk_region_destroy (region);
}

void
redraw_left (void)
{
  gint x, y;
  GdkRegion *region;
  GdkRectangle rect = {xborder, yborder, tile_size * size, tile_size * size};

  region = gdk_region_rectangle (&rect);

  gdk_window_begin_paint_region (space->window, region); 

  for (y = 0; y < size; y++)
    for (x = 0; x < size; x++)
      gui_draw_pixmap (buffer, x, y, FALSE);

  gdk_window_end_paint (space->window);
  gdk_region_destroy (region);
}


GtkWidget *
create_statusbar (void)
{
  GtkWidget *status_bar, *time_label, *time_box;

  time_box = gtk_hbox_new (FALSE, 0);
  time_label = gtk_label_new (_("Time:"));
  gtk_box_pack_start (GTK_BOX (time_box), time_label, FALSE, FALSE, 0);
  time_label = gtk_label_new (" ");
  gtk_box_pack_start (GTK_BOX (time_box), time_label, FALSE, FALSE, 0);
  timer = games_clock_new ();
  gtk_box_pack_start (GTK_BOX (time_box), timer, FALSE, FALSE, 0);

  status_bar = gtk_statusbar_new();
  gtk_statusbar_set_has_resize_grip (GTK_STATUSBAR (status_bar), FALSE);
  gtk_box_pack_start (GTK_BOX (status_bar), time_box, FALSE, FALSE, 0);
 
  return status_bar; 
}

void
message (gchar *message)
{
  guint context_id;

  context_id = gtk_statusbar_get_context_id (GTK_STATUSBAR (statusbar), "mesasge");
  gtk_statusbar_pop (GTK_STATUSBAR (statusbar), context_id);
  gtk_statusbar_push (GTK_STATUSBAR (statusbar), context_id, message);
}

void
create_mover (void)
{
  GdkWindowAttr attributes;

  /* The depth of mover.window must match the depth of space->window. */
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
    g_source_remove (timer_timeout);
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

void
pause_game (void)
{
  if (game_state != paused) {
    game_state = paused;
    message (_("Game paused"));
    gui_draw_pause ();
    update_move_menu_sensitivity ();
    gtk_action_set_sensitive (hint_action, FALSE);
    gtk_action_set_sensitive (solve_action, FALSE);
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
    update_move_menu_sensitivity ();
    gtk_action_set_sensitive (hint_action, TRUE);
    gtk_action_set_sensitive (solve_action, TRUE);
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

      gui_draw_piece (buffer, GTK_STATE_NORMAL, which, xadd, yadd);

      if (which == USED) {
        /* North */
        gui_draw_text_int (buffer, 0,
                           GTK_STATE_NORMAL,
                           xadd + tile_size / 2,
                           yadd + tile_size / 5);
        
        /* South */
        gui_draw_text_int (buffer, 0,
                           GTK_STATE_NORMAL,
                           xadd + tile_size / 2,
                           yadd + tile_size * 4 / 5);
        
        /* West */
        gui_draw_text_int (buffer, 0,
                           GTK_STATE_NORMAL,
                           xadd + tile_size / 5,
                           yadd + tile_size / 2);
        
        /* East */
        gui_draw_text_int (buffer, 0,
                           GTK_STATE_NORMAL,
                           xadd + tile_size * 4 / 5,
                           yadd + tile_size / 2);
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
GtkWidget *
create_menu (GtkUIManager *ui_manager)
{
  gint i;
  GtkActionGroup *action_group;

  action_group = gtk_action_group_new ("actions");

  gtk_action_group_set_translation_domain(action_group, GETTEXT_PACKAGE);
  gtk_action_group_add_actions (action_group, action_entry, G_N_ELEMENTS (action_entry), window);
  gtk_action_group_add_radio_actions (action_group, size_action_entry, G_N_ELEMENTS (size_action_entry), -1, G_CALLBACK(size_cb), NULL);

  gtk_ui_manager_insert_action_group (ui_manager, action_group, 0);
  gtk_ui_manager_add_ui_from_string (ui_manager, ui_description, -1, NULL);

  new_game_action   = gtk_action_group_get_action (action_group, "NewGame");
  pause_action      = gtk_action_group_get_action (action_group, "PauseGame");
  resume_action     = gtk_action_group_get_action (action_group, "ResumeGame");
  hint_action       = gtk_action_group_get_action (action_group, "Hint");
  solve_action      = gtk_action_group_get_action (action_group, "Solve");
  scores_action     = gtk_action_group_get_action (action_group, "Scores");
  move_up_action    = gtk_action_group_get_action (action_group, "MoveUp");
  move_left_action  = gtk_action_group_get_action (action_group, "MoveLeft");
  move_right_action = gtk_action_group_get_action (action_group, "MoveRight");
  move_down_action  = gtk_action_group_get_action (action_group, "MoveDown");

  for (i = 0; i < G_N_ELEMENTS(size_action_entry); i++)
    size_action[i] = gtk_action_group_get_action (action_group, size_action_entry[i].name);

  games_stock_set_pause_actions (pause_action, resume_action);
  return gtk_ui_manager_get_widget (ui_manager, "/MainMenu");
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
new_game_cb (GtkAction *action, gpointer data)
{
  gchar *str;
  
  new_board (size);
  gtk_widget_freeze_child_notify (space);
  make_buffer (space);
  redraw_all ();
  gtk_widget_thaw_child_notify (space);
  game_state = playing;
  timer_start ();
  set_game_menu_items_sensitive (TRUE);
  update_move_menu_sensitivity ();
  str = g_strdup_printf (_("Playing %d\303\227%d board"), size, size);
  message (str);
  g_free (str);
}

void
quit_game_cb (void)
{
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
size_cb (GtkAction *action, gpointer data)
{
  gint newsize;
  gint width, height;

  newsize = gtk_radio_action_get_current_value (GTK_RADIO_ACTION (action));

  gdk_drawable_get_size (space->window, &width, &height);

  if (game_state == paused)
    gtk_action_activate (resume_action);

  if (size == newsize)
    return;
  size = newsize;
  update_tile_size (width, height);
  games_scores_set_category (highscores, scorecats[size-2].key);
  gconf_client_set_int (gconf_client, KEY_GRID_SIZE, size, NULL);
  gtk_action_activate (new_game_action);
}

void
move_up_cb (GtkAction *action, gpointer data)
{
  move_column ('n');
}

void
move_left_cb (GtkAction *action, gpointer data)
{
  move_column ('w');
}

void
move_right_cb (GtkAction *action, gpointer data)
{
  move_column ('e');
}

void
move_down_cb (GtkAction *action, gpointer data)
{
  move_column ('s');
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
  gint x, y;
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
    g_source_remove (timer_timeout);
    gtk_widget_set_sensitive (GTK_WIDGET (space), TRUE);
    if (game_state != playing) return;
    if (solve_me)
      gtk_action_activate (hint_action);
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
  timer_timeout = g_timeout_add (DELAY, (GSourceFunc) (hint_move_cb), NULL);
}

void
hint_cb (GtkAction *action, gpointer data)
{
  gint x1, y1, x2 = 0, y2 = 0, x = 0, y = 0;
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
solve_cb (GtkAction *action, gpointer data)
{
  solve_me = 1;
  gtk_action_activate (hint_action);
}

void
help_cb (GtkAction *action, gpointer data)
{
  gnome_help_display ("gnotravex.xml", NULL, NULL);
}

void
about_cb (GtkAction *action, gpointer data)
{
  const gchar *authors[] = { "Lars Rydlinge", NULL };

  const gchar *documenters[] = { "Rob Bradford", NULL };

  gtk_show_about_dialog (GTK_WINDOW (window),
                         "name", _(APPNAME_LONG),
                         "version", VERSION,
                         "comments", _("GNOME Tetravex is a simple puzzle where "
					     "pieces must be positioned so that the "
					     "same numbers are touching each other."),
                         "copyright", "Copyright \xc2\xa9 1999-2006 Lars Rydlinge",
                         "license", "GPL 2+",
                         "authors", authors,
                         "documenters", documenters,
                         "translator_credits", _("translator-credits"),
                         "logo-icon-name", "gnome-tetravex",
                         "website", "http://www.gnome.org/projects/gnome-games/",
                         "wrap-license", TRUE,
                         NULL);
}
