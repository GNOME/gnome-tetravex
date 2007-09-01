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

#include <string.h>
#include <math.h>
#include <time.h>
#include <stdlib.h>

#include <glib/gi18n.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gtk/gtk.h>

#include <games-clock.h>
#include <games-stock.h>
#include <games-scores.h>
#include <games-scores-dialog.h>
#include <games-conf.h>

#ifdef HAVE_GNOME
#include <gnome.h>
#endif /* HAVE_GNOME */

#define APPNAME "gnotravex"
#define APPNAME_LONG N_("Tetravex")

/* This is based on the point where the numbers become unreadable on my
 * screen at 3x3. - Callum */
#define MINIMUM_TILE_SIZE 40

#define RELEASE 4
#define PRESS 3
#define MOVING 2
#define UNUSED 1
#define USED 0

#define KEY_GRID_SIZE     "grid_size"
#define KEY_CLICK_MOVE    "click_to_move"
#define KEY_SHOW_COLOURS  "colours"

#define DEFAULT_WIDTH 320
#define DEFAULT_HEIGHT 240

/* i18n in-game numbers, replaceable with single-character local ideograms. */
static const char *translatable_number[10] =
  { N_("0"), N_("1"), N_("2"), N_("3"), N_("4"), N_("5"), N_("6"), N_("7"),
N_("8"), N_("9") };

static GtkWidget *window;
static GtkWidget *statusbar;
static GtkWidget *space;
static GtkWidget *bit;
static GtkWidget *timer;
static GdkGC *bg_gc;

static const GamesScoresCategory scorecats[] = { {"2x2", N_("2\303\2272")},
{"3x3", N_("3\303\2273")},
{"4x4", N_("4\303\2274")},
{"5x5", N_("5\303\2275")},
{"6x6", N_("6\303\2276")},
GAMES_SCORES_LAST_CATEGORY
};
static const GamesScoresDescription scoredesc = { scorecats,
  "3x3",
  "gnotravex",
  GAMES_SCORES_STYLE_TIME_ASCENDING
};

static GamesScores *highscores;

static int xborder;
static int yborder;
static int gap;

static GdkPixmap *buffer = NULL;

typedef struct _mover {
  GdkWindow *window;
  GdkPixmap *pixmap;
  gint xstart, ystart;
  gint xtarget, ytarget;
  gint xoff, yoff;
} Mover;

static Mover mover;

typedef struct _tile {
  gint n, w, e, s;
  gint status;
} tile;

static tile tiles[9][18];
static tile orig_tiles[9][9];

enum {
  gameover,
  paused,
  playing,
};

static gint size = -1;
static gint game_state = gameover;
static gint have_been_hinted = 0;
static gint solve_me = 0;
static gint hint_moving = 0;
static gint session_flag = 0;
static gint session_xpos = 0;
static gint session_ypos = 0;
static gint session_position = 0;
static guint timer_timeout = 0;
static gint tile_size = 0;
static gdouble tile_border_size = 3.0;
static gdouble arrow_border_size = 1.5;
static gboolean coloured_tiles = TRUE;
static gboolean click_to_move = FALSE;

/* The vertices used in the tiles/sockets. These are built using gui_build_vertices() */
static gdouble vertices[27][2];
static gboolean rebuild_vertices = TRUE;

/* The sector of a tile to mark quads with */
#define NORTH 0
#define SOUTH 1
#define EAST  2
#define WEST  3

#define HIGHLIGHT 0
#define BASE      1
#define SHADOW    2
#define TEXT      3

/* The faces used to build a socket */
static int socket_faces[4][7] = {
  {NORTH, SHADOW,    4, 0, 1, 18, 17},
  {WEST,  SHADOW,    4, 0, 3, 20, 17},
  {EAST,  HIGHLIGHT, 4, 1, 2, 19, 18},
  {SOUTH, HIGHLIGHT, 4, 2, 3, 20, 19}
};

/* The faces used to build the arrow */
static int arrow_faces[3][7] = {
  {NORTH, SHADOW,    4, 21, 24, 25, 22},
  {NORTH, SHADOW,    4, 21, 23, 26, 24},
  {NORTH, HIGHLIGHT, 4, 23, 22, 25, 26}
};

/* The faces used to build a tile */
static int tile_faces[16][7] = {
  {NORTH, BASE,      3,  4,  5, 12,  0},
  {SOUTH, BASE,      3,  8,  9, 14,  0},
  {EAST,  BASE,      3,  6,  7, 13,  0},
  {WEST,  BASE,      3, 10, 11, 15,  0},
  {EAST,  SHADOW,    4,  1,  2,  7,  6},
  {SOUTH, SHADOW,    4,  2,  3,  9,  8},
  {WEST,  SHADOW,    4,  0, 16, 15, 11},
  {NORTH, SHADOW,    4,  1, 16, 12,  5},
  {SOUTH, SHADOW,    4,  2, 16, 14,  8},
  {WEST,  SHADOW,    4,  3, 16, 15, 10},
  {NORTH, HIGHLIGHT, 4,  0,  1,  5,  4},
  {WEST,  HIGHLIGHT, 4,  0,  3, 10, 11},
  {NORTH, HIGHLIGHT, 4,  0, 16, 12,  4},
  {EAST,  HIGHLIGHT, 4,  1, 16, 13,  6},
  {EAST,  HIGHLIGHT, 4,  2, 16, 13,  7},
  {SOUTH, HIGHLIGHT, 4,  3, 16, 14,  9}
};

/* Tile segment colours (this is the resistor colour code) */
static gdouble tile_colours[11][4][4] = {
  {{ 46,  52,  54, 255}, {  0,   0,   0, 255}, {  0,   0,   0, 255}, {255, 255, 255, 255}}, /* 0  = black */
  {{233, 185, 110, 255}, {193, 125,  17, 255}, {143,  89,   2, 255}, {255, 255, 255, 255}}, /* 1  = brown */
  {{239,  41,  41, 255}, {204,   0,   0, 255}, {164,   0,   0, 255}, {255, 255, 255, 255}}, /* 2  = red */
  {{252, 175,  62, 255}, {245, 121,   0, 255}, {206,  92,   0, 255}, {255, 255, 255, 255}}, /* 3  = orange */
  {{252, 233,  79, 255}, {237, 212,   0, 255}, {196, 160,   0, 255}, {  0,   0,   0, 255}}, /* 4  = yellow */
  {{138, 226,  52, 255}, {115, 210,  22, 255}, { 78, 154,   6, 255}, {  0,   0,   0, 255}}, /* 5  = green */
  {{114, 159, 207, 255}, { 52, 101, 164, 255}, { 32,  74, 135, 255}, {255, 255, 255, 255}}, /* 6  = blue */
  {{173, 127, 168, 255}, {117,  80, 123, 255}, { 92,  53, 102, 255}, {255, 255, 255, 255}}, /* 7  = violet */
  {{211, 215, 207, 255}, {186, 189, 182, 255}, {136, 138, 133, 255}, {  0,   0,   0, 255}}, /* 8  = grey */
  {{255, 255, 255, 255}, {255, 255, 255, 255}, {238, 238, 236, 255}, {  0,   0,   0, 255}}, /* 9  = white */
  {{255, 255, 255,  32}, {  0,   0,   0,  32}, {  0,   0,   0,  64}, {  0,   0,   0,   0}}  /* 10 = shadows */
};

