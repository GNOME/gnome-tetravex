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
#include <time.h>

#define APPNAME "gnotravex"
#define APPNAME_LONG "Gnome Tetravex"
#define GNOTRAVEX_VERSION "0.20"

#define TILE_SIZE 51

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
GdkPixmap *tiles_pixmap = NULL;
GdkColor bg_color;

typedef struct _mover {
  GdkWindow *window;
  GdkPixmap *pixmap;
  int xstart,ystart;
  int xtarget,ytarget;
  int xoff, yoff;
} Mover;

Mover mover;

typedef struct _tile {
  int n,w,e,s;
  int status;
} tile;

tile tiles[9][18];
tile orig_tiles[9][9];

gint SIZE=3;
int paused=0;
int have_been_hinted=0;
int solve_me=0;
int hint_moving = 0;
int session_flag = 0;
int session_xpos = 0;
int session_ypos = 0;
int session_position  = 0;
guint timer_timeout = 0;

void make_buffer(GtkWidget *);
void create_window();
void create_menu();
void create_space();
void create_mover();
void create_statusbar();
void get_bg_color();
void message(gchar *);
void load_image();
void new_board(int);
void redraw_all();
void redraw_left();
void gui_draw_pixmap(GdkPixmap *, gint, gint);
int setup_mover(int,int,int);
int valid_drop(int,int);
void move_column(unsigned char);
int game_over();
void game_score();
gint timer_cb();
void timer_start();
void pause_cb();
static int save_state(GnomeClient*, gint, GnomeRestartStyle, gint, GnomeInteractStyle, gint, gpointer);


/* ------------------------- MENU ------------------------ */
void new_game_cb(GtkWidget *, gpointer);
void quit_game_cb(GtkWidget *, gpointer);
void size_cb(GtkWidget *, gpointer);
void move_cb(GtkWidget *, gpointer);
void about_cb(GtkWidget *, gpointer);
void score_cb(GtkWidget *, gpointer);
void hint_cb(GtkWidget *, gpointer);
void solve_cb(GtkWidget *, gpointer);

GnomeUIInfo game_menu[] = {
  GNOMEUIINFO_MENU_NEW_GAME_ITEM(new_game_cb, NULL),

  GNOMEUIINFO_MENU_PAUSE_GAME_ITEM(pause_cb, NULL),

  GNOMEUIINFO_SEPARATOR,

  GNOMEUIINFO_MENU_HINT_ITEM(hint_cb, NULL),

  { GNOME_APP_UI_ITEM, N_("Sol_ve"), N_("Solve the game"),
    solve_cb, NULL, NULL,GNOME_APP_PIXMAP_STOCK,
    GNOME_STOCK_MENU_REFRESH, 0, 0, NULL },

  GNOMEUIINFO_SEPARATOR,

  GNOMEUIINFO_MENU_SCORES_ITEM(score_cb, NULL),

  GNOMEUIINFO_SEPARATOR,

  GNOMEUIINFO_MENU_EXIT_ITEM(quit_game_cb, NULL),

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
  GNOMEUIINFO_HELP("gnotravex"),
  GNOMEUIINFO_MENU_ABOUT_ITEM(about_cb, NULL),
  GNOMEUIINFO_END
};

GnomeUIInfo settings_menu[] = {
  GNOMEUIINFO_RADIOLIST(size_radio_list),
  GNOMEUIINFO_END
};

GnomeUIInfo main_menu[] = {
  GNOMEUIINFO_MENU_GAME_TREE(game_menu),
  GNOMEUIINFO_SUBTREE(N_("_Move"), move_menu),
  GNOMEUIINFO_MENU_SETTINGS_TREE(settings_menu),
  GNOMEUIINFO_MENU_HELP_TREE(help_menu),
  GNOMEUIINFO_END
};

