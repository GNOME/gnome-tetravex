public class Tile
{
    /* Edge colors */
    public int north;
    public int west;
    public int east;
    public int south;

    /* Solution location */
    public uint x;
    public uint y;

    public Tile (uint x, uint y)
    {
        this.x = x;
        this.y = y;
    }
}

public class Puzzle
{
    private uint _size;
    public uint size
    {
        get { return _size; }
    }
    private Tile[,] board;
    
    public signal void tile_moved (Tile tile, uint x, uint y);    
    public signal void solved ();
    
    public bool is_solved
    {
        get
        {
            /* Solved if entire left hand side is complete (we ensure only tiles
               that fit are allowed */
            for (var x = 0; x < size; x++)
            {
                for (var y = 0; y < size; y++)
                {
                    var tile = board[x, y];
                    if (tile == null)
                        return false;
                }
            }

            return true;
        }
    }

    public Puzzle (uint size)
    {
        _size = size;
        board = new Tile[size * 2, size];
        for (var x = 0; x < size; x++)
            for (var y = 0; y < size; y++)
                board[x, y] = new Tile (x, y);

        /* Pick random colours for edges */
        for (var x = 0; x < size; x++)
        {
            for (var y = 0; y <= size; y++)
            {
                var n = Random.int_range (0, 10);
                if (y - 1 >= 0)
                    board[x, y - 1].south = n;
                if (y < size)
                    board[x, y].north = n;
            }
        }
        for (var x = 0; x <= size; x++)
        {
            for (var y = 0; y < size; y++)
            {
                var n = Random.int_range (0, 10);
                if (x - 1 >= 0)
                    board[x - 1, y].east = n;
                if (x < size)
                    board[x, y].west = n;
            }
        }

        /* Pick up the tiles... */
        List<Tile> tiles = null;
        for (var x = 0; x < size; x++)
        {
            for (var y = 0; y < size; y++)
            {
                tiles.append (board[x, y]);
                board[x, y] = null;
            }
        }

        /* ...and place then randomly on the right hand side */
        for (var x = 0; x < size; x++)
        {
            for (var y = 0; y < size; y++)
            {
                var n = Random.int_range (0, (int32) tiles.length ());
                var tile = tiles.nth_data (n);
                board[x + size, y] = tile;
                tiles.remove (tile);
            }
        }
    }

    public Tile? get_tile (uint x, uint y)
    {
        return board[x, y];
    }
    
    public void get_tile_location (Tile tile, out uint x, out uint y)
    {
        x = y = 0;
        for (x = 0; x < size * 2; x++)
            for (y = 0; y < size; y++)
                if (board[x, y] == tile)
                    return;
    }

    public bool tile_fits (uint x0, uint y0, uint x1, uint y1)
    {
        var tile = board[x0, y0];
        if (tile == null)
            return false;

        if (x1 > 0 && !(x1 - 1 == x0 && y1 == y0) && board[x1 - 1, y1] != null && board[x1 - 1, y1].east != tile.west)
            return false;
        if (x1 < size - 1 && !(x1 + 1 == x0 && y1 == y0) && board[x1 + 1, y1] != null && board[x1 + 1, y1].west != tile.east)
            return false;
        if (y1 > 0 && !(x1 == x0 && y1 - 1 == y0) && board[x1, y1 - 1] != null && board[x1, y1 - 1].south != tile.north)
            return false;
        if (y1 < size - 1 && !(x1 == x0 && y1 + 1 == y0) && board[x1, y1 + 1] != null && board[x1, y1 + 1].north != tile.south)
            return false;

        return true;
    }
    
    public bool can_switch (uint x0, uint y0, uint x1, uint y1)
    {
        if (x0 == x1 && y0 == y1)
            return false;

        var t0 = board[x0, y0];
        var t1 = board[x1, y1];

        /* No tiles to switch */
        if (t0 == null && t1 == null)
            return false;

        /* If placing onto the final area check if it fits */
        if (t0 != null && x1 < size && !tile_fits (x0, y0, x1, y1))
            return false;
        if (t1 != null && x0 < size && !tile_fits (x1, y1, x0, y0))
            return false;

        return true;
    }

    public void switch_tiles (uint x0, uint y0, uint x1, uint y1)
    {
        if (x0 == x1 && y0 == y1)
            return;            

        var t0 = board[x0, y0];
        var t1 = board[x1, y1];
        board[x0, y0] = t1;
        board[x1, y1] = t0;

        if (t0 != null)
            tile_moved (t0, x1, y1);
        if (t1 != null)
            tile_moved (t1, x0, y0);

        if (is_solved)
            solved ();
    }

    public bool can_move_up
    {
        get
        {
            for (var x = 0; x < size; x++)
                if (board[x, 0] != null)
                    return false;
            return true;
        }
    }

    public void move_up ()
    {
        if (!can_move_up)
            return;
        for (var y = 1; y < size; y++)
            for (var x = 0; x < size; x++)
                switch_tiles (x, y, x, y - 1);
    }

    public bool can_move_down
    {
        get
        {
            for (var x = 0; x < size; x++)
                if (board[x, size - 1] != null)
                    return false;
            return true;
        }
    }

    public void move_down ()
    {
        if (!can_move_down)
            return;
        for (var y = (int) size - 2; y >= 0; y--)
            for (var x = 0; x < size; x++)
                switch_tiles (x, y, x, y + 1);
    }

    public bool can_move_left
    {
        get
        {
            for (var y = 0; y < size; y++)
                if (board[0, y] != null)
                    return false;
            return true;
        }
    }

    public void move_left ()
    {
        if (!can_move_left)
            return;
        for (var x = 1; x < size; x++)
            for (var y = 0; y < size; y++)
                switch_tiles (x, y, x - 1, y);
    }

    public bool can_move_right
    {
        get
        {
            for (var y = 0; y < size; y++)
                if (board[size - 1, y] != null)
                    return false;
            return true;
        }
    }

    public void move_right ()
    {
        if (!can_move_right)
            return;
        for (var x = (int) size - 2; x >= 0; x--)
            for (var y = 0; y < size; y++)
                switch_tiles (x, y, x + 1, y);
    }

    public void solve ()
    {
        List<Tile> wrong_tiles = null;
        for (var x = 0; x < size * 2; x++)
        {
            for (var y = 0; y < size; y++)
            {
                var tile = board[x, y];
                if (tile != null && (tile.x != x || tile.y != y))
                    wrong_tiles.append (tile);
                board[x, y] = null;
            }
        }

        foreach (var tile in wrong_tiles)
        {
            board[tile.x, tile.y] = tile;
            tile_moved (tile, tile.x, tile.y);
        }
    }
}