/* The colour to use when tiles are not coloured */
#define DEFAULT_COLOUR 8

/* The colour to use when drawing the sockets */
#define SOCKET_COLOUR 10

void make_buffer (GtkWidget *);
void create_window (void);
GtkWidget *create_menu (GtkUIManager *);
void create_mover (void);
GtkWidget *create_statusbar (void);
GdkPixmap *default_background_pixmap;

gint expose_space (GtkWidget *, GdkEventExpose *);
gint button_press_space (GtkWidget *, GdkEventButton *);
gint button_release_space (GtkWidget *, GdkEventButton *);
gint button_motion_space (GtkWidget *, GdkEventButton *);

void gui_build_vertices (void);
void gui_draw_faces (cairo_t * context, gint xadd, gint yadd, int quads[][7],
		     int count, guint colours[4], gboolean prelight);
void gui_draw_arrow (GdkPixmap * target);
void gui_draw_socket (GdkPixmap * target, GtkStateType state, gint xadd,
		      gint yadd);
void gui_draw_number (cairo_t * context, gdouble x, gdouble y, guint number, gdouble *colour);
void gui_draw_tile (GdkPixmap * target, GtkStateType state, gint xadd,
		    gint yadd, gint north, gint south, gint east, gint west, gboolean prelight);
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
gboolean configure_space (GtkWidget *, GdkEventConfigure *);
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
void clickmove_toggle_cb (GtkToggleAction *, gpointer);
void hint_move (gint, gint, gint, gint);
gint show_score_dialog (gint, gboolean);
void new_game (void);
#ifdef HAVE_GNOME
static gint save_state (GnomeClient *, gint, GnomeRestartStyle,
			gint, GnomeInteractStyle, gint, gpointer);
#endif                     
static void set_fullscreen_actions (gboolean is_fullscreen);
static void fullscreen_cb (GtkAction * action);
static gboolean window_state_cb (GtkWidget * widget, GdkEventWindowState * event);
static void load_pixmaps (void);

static GtkAction *new_game_action;
static GtkAction *pause_action;
static GtkAction *resume_action;
static GtkAction *hint_action;
static GtkAction *solve_action;
static GtkAction *scores_action;
static GtkAction *move_up_action;
static GtkAction *move_left_action;
static GtkAction *move_right_action;
static GtkAction *move_down_action;
static GtkAction *fullscreen_action;
static GtkAction *leave_fullscreen_action;


/* ------------------------- MENU ------------------------ */
void new_game_cb (GtkAction *, gpointer);
void size_cb (GtkAction *, gpointer);
void about_cb (GtkAction *, gpointer);
void score_cb (GtkAction *, gpointer);
void hint_cb (GtkAction *, gpointer);
void solve_cb (GtkAction *, gpointer);
void show_colours_toggle_cb (GtkToggleAction * togglebutton, gpointer data);
void move_up_cb (GtkAction *, gpointer);
void move_left_cb (GtkAction *, gpointer);
void move_right_cb (GtkAction *, gpointer);
void move_down_cb (GtkAction *, gpointer);
void help_cb (GtkAction *, gpointer);
void quit_game_cb (void);

const GtkActionEntry action_entry[] = {
  {"GameMenu", NULL, N_("_Game")},
  {"ViewMenu", NULL, N_("_View")},
  {"MoveMenu", NULL, N_("_Move")},
  {"SizeMenu", NULL, N_("_Size")},
  {"HelpMenu", NULL, N_("_Help")},
  {"NewGame", GAMES_STOCK_NEW_GAME, NULL, NULL, NULL,
   G_CALLBACK (new_game_cb)},
  {"PauseGame", GAMES_STOCK_PAUSE_GAME, NULL, NULL, NULL,
   G_CALLBACK (pause_cb)},
  {"ResumeGame", GAMES_STOCK_RESUME_GAME, NULL, NULL, NULL,
   G_CALLBACK (pause_cb)},
  {"Hint", GAMES_STOCK_HINT, NULL, NULL, NULL, G_CALLBACK (hint_cb)},
  {"Solve", GTK_STOCK_REFRESH, N_("Sol_ve"), NULL, N_("Solve the game"),
   G_CALLBACK (solve_cb)},
  {"Scores", GAMES_STOCK_SCORES, NULL, NULL, NULL, G_CALLBACK (score_cb)},
  {"Quit", GTK_STOCK_QUIT, NULL, NULL, NULL, G_CALLBACK (quit_game_cb)},
  {"Fullscreen", GAMES_STOCK_FULLSCREEN, NULL, NULL, NULL,
   G_CALLBACK (fullscreen_cb)},
  {"LeaveFullscreen", GAMES_STOCK_LEAVE_FULLSCREEN, NULL, NULL, NULL,
   G_CALLBACK (fullscreen_cb)},

  {"MoveUp", GTK_STOCK_GO_UP, N_("_Up"), "<control>Up",
   N_("Move the pieces up"), G_CALLBACK (move_up_cb)},
  {"MoveLeft", GTK_STOCK_GO_BACK, N_("_Left"), "<control>Left",
   N_("Move the pieces left"), G_CALLBACK (move_left_cb)},
  {"MoveRight", GTK_STOCK_GO_FORWARD, N_("_Right"), "<control>Right",
   N_("Move the pieces right"), G_CALLBACK (move_right_cb)},
  {"MoveDown", GTK_STOCK_GO_DOWN, N_("_Down"), "<control>Down",
   N_("Move the pieces down"), G_CALLBACK (move_down_cb)},
  {"Contents", GAMES_STOCK_CONTENTS, NULL, NULL, NULL, G_CALLBACK (help_cb)},
  {"About", GTK_STOCK_ABOUT, NULL, NULL, NULL, G_CALLBACK (about_cb)}
};