static const struct poptOption options[] = {
  {NULL, 'x', POPT_ARG_INT, &session_xpos, 0, NULL, NULL},
  {NULL, 'y', POPT_ARG_INT, &session_ypos, 0, NULL, NULL},
  { "size", 's', POPT_ARG_INT, &SIZE,0, N_("Size of board (2-6)"), N_("SIZE") },
  { NULL, '\0', 0, NULL, 0 }
};

/* ------------------------------------------------------- */


int main (int argc, char **argv){
  GnomeClient *client;

  gnome_score_init(APPNAME);

  bindtextdomain(PACKAGE, GNOMELOCALEDIR);
  textdomain(PACKAGE);

  gnome_init_with_popt_table(APPNAME, VERSION, argc, argv, options, 0, NULL);
  gnome_window_icon_set_default_from_file (GNOME_ICONDIR"/gnotravex/gnome-gnotravex.png");
  client = gnome_master_client();
  gtk_object_ref(GTK_OBJECT(client));
  gtk_object_sink(GTK_OBJECT(client));
  
  gtk_signal_connect(GTK_OBJECT (client), "save_yourself", GTK_SIGNAL_FUNC (save_state), argv[0]);
  gtk_signal_connect(GTK_OBJECT(client), "die", GTK_SIGNAL_FUNC(quit_game_cb), argv[0]);

  if(SIZE<2 || SIZE>6) SIZE=3;
  
  create_window();
  create_menu();
  load_image();

  create_space(); 
  create_statusbar();

  if(session_xpos >= 0 && session_ypos >= 0)
    gtk_widget_set_uposition(window, session_xpos, session_ypos);
    
  gtk_widget_show(window);
  create_mover();

  new_game_cb(space,NULL);
  
  gtk_check_menu_item_set_state(GTK_CHECK_MENU_ITEM(size_radio_list[SIZE-2].widget),TRUE);

  gtk_main ();
  
  return 0;
}

void create_window(){
  window = gnome_app_new(APPNAME, N_(APPNAME_LONG));
  gtk_window_set_policy(GTK_WINDOW(window), FALSE, FALSE, TRUE);
  gtk_widget_realize(window);
  gtk_signal_connect(GTK_OBJECT(window), "delete_event", GTK_SIGNAL_FUNC(quit_game_cb), NULL);
}

gint expose_space(GtkWidget *widget, GdkEventExpose *event){ 
  gdk_draw_pixmap(widget->window, 
		  widget->style->fg_gc[GTK_WIDGET_STATE(widget)], 
		  buffer, event->area.x, event->area.y, 
		  event->area.x, event->area.y, 
		  event->area.width, event->area.height);
  return FALSE; 
}

int button_down = 0;

gint button_press_space(GtkWidget *widget, GdkEventButton *event){ 
  if(!paused){
    if(event->button == 1){
      if(button_down==1){
	setup_mover(event->x,event->y,RELEASE); /* Seen it happened */
	button_down = 0;
	return FALSE;
      }
      if(setup_mover(event->x,event->y,PRESS)){
	button_down = 1;
      }
    }
  }
  return FALSE;
}

gint button_release_space(GtkWidget *widget, GdkEventButton *event){ 
  if(event->button == 1){
    if(button_down==1){
      setup_mover(event->x,event->y,RELEASE);
    }
    button_down = 0;
  }
  return FALSE;
}

gint button_motion_space(GtkWidget *widget, GdkEventButton *event){ 
  if(button_down == 1){
    gdk_window_move(mover.window,event->x-mover.xoff,event->y-mover.yoff);
  }
  return FALSE;
}


