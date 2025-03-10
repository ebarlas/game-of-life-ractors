require 'optparse'
require 'gosu'

def parse_options
  options = {
    grid: "patterns/pulsar.txt",
    left: 0,
    top: 0,
    right: 0,
    bottom: 0,
    period: 200,
    width: 640,
    height: 480
  }
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby game_of_life.rb [options]"
    opts.on("--grid FILE", "Grid seed file (default: patterns/pulsar.txt)") { |file| options[:grid] = file }
    opts.on("--left VALUE", Integer, "Left margin padding (default: 0)") { |val| options[:left] = val }
    opts.on("--top VALUE", Integer, "Top margin padding (default: 0)") { |val| options[:top] = val }
    opts.on("--right VALUE", Integer, "Right margin padding (default: 0)") { |val| options[:right] = val }
    opts.on("--bottom VALUE", Integer, "Bottom margin padding (default: 0)") { |val| options[:bottom] = val }
    opts.on("--period VALUE", Integer, "Update period in ms (default: 200)") { |val| options[:period] = val }
    opts.on("--width VALUE", Integer, "Max window width in pixels (default: 640)") { |val| options[:width] = val }
    opts.on("--height VALUE", Integer, "Max window height in pixels (default: 480)") { |val| options[:height] = val }
    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!
  options
end

def self.load_grid(file)
  lines = File.readlines(file, chomp: true).map { |line| line.chars.map { |c| c == '*' } }
  rows = lines.length
  cols = lines.first.length
  Grid.new(rows, cols).tap do |grid|
    lines.each_with_index do |line, r|
      line.each_with_index { |alive, c| grid[r, c] = alive }
    end
  end
end

class Grid
  include Enumerable
  attr_reader :rows, :cols

  def initialize(rows, cols)
    @rows = rows
    @cols = cols
    @grid = Array.new(rows) { Array.new(cols) }
  end

  def size
    @rows * @cols
  end

  def [](row, col)
    @grid[row][col]
  end

  def []=(row, col, val)
    @grid[row][col] = val
  end

  def each
    return enum_for(:each) unless block_given?
    @grid.each_with_index do |row, r|
      row.each_with_index do |val, c|
        yield r, c, val
      end
    end
  end

  private def valid_row_col?(row, col)
    row.between?(0, @rows - 1) && col.between?(0, @cols - 1)
  end

  def neighbors(row, col)
    return enum_for(:neighbors, row, col) unless block_given?
    (row - 1).upto(row + 1) do |r|
      (col - 1).upto(col + 1) do |c|
        yield @grid[r][c] if (r != row || c != col) && valid_row_col?(r, c)
      end
    end
  end

  def pad(left, top, right, bottom)
    new_rows, new_cols = @rows + top + bottom, @cols + left + right
    Grid.new(new_rows, new_cols).tap do |g|
      @rows.times do |r|
        @cols.times do |c|
          g[r + top, c + left] = @grid[r][c]
        end
      end
    end
  end

  def blank
    Grid.new(@rows, @cols)
  end
end

class Game < Gosu::Window
  def initialize(width, height, side, rows, cols, period)
    super width, height
    self.caption = "Game of Life"
    self.update_interval = period
    @side = side
    @grid = Grid.new(rows, cols)
  end

  def update
    @grid.size.times do
      Ractor.yield(nil)
    end
    @grid.size.times do
      row, col, alive = Ractor.receive
      @grid[row, col] = alive
    end
  end

  def draw
    @grid.each do |r, c, alive|
      Gosu.draw_rect(c * @side, r * @side, @side, @side, alive ? Gosu::Color::BLACK : Gosu::Color::WHITE)
    end
  end
end

def tile_size(max_width, max_height, rows, cols)
  aspect = Float(max_width) / max_height
  actual = Float(cols) / rows
  size = actual < aspect ? max_height / rows : max_width / cols
  [size, size * cols, size * rows]
end

def run_cell(row, col, alive)
  neighbors = Ractor.receive # seed message with neighbor actors
  loop do
    Ractor.main.take # clock tick signal
    neighbors.each { |n| n.send(alive) } # announce liveness to neighbors
    live_neighbors = neighbors.count { Ractor.receive } # receive liveness from neighbors
    alive = alive ? [2, 3].include?(live_neighbors) : live_neighbors == 3 # calculate next state based on rules
    Ractor.main.send([row, col, alive]) # announce resulting next state
  end
end

def start_cells(grid)
  grid.blank.tap do |cells|
    grid.each do |r, c, alive|
      cells[r, c] = Ractor.new(r, c, alive, &method(:run_cell))
    end
  end
end

def main
  opts = parse_options
  grid = load_grid(opts[:grid]).pad(opts[:left], opts[:top], opts[:right], opts[:bottom])
  side, width, height = tile_size(opts[:width], opts[:height], grid.rows, grid.cols)
  cells = start_cells(grid)
  cells.each { |row, col, cell| cell.send(cells.neighbors(row, col).to_a) }
  neighbors = cells.map { |row, col, _| cells.neighbors(row, col).count }.sum
  fields = {
    cells: grid.size,
    neighbors: neighbors,
    rows: grid.rows,
    cols: grid.cols,
    width: width,
    height: height,
    side: side
  }
  puts "started cells, " + fields.map { |k, v| "#{k}=#{v}" }.join(", ")
  Game.new(width, height, side, grid.rows, grid.cols, opts[:period]).show
end

main