const GtkRadioActionEntry size_action_entry[] = {
  {"Size2x2", NULL, N_("_2\303\2272"), NULL, N_("Play on a 2\303\2272 board"),
   2},
  {"Size3x3", NULL, N_("_3\303\2273"), NULL, N_("Play on a 3\303\2273 board"),
   3},
  {"Size4x4", NULL, N_("_4\303\2274"), NULL, N_("Play on a 4\303\2274 board"),
   4},
  {"Size5x5", NULL, N_("_5\303\2275"), NULL, N_("Play on a 5\303\2275 board"),
   5},
  {"Size6x6", NULL, N_("_6\303\2276"), NULL, N_("Play on a 6\303\2276 board"),
   6}
};

static const GtkToggleActionEntry toggles[] = {
  {"Colours", NULL, N_("Tile _Colours"), NULL, "Colour the game tiles",
   G_CALLBACK (show_colours_toggle_cb)},
  {"ClickToMove", NULL, N_("_Click to Move"), NULL, "Pick up and drop tiles by clicking",
   G_CALLBACK (clickmove_toggle_cb)}
};

static GtkAction *size_action[G_N_ELEMENTS (size_action_entry)];

static const char ui_description[] =
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
  "    <menu action='ViewMenu'>"
  "      <menuitem action='Colours'/>"
  "      <menuitem action='Fullscreen'/>"
  "      <menuitem action='LeaveFullscreen'/>"
  "    </menu>"
  "    <menu action='MoveMenu'>"
  "      <menuitem action='ClickToMove'/>"
  "      <separator/>"
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
  "      <menuitem action='About'/>" "    </menu>" "  </menubar>" "</ui>";


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
  GOptionContext *context;
  GtkWidget *vbox;
  GtkWidget *menubar;
  GtkUIManager *ui_manager;
  GtkAccelGroup *accel_group;
#ifdef HAVE_GNOME
  GnomeClient *client;
  GnomeProgram *program;
#else
  gboolean retval;
  GError *error = NULL;
#endif

#if defined(HAVE_GNOME) || defined(HAVE_RSVG_GNOMEVFS)
  /* If we're going to use gnome-vfs, we need to init threads before
   * calling any glib functions.
   */
  g_thread_init (NULL);
#endif

  setgid_io_init ();

  bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
  bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
  textdomain (GETTEXT_PACKAGE);

  context = g_option_context_new (NULL);
  g_option_context_add_main_entries (context, options, GETTEXT_PACKAGE);

#ifdef HAVE_GNOME
  program = gnome_program_init (APPNAME, VERSION,
				LIBGNOMEUI_MODULE,
				argc, argv,
				GNOME_PARAM_GOPTION_CONTEXT, context,
				GNOME_PARAM_APP_DATADIR, DATADIR,
                                NULL);
  
  client = gnome_master_client ();
  g_signal_connect (client, "save_yourself",
                    G_CALLBACK (save_state), argv[0]);
  g_signal_connect (client, "die",
                    G_CALLBACK (quit_game_cb), argv[0]);
#else
  g_option_context_add_group (context, gtk_get_option_group (TRUE));

  retval = g_option_context_parse (context, &argc, &argv, &error);
  g_option_context_free (context);
  if (!retval) {
    g_print ("%s", error->message);
    g_error_free (error);
    exit (1);
  }
#endif /* HAVE_GNOME */

  g_set_application_name (_(APPNAME_LONG));

  games_conf_initialise (APPNAME);

  highscores = games_scores_new (&scoredesc);

  games_stock_init ();

  gtk_window_set_default_icon_name ("gnome-tetravex");

  if (size == -1)
    size = games_conf_get_integer (NULL, KEY_GRID_SIZE, NULL);
  if (size < 2 || size > 6)
    size = 3;
  games_scores_set_category (highscores, scorecats[size - 2].key);

  coloured_tiles = games_conf_get_boolean (NULL, KEY_SHOW_COLOURS, NULL);
  click_to_move = games_conf_get_boolean (NULL, KEY_CLICK_MOVE, NULL);

  load_pixmaps ();
  create_window ();

  space = gtk_drawing_area_new ();
  gtk_widget_set_events (space,
                         GDK_EXPOSURE_MASK | GDK_BUTTON_PRESS_MASK
                         | GDK_POINTER_MOTION_MASK | GDK_BUTTON_RELEASE_MASK);

  statusbar = create_statusbar ();

  ui_manager = gtk_ui_manager_new ();
  games_stock_prepare_for_statusbar_tooltips (ui_manager, statusbar);

  menubar = create_menu (ui_manager);

  vbox = gtk_vbox_new (FALSE, 0);
  gtk_container_add (GTK_CONTAINER (window), vbox);

  gtk_box_pack_start (GTK_BOX (vbox), menubar, FALSE, FALSE, 0);
  gtk_box_pack_start (GTK_BOX (vbox), space, TRUE, TRUE, 0);
  gtk_box_pack_start (GTK_BOX (vbox), statusbar, FALSE, FALSE, 0);

  accel_group = gtk_ui_manager_get_accel_group (ui_manager);
  gtk_window_add_accel_group (GTK_WINDOW (window), accel_group);

  gtk_widget_realize (space);
  bg_gc = gdk_gc_new (space->window);
  gdk_gc_set_tile (bg_gc, default_background_pixmap);
  gdk_gc_set_fill (bg_gc, GDK_TILED);

  g_signal_connect (G_OBJECT (space), "expose_event",
		    G_CALLBACK (expose_space), NULL);
  g_signal_connect (G_OBJECT (space), "configure_event",
		    G_CALLBACK (configure_space), NULL);
  g_signal_connect (G_OBJECT (space), "button_press_event",
		    G_CALLBACK (button_press_space), NULL);
  g_signal_connect (G_OBJECT (space), "button_release_event",
		    G_CALLBACK (button_release_space), NULL);
  g_signal_connect (G_OBJECT (space), "motion_notify_event",
		    G_CALLBACK (button_motion_space), NULL);
  /* We do our own double-buffering. */
  gtk_widget_set_double_buffered (space, FALSE);

  gtk_widget_show (space);


  if (session_xpos >= 0 && session_ypos >= 0)
    gtk_window_move (GTK_WINDOW (window), session_xpos, session_ypos);

  gtk_widget_show_all (window);
  create_mover ();

  gtk_action_activate (new_game_action);

  gtk_action_activate (size_action[size - 2]);

  gtk_main ();

  games_conf_shutdown ();

#ifdef HAVE_GNOME
  g_object_unref (program);
#endif /* HAVE_GNOME */

  return 0;
}

/* Enable or disable the game menu items that are only relevant
 * during a game. */
static
  void
set_game_menu_items_sensitive (gboolean state)
{
  gtk_action_set_sensitive (pause_action, state);
  gtk_action_set_sensitive (hint_action, state);
  gtk_action_set_sensitive (solve_action, state);
}

/* Show only valid options in the move menu. */
static
  void