void gui_draw_pixmap(GdkPixmap *target, gint x, gint y){
  int which,xadd,yadd;
  GdkGC *gc;
  GdkRectangle area;

  which = tiles[y][x].status;

  if(target==buffer){
    xadd = x * TILE_SIZE + CORNER + (x >= SIZE)*GAP;
    yadd = y * TILE_SIZE + CORNER;
    gc = space->style->black_gc;
  }

  if(target==mover.pixmap){
    xadd = 0;
    yadd = 0;
    gc = gdk_gc_new(mover.pixmap);
    gdk_window_set_back_pixmap(mover.window, mover.pixmap, 0);
  }

  gdk_draw_pixmap(target, gc, tiles_pixmap,
		  which * TILE_SIZE, 0, 
		  xadd, yadd, TILE_SIZE, TILE_SIZE);
  if(which == USED){
    /* North */
    gdk_draw_pixmap(target,
		    gc,
		    tiles_pixmap,
		    tiles[y][x].n * 10,
		    TILE_SIZE+1, 
		    xadd + TILE_SIZE/2-3,
		    yadd + 5,
		    9,
		    13);
  
    /* South */
    gdk_draw_pixmap(target,
		    gc,
		    tiles_pixmap,
		    tiles[y][x].s * 10,
		    TILE_SIZE+1, 
		    xadd + TILE_SIZE/2-3,
		    yadd + TILE_SIZE-17,
		    9,
		    13);
    
    /* West */
    gdk_draw_pixmap(target,
		    gc,
		    tiles_pixmap,
		    tiles[y][x].w * 10,
		    TILE_SIZE+1, 
		    xadd +5,
		    yadd + TILE_SIZE/2-6,
		    9,
		    13);
  
    /* East */
    gdk_draw_pixmap(target,
		    gc,
		    tiles_pixmap,
		    tiles[y][x].e * 10,
		    TILE_SIZE+1, 
		    xadd + TILE_SIZE-13,
		    yadd + TILE_SIZE/2-6,
		    9,
		    13);
  }
  area.x = xadd;
  area.y = yadd;
  area.width = TILE_SIZE;
  area.height = TILE_SIZE;
  gtk_widget_draw (space, &area);

  if(target==mover.pixmap)
    gdk_gc_destroy(gc);
}

void get_pixeltilexy(int x,int y,int *xx,int *yy){
  int sumx=CORNER,sumy=CORNER;
  
  if(x>=SIZE)
    sumx += GAP;
  
  sumx += x*TILE_SIZE;
  sumy += y*TILE_SIZE;
  *xx = sumx;
  *yy = sumy;
}

void get_tilexy(int x,int y,int *xx,int *yy){
  
  x = x - CORNER; y = y - CORNER;
  if(x/TILE_SIZE < SIZE)
    *xx = x/TILE_SIZE;
  else 
    *xx = SIZE + (x-(GAP+TILE_SIZE*SIZE))/TILE_SIZE;
  *yy = (y/TILE_SIZE);

}

void get_offsetxy(int x,int y,int *xoff,int *yoff){

  x = x - CORNER; y = y - CORNER;
  if(x/TILE_SIZE < SIZE)
    *xoff = x % TILE_SIZE;
  else 
    *xoff = (x-(GAP+TILE_SIZE*SIZE)) % TILE_SIZE;
  *yoff = y % TILE_SIZE;
}

int setup_mover(int x,int y,int status){
  int xx,yy;
  
  if(status==PRESS){
    get_tilexy(x,y,&xx,&yy);
    get_offsetxy(x,y,&mover.xoff,&mover.yoff);
    if(tiles[yy][xx].status==UNUSED || mover.yoff < 0 || mover.xoff < 0
       || yy>=SIZE || xx>=SIZE*2)
      return 0; /* No move */

    mover.xstart = xx; mover.ystart = yy;
    gdk_window_resize(mover.window, TILE_SIZE, TILE_SIZE);
    mover.pixmap = gdk_pixmap_new(mover.window, TILE_SIZE,TILE_SIZE,
				  gdk_window_get_visual(mover.window)->depth);
    gdk_window_move(mover.window,x - mover.xoff,y - mover.yoff);
    gui_draw_pixmap(mover.pixmap,xx,yy);
    gdk_window_show(mover.window);
    tiles[yy][xx].status = UNUSED;
    gui_draw_pixmap(buffer,xx,yy);
    return 1;
  }

  if(status==RELEASE){
    get_tilexy(x-mover.xoff+TILE_SIZE/2,y-mover.yoff+TILE_SIZE/2,&xx,&yy);
    if(tiles[yy][xx].status==UNUSED && xx>=0 && xx<SIZE*2 && yy>=0 && yy<SIZE
       && valid_drop(xx,yy)){
      tiles[yy][xx] = tiles[mover.ystart][mover.xstart];
      tiles[yy][xx].status = USED;
      gui_draw_pixmap(buffer,xx,yy);
      gui_draw_pixmap(buffer,mover.xstart,mover.ystart);
    } else {
      tiles[mover.ystart][mover.xstart].status = USED;
      gui_draw_pixmap(buffer,mover.xstart,mover.ystart);
    }
    gdk_window_hide(mover.window);
    if(mover.pixmap) gdk_pixmap_unref(mover.pixmap);
    mover.pixmap = NULL;
    if(game_over()){
      paused = 1;
      gtk_clock_stop(GTK_CLOCK(timer));
      if(!have_been_hinted){
	message(_("Puzzle solved! Well done!"));
	game_score();
      } else {
	message(_("Puzzle solved!"));
      }
    }
    return 1;
  }
  return 0;
}

int valid_drop(int x,int y){
  int xx,yy;
  xx = mover.xstart;
  yy = mover.ystart;

  if(x>=SIZE) return 1;
  
  /* West */
  if(x!=0 && tiles[y][x-1].status == USED && tiles[y][x-1].e != tiles[yy][xx].w) return 0; 
  /* East */
  if(x!=SIZE-1 && tiles[y][x+1].status == USED && tiles[y][x+1].w != tiles[yy][xx].e) return 0;
  /* North */
  if(y!=0 && tiles[y-1][x].status == USED && tiles[y-1][x].s != tiles[yy][xx].n) return 0; 
  /* South */
  if(y!=SIZE-1 && tiles[y+1][x].status == USED && tiles[y+1][x].n != tiles[yy][xx].s) return 0;

  return 1;
}

void move_tile(int xx,int yy,int x,int y){
  tiles[yy][xx] = tiles[y][x];
  tiles[y][x].status = UNUSED;
}

void move_column(unsigned char dir){
  int x,y;
  switch(dir){
  case 'n':
    for(x=0;x<SIZE;x++) if(tiles[0][x].status == USED) return;
    for(y=1;y<SIZE;y++)
      for(x=0;x<SIZE;x++)
	move_tile(x,y-1,x,y); 
    redraw_left();
    break;
  case 's':
    for(x=0;x<SIZE;x++) if(tiles[SIZE-1][x].status == USED) return;
    for(y=SIZE-2;y>=0;y--)
      for(x=0;x<SIZE;x++)
	move_tile(x,y+1,x,y); 
    redraw_left();
    break;
  case 'w':
    for(y=0;y<SIZE;y++) if(tiles[y][0].status == USED) return;
    for(y=0;y<SIZE;y++)
      for(x=1;x<SIZE;x++)
	move_tile(x-1,y,x,y); 
    redraw_left();
    break;
  case 'e':
    for(y=0;y<SIZE;y++) if(tiles[y][SIZE-1].status == USED) return;
    for(y=0;y<SIZE;y++)
      for(x=SIZE-2;x>=0;x--)
	move_tile(x+1,y,x,y); 
    redraw_left();
    break;
  default:
    break;
  }
}

int game_over(){
  int x,y;
  for(y=0;y<SIZE;y++)
    for(x=0;x<SIZE;x++)
      if(tiles[y][x].status == UNUSED) return 0;
  return 1;
}

void score_cb(GtkWidget *widget, gpointer data){
  gchar level[5];
  sprintf(level,"%dx%d",SIZE,SIZE);
  gnome_scores_display (_(APPNAME_LONG), APPNAME, level, 0);
}