update_move_menu_sensitivity (void)
{
  int x, y;
  gboolean clear;
  gboolean n, w, e, s;

  n = w = e = s = TRUE;

  clear = TRUE;
  for (x = 0; x < size; x++) {
    if (tiles[0][x].status == USED)
      n = FALSE;
    if (tiles[x][0].status == USED)
      w = FALSE;
    if (tiles[x][size - 1].status == USED)
      e = FALSE;
    if (tiles[size - 1][x].status == USED)
      s = FALSE;
    for (y = 0; y < size; y++)
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


void
create_window (void)
{
  window = gtk_window_new (GTK_WINDOW_TOPLEVEL);

  gtk_window_set_title (GTK_WINDOW (window), _(APPNAME_LONG));

  gtk_window_set_default_size (GTK_WINDOW (window), DEFAULT_WIDTH, DEFAULT_HEIGHT);
  games_conf_add_window (GTK_WINDOW (window), NULL);
  gtk_window_set_resizable (GTK_WINDOW (window), TRUE);

  gtk_widget_realize (window);
  g_signal_connect (G_OBJECT (window), "delete_event",
		    G_CALLBACK (quit_game_cb), NULL);
  g_signal_connect (G_OBJECT (window), "window_state_event",
		    G_CALLBACK (window_state_cb), NULL);

}

gint
expose_space (GtkWidget * widget, GdkEventExpose * event)
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
button_press_space (GtkWidget * widget, GdkEventButton * event)
{
  if (game_state == paused)
    gtk_action_activate (resume_action);

  if (game_state != playing)
    return FALSE;
   
  if (event->button != 1)
    return FALSE;
   
  if (click_to_move) 
  {
    if (button_down) 
    {
      setup_mover (event->x,event->y, RELEASE); /* Seen it happened */
      button_down = 0;
      return FALSE;
    }
    else
    {	       
      if (setup_mover (event->x, event->y, PRESS))
	button_down = 1;
    }
  }
  else
  {
    if (button_down == 1) 
    {
      setup_mover (event->x,event->y, RELEASE); /* Seen it happened */
      button_down = 0;
      return FALSE;
    }
    if (setup_mover (event->x, event->y, PRESS))
      button_down = 1;
  }
   
  return FALSE;
}

gint
button_release_space (GtkWidget * widget, GdkEventButton * event)
{
  /* Ignore when using click to move mode */
  if (click_to_move)
    return FALSE;

  if (event->button == 1) {
    if (button_down == 1) {
      setup_mover (event->x, event->y, RELEASE);
    }
    button_down = 0;
  }
  return FALSE;
}

void
gui_build_vertices (void)
{
  gdouble z, midx, midy, offset, far_offset;
  gdouble z2, dx, dy, w, h, xoffset, yoffset;

  /* Vertices 0-3 are the border of the square */
  vertices[0][0] = 0;
  vertices[0][1] = 0;
  vertices[1][0] = tile_size;
  vertices[1][1] = 0;
  vertices[2][0] = tile_size;
  vertices[2][1] = tile_size;
  vertices[3][0] = 0;
  vertices[3][1] = tile_size;

  /* Calculate the intersection between the edge and the diagonal grooves */
  z = 0.70711 * tile_border_size;
  offset = tile_border_size + z;
  far_offset = tile_size - offset;

  /* Top edge */
  vertices[4][0] = offset;
  vertices[4][1] = tile_border_size;
  vertices[5][0] = far_offset;
  vertices[5][1] = tile_border_size;

  /* Right edge */
  vertices[6][0] = tile_size - tile_border_size;
  vertices[6][1] = offset;
  vertices[7][0] = tile_size - tile_border_size;
  vertices[7][1] = far_offset;

  /* Bottom edge */
  vertices[8][0] = far_offset;
  vertices[8][1] = tile_size - tile_border_size;
  vertices[9][0] = offset;
  vertices[9][1] = tile_size - tile_border_size;

  /* Left edge */
  vertices[10][0] = tile_border_size;
  vertices[10][1] = far_offset;
  vertices[11][0] = tile_border_size;
  vertices[11][1] = offset;

  midx = tile_size / 2.0;
  midy = tile_size / 2.0;

  /* Inner edges */
  vertices[12][0] = midx;
  vertices[12][1] = midy - z;
  vertices[13][0] = midx + z;
  vertices[13][1] = midy;
  vertices[14][0] = midx;
  vertices[14][1] = midy + z;
  vertices[15][0] = midx - z;
  vertices[15][1] = midy;

  /* Centre point */
  vertices[16][0] = midx;
  vertices[16][1] = midy;

  /* Edges for socket */
  vertices[17][0] = tile_border_size;
  vertices[17][1] = tile_border_size;
  vertices[18][0] = tile_size - tile_border_size;
  vertices[18][1] = tile_border_size;
  vertices[19][0] = tile_size - tile_border_size;
  vertices[19][1] = tile_size - tile_border_size;
  vertices[20][0] = tile_border_size;
  vertices[20][1] = tile_size - tile_border_size;
   
  /* Edges for the arrow */
  w = gap;
  h = size * tile_size;
  xoffset = w * 0.25;
  yoffset = 0.5 * (h - 1.5 * tile_size);
  vertices[21][0] = xoffset;
  vertices[21][1] = h * 0.5;
  vertices[22][0] = w - xoffset;
  vertices[22][1] = yoffset;
  vertices[23][0] = vertices[22][0];
  vertices[23][1] = h - yoffset;
   
  /* Arrow inner edges */
  dx = w - 2*xoffset;
  dy = (h - 2*yoffset) * 0.5;
  z = arrow_border_size * dy / sqrt(dx*dx + dy*dy);
  z2 = (dy / dx) * (dx - arrow_border_size - z);
  vertices[24][0] = vertices[21][0] + z;
  vertices[24][1] = vertices[21][1];
  vertices[25][0] = vertices[22][0] - arrow_border_size;
  vertices[25][1] = vertices[21][1] - z2;
  vertices[26][0] = vertices[25][0];
  vertices[26][1] = vertices[21][1] + z2;
}

void
gui_draw_faces (cairo_t * context, gint xadd, gint yadd, int quads[][7],
		int count, guint colours[4], gboolean prelight)
{
  int i, j, k;
  int *quad;
  guint face, level, n_vertices;
  gdouble *colour;

  for (i = 0; i < count; i += 1) {
    quad = quads[i];

    /* Set the face colour */
    face = quad[0];
    level = quad[1];
    if (prelight && level == BASE)
       level = HIGHLIGHT;
    n_vertices = quad[2];
    colour = tile_colours[colours[face]][level];
    cairo_set_source_rgba (context, colour[0] / 255.0, colour[1] / 255.0,
			   colour[2] / 255.0, colour[3] / 255.0);

    k = quad[3];
    cairo_move_to (context, xadd + vertices[k][0], yadd + vertices[k][1]);
    for (j = 1; j < n_vertices; j += 1) {
      k = quad[j + 3];
      cairo_line_to (context, xadd + vertices[k][0], yadd + vertices[k][1]);
    }

    cairo_close_path (context);
    cairo_fill (context);
  }
}

void
gui_draw_arrow (GdkPixmap * target)
{
  cairo_t *context;
  gdouble x, y;
  guint colours[4] = { SOCKET_COLOUR, SOCKET_COLOUR, SOCKET_COLOUR, SOCKET_COLOUR };
   
  context = gdk_cairo_create (GDK_DRAWABLE (buffer));
     
  x = xborder + size * tile_size;
  y = yborder;
  gui_draw_faces (context, x, y, arrow_faces, 3, colours, FALSE);
     
  cairo_destroy (context);
}

void
gui_draw_socket (GdkPixmap * target, GtkStateType state, gint xadd, gint yadd)
{
  cairo_t *context;
  guint colours[4] = { SOCKET_COLOUR, SOCKET_COLOUR, SOCKET_COLOUR, SOCKET_COLOUR };
  gdouble *colour;
  
  gdk_draw_rectangle (GDK_DRAWABLE(target), bg_gc, TRUE, xadd, yadd, 
		      tile_size, tile_size);

  context = gdk_cairo_create (GDK_DRAWABLE (target));

  /* Only draw inside the allocated space */
  cairo_rectangle (context, xadd, yadd, tile_size, tile_size);
  cairo_clip (context);

  /* Blank the piece */
  colour = tile_colours[SOCKET_COLOUR][BASE];
  cairo_set_source_rgba (context, colour[0] / 255.0, colour[1] / 255.0, colour[2] / 255.0, colour[3] / 255.0);
  cairo_rectangle (context, xadd, yadd, tile_size, tile_size);
  cairo_fill (context);

  /* Build the co-ordinates used by the tiles */
  if (rebuild_vertices) {
    gui_build_vertices ();
    rebuild_vertices = FALSE;
  }

  gui_draw_faces (context, xadd, yadd, socket_faces, 4, colours, FALSE);

  cairo_destroy (context);
}

void
gui_draw_number (cairo_t * context, gdouble x, gdouble y, guint number, gdouble *colour)
{
  gchar *text;
  cairo_text_extents_t extents;

  text = _(translatable_number[number]);

  cairo_set_source_rgba (context, colour[0] / 255.0, colour[1] / 255.0,
			 colour[2] / 255.0, colour[3] / 255.0);

  cairo_text_extents (context, text, &extents);
  cairo_move_to (context, x - extents.width / 2.0, y + extents.height / 2.0);
  cairo_show_text (context, text);
}

void
gui_draw_tile (GdkPixmap * target, GtkStateType state, gint xadd, gint yadd,
	       gint north, gint south, gint east, gint west, gboolean prelight)
{
  cairo_t *context;
  guint colours[4];

  context = gdk_cairo_create (GDK_DRAWABLE (target));

  /* Use per sector colours or the theme colours */
  if (coloured_tiles) {
    colours[NORTH] = north;
    colours[SOUTH] = south;
    colours[EAST] = east;
    colours[WEST] = west;
  } else
    colours[NORTH] = colours[SOUTH] = colours[EAST] = colours[WEST] = DEFAULT_COLOUR;

  /* Only draw inside the allocated space */
  cairo_rectangle (context, xadd, yadd, tile_size, tile_size);
  cairo_clip (context);
   
  /* Clear background */
  cairo_set_source_rgba (context, 0.0, 0.0, 0.0, 1.0);
  cairo_paint (context);

  /* Build the co-ordinates used by the tiles */
  if (rebuild_vertices) {
    gui_build_vertices ();
    rebuild_vertices = FALSE;
  }

  gui_draw_faces (context, xadd, yadd, tile_faces, 16, colours, prelight);

  /* Draw outline */
  cairo_set_line_width (context, 1.0);
  cairo_set_source_rgba (context, 0.0, 0.0, 0.0, 1.0);
  cairo_rectangle (context, xadd + 0.5, yadd + 0.5, tile_size - 1.0,
		   tile_size - 1.0);
  cairo_stroke (context);

  cairo_select_font_face (context, "Sans", CAIRO_FONT_SLANT_NORMAL,
			  CAIRO_FONT_WEIGHT_BOLD);
  cairo_set_font_size (context, tile_size / 3.5);

  gui_draw_number (context, xadd + tile_size / 2, yadd + tile_size / 5, north, tile_colours[colours[NORTH]][TEXT]);
  gui_draw_number (context, xadd + tile_size / 2, yadd + tile_size * 4 / 5, south, tile_colours[colours[SOUTH]][TEXT]);
  gui_draw_number (context, xadd + tile_size * 4 / 5, yadd + tile_size / 2, east, tile_colours[colours[EAST]][TEXT]);
  gui_draw_number (context, xadd + tile_size / 5, yadd + tile_size / 2, west, tile_colours[colours[WEST]][TEXT]);

  cairo_destroy (context);
}

gint
button_motion_space (GtkWidget * widget, GdkEventButton * event)
{
  static int oldx = -1, oldy = -1;
  gint x, y;

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

void
gui_draw_pixmap (GdkPixmap * target, gint x, gint y, gboolean prelight)
{
  gint which, xadd = 0, yadd = 0;
  GtkStateType state;

  which = tiles[y][x].status;
  state = GTK_STATE_NORMAL;

  if (target == buffer) {
    xadd = x * tile_size + xborder + (x >= size) * gap;
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

  if (which == USED)
    gui_draw_tile (target, state, xadd, yadd, tiles[y][x].n, tiles[y][x].s,
		   tiles[y][x].e, tiles[y][x].w, state);
  else
    gui_draw_socket (target, state, xadd, yadd);

  gtk_widget_queue_draw_area (space, xadd, yadd, tile_size, tile_size);
}

void
get_pixeltilexy (gint x, gint y, gint * xx, gint * yy)
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
get_tilexy_lazy (gint x, gint y, gint * xx, gint * yy)
{
  x = x - xborder;
  y = y - yborder;
  if (x / tile_size < size)
    *xx = x / tile_size;
  else
    *xx = size + (x - (gap + tile_size * size)) / tile_size;
  *yy = (y / tile_size);
}

void
get_tilexy (gint x, gint y, gint * xx, gint * yy)
{
  /* We return -1, -1 if the location doesn't correspond to a tile. */

  x = x - xborder;
  y = y - yborder;

  if ((x < 0) || (y < 0) ||
      ((x >= size * tile_size) && (x < size * tile_size + gap))) {
    *xx = -1;
    *yy = -1;
    return;
  }

  if (x / tile_size < size)
    *xx = x / tile_size;
  else
    *xx = size + (x - (gap + tile_size * size)) / tile_size;
  *yy = (y / tile_size);

  if ((*xx >= 2 * size) || (*yy >= size)) {
    *xx = -1;
    *yy = -1;
  }
}

void
get_offsetxy (gint x, gint y, gint * xoff, gint * yoff)
{

  x = x - xborder;
  y = y - yborder;
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
      return 0;			/* No move */
    if (tiles[yy][xx].status == UNUSED)
      return 0;			/* No move */
    get_offsetxy (x, y, &mover.xoff, &mover.yoff);

    mover.xstart = xx;
    mover.ystart = yy;
    gdk_window_resize (mover.window, tile_size, tile_size);
    /* We assume elsewhere that this has the same depth as the parent. */
    mover.pixmap = gdk_pixmap_new (mover.window, tile_size, tile_size, -1);

    gdk_window_move (mover.window, x - mover.xoff, y - mover.yoff);
    gui_draw_pixmap (mover.pixmap, xx, yy, FALSE);
    gdk_window_show (mover.window);

    tiles[yy][xx].status = UNUSED;
    gui_draw_pixmap (buffer, xx, yy, FALSE);
    return 1;
  }

  if (status == RELEASE) {
    get_tilexy_lazy (x - mover.xoff + tile_size / 2,
		     y - mover.yoff + tile_size / 2, &xx, &yy);
    if (tiles[yy][xx].status == UNUSED
	&& xx >= 0 && xx < size * 2
	&& yy >= 0 && yy < size && valid_drop (xx, yy)) {
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
    if (game_over () && game_state != gameover) {
      game_state = gameover;
      games_clock_stop (GAMES_CLOCK (timer));
      set_game_menu_items_sensitive (FALSE);
      if (!have_been_hinted) {
	message (_("Puzzle solved! Well done!"));
      } else {
	message (_("Puzzle solved!"));
      }
      game_score ();
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
  if (x != 0 && tiles[y][x - 1].status == USED
      && tiles[y][x - 1].e != tiles[yy][xx].w)
    return 0;
  /* East */
  if (x != size - 1 && tiles[y][x + 1].status == USED
      && tiles[y][x + 1].w != tiles[yy][xx].e)
    return 0;
  /* North */
  if (y != 0 && tiles[y - 1][x].status == USED
      && tiles[y - 1][x].s != tiles[yy][xx].n)
    return 0;
  /* South */
  if (y != size - 1 && tiles[y + 1][x].status == USED
      && tiles[y + 1][x].n != tiles[yy][xx].s)
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
      if (tiles[size - 1][x].status == USED)
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
      if (tiles[y][size - 1].status == USED)
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

gint
show_score_dialog (gint pos, gboolean endofgame)
{
  static GtkWidget *scoresdialog = NULL;
  gchar *message;
  gint result;

  if (!scoresdialog) {
    scoresdialog = games_scores_dialog_new (GTK_WINDOW (window), highscores, _("Tetravex Scores"));
    games_scores_dialog_set_category_description (GAMES_SCORES_DIALOG
						  (scoresdialog), _("Size:"));
  }
  if (pos > 0) {
    games_scores_dialog_set_hilight (GAMES_SCORES_DIALOG (scoresdialog), pos);
    message = g_strdup_printf ("<b>%s</b>\n\n%s",
			       _("Congratulations!"),
			       _("Your score has made the top ten."));
    games_scores_dialog_set_message (GAMES_SCORES_DIALOG (scoresdialog),
				     message);
    g_free (message);
  } else {
    games_scores_dialog_set_message (GAMES_SCORES_DIALOG (scoresdialog),
				     NULL);
  }

  if (endofgame) {
    games_scores_dialog_set_buttons (GAMES_SCORES_DIALOG (scoresdialog),
				     GAMES_SCORES_QUIT_BUTTON |
				     GAMES_SCORES_NEW_GAME_BUTTON);
  } else {
    games_scores_dialog_set_buttons (GAMES_SCORES_DIALOG (scoresdialog), 0);
  }

  result = gtk_dialog_run (GTK_DIALOG (scoresdialog));
  gtk_widget_hide (scoresdialog);

  return result;
}

void
score_cb (GtkAction * action, gpointer data)
{
  show_score_dialog (0, FALSE);
}

void
game_score (void)
{
  gint pos = 0;
  time_t seconds;
  GamesScoreValue score;

  if (!have_been_hinted) {
    seconds = GAMES_CLOCK (timer)->stopped;
    games_clock_set_seconds (GAMES_CLOCK (timer), (int) seconds);
    score.time_double = (gfloat) (seconds / 60) + (gfloat) (seconds % 60) / 100;
    pos = games_scores_add_score (highscores, score);
  }

  if (show_score_dialog (pos, TRUE) == GTK_RESPONSE_REJECT) {
    gtk_main_quit ();
  } else {
    new_game ();
  }
}

void
update_tile_size (gint screen_width, gint screen_height)
{
  gint xt_size, yt_size;

  /* We aim for the gap and the corners to be 1/2 a tile wide. */
  xt_size = (2 * screen_width) / (4 * size + 3);
  yt_size = screen_height / (size + 1);
  tile_size = MIN (xt_size, yt_size);
  gap = (screen_width - 2 * size * tile_size) / 3;
  xborder = gap;
  yborder = (screen_height - size * tile_size) / 2;

  /* Set tile edge to a percentage of the tile size */
  tile_border_size = 0.05 * tile_size;
  if (tile_border_size < 1.0)
    tile_border_size = 1.0;
  else if (tile_border_size > 5.0)
    tile_border_size = 5.0;

  /* Make arrow less sunken */
  arrow_border_size = 0.5 * tile_border_size;
  if (arrow_border_size < 1.0)
    arrow_border_size = 1.0; 

  /* Rebuild the tile/socket vertices when required */
  rebuild_vertices = TRUE;
}

gboolean
configure_space (GtkWidget * widget, GdkEventConfigure * event)
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

  if (!space->window)
    return;

  region = gdk_drawable_get_clip_region (GDK_DRAWABLE (space->window));
  gdk_window_begin_paint_region (space->window, region);

  gdk_window_clear (space->window);
  gdk_draw_rectangle (space->window, bg_gc, TRUE, 0, 0, -1, -1);
  gdk_draw_rectangle (buffer, bg_gc, TRUE, 0, 0, -1, -1);
  for (y = 0; y < size; y++)
    for (x = 0; x < size * 2; x++)
      gui_draw_pixmap (buffer, x, y, FALSE);
   
  gui_draw_arrow(buffer);

  gdk_window_end_paint (space->window);
  gdk_region_destroy (region);
}

void
redraw_left (void)
{
  gint x, y;
  GdkRegion *region;
  GdkRectangle rect =
    { xborder, yborder, tile_size * size, tile_size * size };

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

  status_bar = gtk_statusbar_new ();
  gtk_statusbar_set_has_resize_grip (GTK_STATUSBAR (status_bar), FALSE);
  gtk_box_pack_start (GTK_BOX (status_bar), time_box, FALSE, FALSE, 0);

  return status_bar;
}

void
message (gchar * message)
{
  guint context_id;

  context_id =
    gtk_statusbar_get_context_id (GTK_STATUSBAR (statusbar), "mesasge");
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

  mover.window = gdk_window_new (space->window, &attributes,
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

  for (y = 0; y < size; y++)
    for (x = 0; x < size; x++)
      tiles[y][x].status = UNUSED;

  for (y = 0; y < size; y++)
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
      tiles[y][x].e = tiles[y][x + 1].w;
  for (y = 0; y < size - 1; y++)
    for (x = size; x < size * 2; x++)
      tiles[y][x].s = tiles[y + 1][x].n;

  /* Copy tiles to orig_tiles */
  for (y = 0; y < size; y++)
    for (x = 0; x < size; x++)
      orig_tiles[y][x] = tiles[y][x + size];

  /* Unsort */
  j = 0;
  do {
    for (i = 0; i < size * size * size; i++) {
      x = g_random_int () % size + size;
      y = g_random_int () % size;
      x1 = g_random_int () % size + size;
      y1 = g_random_int () % size;
      tmp = tiles[y1][x1];
      tiles[y1][x1] = tiles[y][x];
      tiles[y][x] = tmp;
    }
  } while (tiles[0][size].e == tiles[0][size + 1].w && j++ < 8);
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

  if (!space->window)
    return;

  region = gdk_drawable_get_clip_region (GDK_DRAWABLE (space->window));
  gdk_window_begin_paint_region (space->window, region);
  gdk_draw_rectangle (space->window, bg_gc, TRUE, 0, 0, -1, -1);

  for (y = 0; y < size; y++) {
    for (x = 0; x < size * 2; x++) {
      which = tiles[y][x].status;

      xadd = x * tile_size + xborder + (x >= size) * gap;
      yadd = y * tile_size + yborder;

      if (which == USED)
	gui_draw_tile (buffer, GTK_STATE_NORMAL, xadd, yadd, 0, 0, 0, 0, 
		       FALSE);
      else
	gui_draw_socket (buffer, GTK_STATE_NORMAL, xadd, yadd);

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
create_menu (GtkUIManager * ui_manager)
{
  gint i;
  GtkActionGroup *action_group;
  GtkAction *action;

  action_group = gtk_action_group_new ("actions");

  gtk_action_group_set_translation_domain (action_group, GETTEXT_PACKAGE);
  gtk_action_group_add_actions (action_group, action_entry,
				G_N_ELEMENTS (action_entry), window);
  gtk_action_group_add_radio_actions (action_group, size_action_entry,
				      G_N_ELEMENTS (size_action_entry), -1,
				      G_CALLBACK (size_cb), NULL);

  gtk_ui_manager_insert_action_group (ui_manager, action_group, 0);
  gtk_ui_manager_add_ui_from_string (ui_manager, ui_description, -1, NULL);

  new_game_action = gtk_action_group_get_action (action_group, "NewGame");
  pause_action = gtk_action_group_get_action (action_group, "PauseGame");
  resume_action = gtk_action_group_get_action (action_group, "ResumeGame");
  hint_action = gtk_action_group_get_action (action_group, "Hint");
  solve_action = gtk_action_group_get_action (action_group, "Solve");
  scores_action = gtk_action_group_get_action (action_group, "Scores");
  move_up_action = gtk_action_group_get_action (action_group, "MoveUp");
  move_left_action = gtk_action_group_get_action (action_group, "MoveLeft");
  move_right_action = gtk_action_group_get_action (action_group, "MoveRight");
  move_down_action = gtk_action_group_get_action (action_group, "MoveDown");
  fullscreen_action =
    gtk_action_group_get_action (action_group, "Fullscreen");
  leave_fullscreen_action =
    gtk_action_group_get_action (action_group, "LeaveFullscreen");

  set_fullscreen_actions (FALSE);

  gtk_action_group_add_toggle_actions (action_group, toggles,
				       G_N_ELEMENTS (toggles), NULL);
  action = gtk_action_group_get_action (action_group, "Colours");
  gtk_toggle_action_set_active (GTK_TOGGLE_ACTION (action), coloured_tiles);
  action = gtk_action_group_get_action (action_group, "ClickToMove");
  gtk_toggle_action_set_active (GTK_TOGGLE_ACTION (action), click_to_move);

  for (i = 0; i < G_N_ELEMENTS (size_action_entry); i++)
    size_action[i] =
      gtk_action_group_get_action (action_group, size_action_entry[i].name);

  games_stock_set_pause_actions (pause_action, resume_action);
  return gtk_ui_manager_get_widget (ui_manager, "/MainMenu");
}

void
make_buffer (GtkWidget * widget)
{

  if (buffer)
    g_object_unref (buffer);

  buffer = gdk_pixmap_new (widget->window, widget->allocation.width,
			   widget->allocation.height, -1);

}

void
new_game (){
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
new_game_cb (GtkAction * action, gpointer data)
{
  new_game ();
}

void
quit_game_cb (void)
{
  gtk_main_quit ();
}

#ifdef HAVE_GNOME

static gint
save_state (GnomeClient * client, gint phase,
	    GnomeRestartStyle save_style, gint shutdown,
	    GnomeInteractStyle interact_style, gint fast,
	    gpointer client_data)
{
  gchar *argv[20];
  gint i;
  gint xpos, ypos;

  gdk_window_get_origin (window->window, &xpos, &ypos);

  i = 0;
  argv[i++] = (char *) client_data;
  argv[i++] = "-x";
  argv[i++] = g_strdup_printf ("%d", xpos);
  argv[i++] = "-y";
  argv[i++] = g_strdup_printf ("%d", ypos);

  gnome_client_set_restart_command (client, i, argv);
  gnome_client_set_clone_command (client, 0, NULL);

  g_free (argv[2]);
  g_free (argv[4]);

  return TRUE;
}

#endif /* HAVE_GNOME */

void
size_cb (GtkAction * action, gpointer data)
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
  games_scores_set_category (highscores, scorecats[size - 2].key);
  games_conf_set_integer (NULL, KEY_GRID_SIZE, size);
  gtk_action_activate (new_game_action);
}

void
show_colours_toggle_cb (GtkToggleAction * togglebutton, gpointer data)
{
  coloured_tiles = gtk_toggle_action_get_active (togglebutton);
  games_conf_set_boolean (NULL, KEY_SHOW_COLOURS, coloured_tiles);
  redraw_all ();
}

void
clickmove_toggle_cb(GtkToggleAction * togglebutton, gpointer data)
{
  click_to_move = gtk_toggle_action_get_active (togglebutton);
  games_conf_set_boolean (NULL, KEY_CLICK_MOVE, click_to_move);
}

void
move_up_cb (GtkAction * action, gpointer data)
{
  move_column ('n');
}

void
move_left_cb (GtkAction * action, gpointer data)
{
  move_column ('w');
}

void
move_right_cb (GtkAction * action, gpointer data)
{
  move_column ('e');
}

void
move_down_cb (GtkAction * action, gpointer data)
{
  move_column ('s');
}

gint
compare_tile (tile * t1, tile * t2)
{
  if (t1->e == t2->e && t1->w == t2->w && t1->s == t2->s && t1->n == t2->n)
    return 0;
  return 1;
}

void
find_first_tile (gint status, gint * xx, gint * yy)
{
  gint x, y;
  for (y = 0; y < size; y++)
    for (x = size; x < size * 2; x++)
      if (tiles[y][x].status == status) {
	*xx = x;
	*yy = y;
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
    gdk_window_move (mover.window, hint_src_x - (gint) (count * dx),
		     (gint) hint_src_y - (gint) (count * dy));
    count++;
  }
  if (count > COUNT) {
    hint_moving = 0;
    count = 0;
    setup_mover (hint_dest_x + 1, hint_dest_y + 1, RELEASE);
    g_source_remove (timer_timeout);
    gtk_widget_set_sensitive (GTK_WIDGET (space), TRUE);
    if (game_state != playing)
      return;
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
hint_cb (GtkAction * action, gpointer data)
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
  if (x2 != 0 && tiles[y2][x2 - 1].status == USED
      && tiles[y2][x2 - 1].e != hint_tile.w) {
    find_first_tile (UNUSED, &x1, &y1);
    hint_move (x2 - 1, y2, x1, y1);
    return;
  }

  /* East */
  if (x2 != size - 1 && tiles[y2][x2 + 1].status == USED
      && tiles[y2][x2 + 1].w != hint_tile.e) {
    find_first_tile (UNUSED, &x1, &y1);
    hint_move (x2 + 1, y2, x1, y1);
    return;
  }

  /* North */
  if (y2 != 0 && tiles[y2 - 1][x2].status == USED
      && tiles[y2 - 1][x2].s != hint_tile.n) {
    find_first_tile (UNUSED, &x1, &y1);
    hint_move (x2, y2 - 1, x1, y1);
    return;
  }

  /* South */
  if (y2 != size - 1 && tiles[y2 + 1][x2].status == USED
      && tiles[y2 + 1][x2].n != hint_tile.s) {
    find_first_tile (UNUSED, &x1, &y1);
    hint_move (x2, y2 + 1, x1, y1);
    return;
  }

  hint_move (x1, y1, x2, y2);
}

void
solve_cb (GtkAction * action, gpointer data)
{
  solve_me = 1;
  gtk_action_activate (hint_action);
}

void
help_cb (GtkAction * action, gpointer data)
{
#ifdef HAVE_GNOME
  gnome_help_display ("gnotravex.xml", NULL, NULL);
#else
#warning need to port help to gtk-only!
#endif /* HAVE_GNOME */
}

void
about_cb (GtkAction * action, gpointer data)
{
  const gchar *authors[] = { "Lars Rydlinge", NULL };

  const gchar *documenters[] = { "Rob Bradford", NULL };

  gchar *license = games_get_license (_(APPNAME_LONG));

  gtk_show_about_dialog (GTK_WINDOW (window),
#if GTK_CHECK_VERSION (2, 11, 0)
                         "program-name", _(APPNAME_LONG),
#else
			 "name", _(APPNAME_LONG),
#endif
			 "version", VERSION,
			 "comments",
			 _("GNOME Tetravex is a simple puzzle where "
			   "pieces must be positioned so that the "
			   "same numbers are touching each other.\n\n"
			   "Tetravex is a part of GNOME Games."),
			 "copyright",
			 "Copyright \xc2\xa9 1999-2007 Lars Rydlinge",
			 "license", license,
                         "wrap-license", TRUE,
                         "authors", authors,
			 "documenters", documenters,
                         "translator-credits", _("translator-credits"),
                         "logo-icon-name", "gnome-tetravex",
                         "website", "http://www.gnome.org/projects/gnome-games",
                         "website-label", _("GNOME Games web site"),
                         NULL);
  g_free (license);
}

static void
set_fullscreen_actions (gboolean is_fullscreen)
{
  gtk_action_set_sensitive (leave_fullscreen_action, is_fullscreen);
  gtk_action_set_visible (leave_fullscreen_action, is_fullscreen);

  gtk_action_set_sensitive (fullscreen_action, !is_fullscreen);
  gtk_action_set_visible (fullscreen_action, !is_fullscreen);
}

static void
fullscreen_cb (GtkAction * action)
{
  if (action == fullscreen_action) {
    gtk_window_fullscreen (GTK_WINDOW (window));
  } else {
    gtk_window_unfullscreen (GTK_WINDOW (window));
  }
}

/* Just in case something else takes us to/from fullscreen. */
static gboolean
window_state_cb (GtkWidget * widget, GdkEventWindowState * event)
{
  if (event->changed_mask & GDK_WINDOW_STATE_FULLSCREEN)
    set_fullscreen_actions (event->new_window_state &
			    GDK_WINDOW_STATE_FULLSCREEN);
    
  return FALSE;
}

static GdkPixmap *
get_pixmap (const char *filename)
{
  GdkPixmap *ret;
  GdkPixbuf *im;
  char *path;
  GError *error = NULL;

  path = g_build_filename (PIXMAPDIR, filename, NULL);
  im = gdk_pixbuf_new_from_file (path, &error);
  if (im != NULL) {
    gdk_pixbuf_render_pixmap_and_mask_for_colormap (im,
						    gdk_colormap_get_system
						    (), &ret, NULL, 127);
    gdk_pixbuf_unref (im);
  } else {
    g_warning ("Error loading file '%s': %s\n", path, error->message);
    g_error_free (error);

    ret = NULL;
  }
  g_free (path);

  return ret;
}

static void
load_pixmaps (void)
{
  default_background_pixmap = get_pixmap ("baize.png");
}