void game_score(){
  gint pos;
  time_t seconds;
  gfloat score;
  gchar level[5];
  
  sprintf(level,"%dx%d",SIZE,SIZE);
  seconds = GTK_CLOCK(timer)->stopped;
  gtk_clock_set_seconds(GTK_CLOCK(timer), (int) seconds);
  score = (gfloat) (seconds / 60) + (gfloat) (seconds % 60) / 100;
  pos = gnome_score_log(score,level,FALSE);
  gnome_scores_display (_(APPNAME_LONG), APPNAME, level, pos);
}

gint configure_space(GtkWidget *widget, GdkEventConfigure *event){
  make_buffer(widget);
  redraw_all();
  return(TRUE);
}

void redraw_all(){
  guint x, y;
  GdkGC *draw_gc;
  draw_gc = gdk_gc_new(space->window);
  get_bg_color(); 
  gdk_window_set_background(space->window, &bg_color);
  gdk_gc_set_background(draw_gc,&bg_color);
  gdk_gc_set_foreground(draw_gc,&bg_color);
  gdk_draw_rectangle (buffer, draw_gc, TRUE, 0, 0, -1, -1);
  gdk_window_clear(space->window);
  for(y = 0; y < SIZE; y++)
    for(x = 0; x < SIZE*2; x++)
      gui_draw_pixmap(buffer, x, y);
  if(draw_gc)
    gdk_gc_unref(draw_gc);
}

void redraw_left(){
  int x,y;
  for(y = 0; y < SIZE; y++)
    for(x = 0; x < SIZE; x++)
      gui_draw_pixmap(buffer, x, y);
}

void create_space(){
  gtk_widget_push_visual(gdk_imlib_get_visual());
  gtk_widget_push_colormap(gdk_imlib_get_colormap());
  space = gtk_drawing_area_new();
  gtk_widget_pop_colormap();
  gtk_widget_pop_visual();
  gnome_app_set_contents(GNOME_APP(window),space);
  gtk_drawing_area_size(GTK_DRAWING_AREA(space),CORNER*2 + GAP+ SIZE*TILE_SIZE*2,SIZE*TILE_SIZE + CORNER*2);
  gtk_widget_set_events(space, GDK_EXPOSURE_MASK | GDK_BUTTON_PRESS_MASK | GDK_POINTER_MOTION_MASK | GDK_BUTTON_RELEASE_MASK);
  gtk_widget_realize(space);
  
  gtk_signal_connect(GTK_OBJECT(space), "expose_event", 
		     GTK_SIGNAL_FUNC(expose_space), NULL);
  gtk_signal_connect(GTK_OBJECT(space), "configure_event", 
		     GTK_SIGNAL_FUNC(configure_space), NULL);
  gtk_signal_connect(GTK_OBJECT(space), "button_press_event", 
		     GTK_SIGNAL_FUNC(button_press_space), NULL);
  gtk_signal_connect (GTK_OBJECT(space),"button_release_event",
                      GTK_SIGNAL_FUNC(button_release_space), NULL);
  gtk_signal_connect (GTK_OBJECT(space), "motion_notify_event",
                      GTK_SIGNAL_FUNC(button_motion_space), NULL);
  gtk_widget_show(space);
}


void create_statusbar(){
  GtkWidget *time_label,*time_box;
  time_box = gtk_hbox_new(0, FALSE);
  time_label = gtk_label_new (_("Time:"));
  gtk_box_pack_start (GTK_BOX(time_box), time_label, FALSE, FALSE, 0);
  timer = gtk_clock_new (GTK_CLOCK_INCREASING);
  gtk_box_pack_start (GTK_BOX(time_box), timer, FALSE, FALSE, 0);
  gtk_widget_show (time_label);
  gtk_widget_show (timer);
  gtk_widget_show (time_box);

  statusbar = gnome_appbar_new(FALSE, TRUE, GNOME_PREFERENCES_USER);
  gtk_box_pack_end(GTK_BOX(statusbar), time_box, FALSE, FALSE, 0);
  gnome_app_set_statusbar(GNOME_APP(window), statusbar);

  gnome_app_install_menu_hints(GNOME_APP (window), main_menu);

  /* FIXME */
  /*  gtk_statusbar_push(GTK_STATUSBAR(statusbar), statusbar_id,APPNAME_LONG); */
}

void message(gchar *message){
  gnome_appbar_pop(GNOME_APPBAR (statusbar));
  gnome_appbar_push(GNOME_APPBAR (statusbar), message);
}

void create_mover(){
  GdkWindowAttr attributes;

  attributes.wclass = GDK_INPUT_OUTPUT;
  attributes.window_type = GDK_WINDOW_CHILD;
  attributes.event_mask = 0;
  attributes.width = TILE_SIZE;
  attributes.height = TILE_SIZE;
  attributes.colormap = gdk_window_get_colormap (space->window);
  attributes.visual = gdk_window_get_visual (space->window);
  
  mover.window = gdk_window_new(space->window, &attributes,
			 (GDK_WA_VISUAL | GDK_WA_COLORMAP));
  mover.pixmap = NULL;
}

void load_image(){

  char *tmp;
  char *fname;
  GdkImlibImage *image;
  GdkVisual *visual;

  tmp = g_strconcat("gnotravex/", "gnotravex.png", NULL);
  fname = gnome_unconditional_pixmap_file(tmp);
  g_free(tmp);
  if(!g_file_exists(fname)) {
    g_print(N_("Could not find \'%s\' pixmap file\n")\
	    , fname);
    exit(1);
  }
  image = gdk_imlib_load_image(fname);

  visual = gdk_imlib_get_visual();
  if(visual->type != GDK_VISUAL_TRUE_COLOR) {
    gdk_imlib_set_render_type(RT_PLAIN_PALETTE);
  }
  gdk_imlib_render(image, image->rgb_width, image->rgb_height);
  tiles_pixmap = gdk_imlib_move_image(image);
  
  gdk_imlib_destroy_image(image);
  g_free(fname);
}

void new_board(int size){
  static int myrand = 498;
  int x,y,x1,y1,i,j;
  tile tmp;

  have_been_hinted = 0;
  solve_me = 0;

  if(timer_timeout) {
    gtk_timeout_remove(timer_timeout);
    gtk_widget_set_sensitive (GTK_WIDGET(space), TRUE);
  }
  
  if(button_down || hint_moving){
    setup_mover(0,0,RELEASE);
    button_down = 0;
    hint_moving = 0;
  }

  srand(time(NULL)+myrand);

  myrand += 17;

  for(y=0;y<size;y++)
    for(x=0;x<size;x++)
      tiles[y][x].status = UNUSED;

  for(y=0;y<size;y++)
    for(x=size;x<size*2;x++){
      tiles[y][x].status = USED;
      tiles[y][x].n = rand()%10;
      tiles[y][x].s = rand()%10;
      tiles[y][x].w = rand()%10;
      tiles[y][x].e = rand()%10;
    }

  /* Sort */
  for(y=0;y<size;y++)
    for(x=size;x<size*2-1;x++)
      tiles[y][x].e = tiles[y][x+1].w;
  for(y=0;y<size-1;y++)
    for(x=size;x<size*2;x++)
      tiles[y][x].s = tiles[y+1][x].n;

  /* Copy tiles to orig_tiles */
  for(y=0; y<size; y++)
    for(x=0; x<size; x++)
      orig_tiles[y][x] = tiles[y][x+size];

  /* Unsort */
  j=0;
  do {
    for(i=0;i<size*size*size;i++){
      x = rand() % size +size;
      y = rand() % size;
      x1 = rand() % size + size;
      y1 = rand() % size;
      tmp = tiles[y1][x1];
      tiles[y1][x1] = tiles[y][x];
      tiles[y][x] = tmp;
    }
  } while(tiles[0][SIZE].e == tiles[0][SIZE+1].w && j++ < 8);
}

void get_bg_color(){
  GdkImage *tmpimage;
  tmpimage = gdk_image_get(tiles_pixmap, 0, 0, 9, 6);
  bg_color.pixel = gdk_image_get_pixel(tmpimage, 8, 5);
  gdk_image_destroy(tmpimage);
}

void pause_cb(){
  if(game_over()) return;
  paused = !paused;
  if(paused){
    message(_("... Game paused ..."));
    gtk_clock_stop(GTK_CLOCK(timer));
  } else {
    message("");
    gtk_clock_start(GTK_CLOCK(timer));
  }
}

void timer_start(){
  gtk_clock_stop(GTK_CLOCK(timer));
  gtk_clock_set_seconds(GTK_CLOCK(timer), 0);
  gtk_clock_start(GTK_CLOCK(timer));
}

/* --------------------------- MENU --------------------- */
void create_menu(){
  gnome_app_create_menus(GNOME_APP(window), main_menu);
}

void make_buffer (GtkWidget *widget) {

  if(buffer)
    gdk_pixmap_unref(buffer);
  
  buffer = gdk_pixmap_new(widget->window, widget->allocation.width, widget->allocation.height, -1);

}

void new_game_cb(GtkWidget *widget, gpointer data){
  char str[40];
  widget = space;
  
  new_board(SIZE);
  gtk_drawing_area_size(GTK_DRAWING_AREA(space),CORNER*2 + GAP+ SIZE*TILE_SIZE*2,SIZE*TILE_SIZE + CORNER*2);
  make_buffer(widget);
  redraw_all();
  paused = 0;
  timer_start();
  sprintf(str,_("Playing %dx%d board"),SIZE,SIZE);
  message(str);
}

void quit_game_cb(GtkWidget *widget, gpointer data){
  if(buffer)
    gdk_pixmap_unref(buffer);
  if(tiles_pixmap)
    gdk_pixmap_unref(tiles_pixmap);
  if(mover.pixmap)
    gdk_pixmap_unref(mover.pixmap);

  gtk_main_quit();
}

static char *nstr(int n){
  char buf[20]; sprintf(buf, "%d", n);
  return strdup(buf);
}

static int save_state(GnomeClient *client,gint phase, 
		      GnomeRestartStyle save_style, gint shutdown,
		      GnomeInteractStyle interact_style, gint fast,
		      gpointer client_data){
  char *argv[20];
  int i;
  gint xpos, ypos;
  
  gdk_window_get_origin(window->window, &xpos, &ypos);
  
  i = 0;
  argv[i++] = (char *)client_data;
  argv[i++] = "-x";
  argv[i++] = nstr(xpos);
  argv[i++] = "-y";
  argv[i++] = nstr(ypos);

  gnome_client_set_restart_command(client, i, argv);
  gnome_client_set_clone_command(client, 0, NULL);
  
  free(argv[2]);
  free(argv[4]);
  
  return TRUE;
}


void size_cb(GtkWidget *widget, gpointer data){
  int size;
  size = atoi((gchar *)data);
  SIZE = size;
  new_game_cb(space,NULL);
}

void move_cb(GtkWidget *widget, gpointer data){
  move_column((unsigned char)*((gchar *) data));
}

int compare_tile(tile *t1, tile *t2){
  if(t1->e == t2->e &&
     t1->w == t2->w &&
     t1->s == t2->s &&
     t1->n == t2->n) return 0;
  return 1;
}

void find_first_tile(int status, int *xx, int *yy){
  int x,y,size = SIZE;
  for(y=0;y<size;y++)
    for(x=size;x<size*2;x++)
      if(tiles[y][x].status == status){
	*xx = x; *yy = y;
	return;
      }
}

#define COUNT 15
#define DELAY 10

int hint_src_x,hint_src_y,hint_dest_x,hint_dest_y;

void hint_move_cb(){
  float dx, dy;
  static int count = 0;
  dx = (float) (hint_src_x - hint_dest_x)/COUNT; 
  dy = (float) (hint_src_y - hint_dest_y)/COUNT; 
  if(count <= COUNT){
    gdk_window_move(mover.window, hint_src_x - (int) (count*dx), (int) hint_src_y - (int) (count*dy));
    count++;
  }
  if(count > COUNT){
    hint_moving = 0;
    count = 0;
    setup_mover(hint_dest_x + 1,hint_dest_y + 1,RELEASE);
    gtk_timeout_remove(timer_timeout);
    gtk_widget_set_sensitive (GTK_WIDGET(space), TRUE);
    if(paused) return;
    if(solve_me)
      hint_cb(NULL,NULL);
  }
}

void hint_move(int x1,int y1, int x2, int y2){
  have_been_hinted = 1;
  get_pixeltilexy(x1,y1,&hint_src_x, &hint_src_y);
  get_pixeltilexy(x2,y2,&hint_dest_x, &hint_dest_y);
  setup_mover(hint_src_x + 1,hint_src_y + 1,PRESS);
  hint_moving = 1;
  gtk_widget_set_sensitive (GTK_WIDGET(space), FALSE);
  timer_timeout = gtk_timeout_add (DELAY, (GtkFunction) (hint_move_cb), NULL);
}

void hint_cb(GtkWidget *widget, gpointer data){

  int x1, y1, x2, y2, x, y, size = SIZE;
  tile hint_tile;

  if(game_over() || button_down || paused || hint_moving) return;
  
  find_first_tile(USED,&x,&y);
  x1 = x; y1 = y;
  hint_tile = tiles[y][x];

  /* Find position in original map */
  for(y=0;y<size;y++)
    for(x=0;x<size;x++)
      if(compare_tile(&hint_tile,&orig_tiles[y][x]) == 0){
	if(tiles[y][x].status == USED && compare_tile(&hint_tile,&tiles[y][x])==0){
	  /* Do Nothing */
	} else {
	  x2 = x; y2 = y;
	  x=size; y=size;
	}
      }
  
  /* Tile I want to hint about is busy. Move the busy tile away! */
  if(tiles[y2][x2].status == USED){
    find_first_tile(UNUSED,&x1,&y1);
    hint_move(x2,y2,x1,y1);
    return;
  }
  
  /* West */
  if(x2!=0 && tiles[y2][x2-1].status == USED && tiles[y2][x2-1].e != hint_tile.w){
    find_first_tile(UNUSED,&x1,&y1);
    hint_move(x2-1,y2,x1,y1);
    return;
  }

  /* East */
  if(x2!=SIZE-1 && tiles[y2][x2+1].status == USED && tiles[y2][x2+1].w != hint_tile.e){
    find_first_tile(UNUSED,&x1,&y1);
    hint_move(x2+1,y2,x1,y1);
    return;
  }

  /* North */
  if(y2!=0 && tiles[y2-1][x2].status == USED && tiles[y2-1][x2].s != hint_tile.n){
    find_first_tile(UNUSED,&x1,&y1);
    hint_move(x2,y2-1,x1,y1);
    return;
  }
  
  /* South */
  if(y2!=SIZE-1 && tiles[y2+1][x2].status == USED && tiles[y2+1][x2].n != hint_tile.s){
    find_first_tile(UNUSED,&x1,&y1);
    hint_move(x2,y2+1,x1,y1);
    return;
  }

  hint_move(x1,y1,x2,y2);
}

void solve_cb(GtkWidget *widget, gpointer data){
  solve_me = 1;
  hint_cb(widget,NULL);
}

void about_cb(GtkWidget *widget, gpointer data){
  GtkWidget *about;
  
  const gchar *authors[] = { "Lars Rydlinge", NULL };
  about = gnome_about_new(_(APPNAME_LONG), 
			  GNOTRAVEX_VERSION, 
			  "(C) 1998 Lars Rydlinge",
			  (const char **)authors, 
			  _("Tetravex clone\n(Comments to: Lars.Rydlinge@HIG.SE)"), 
			  NULL);
  gtk_widget_show(about);
}




