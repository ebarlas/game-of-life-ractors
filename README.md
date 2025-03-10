# Game of Life

[Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life)
is an excellent example of the wonder of programming.
With just a few simple rules, an animated scene springs to life.

This [edition](game_of_life.rb) of Game of Life is built with Ruby actors (`Ractor` class). 

## Ruby Actors

The application consists of one main actor (`Ractor.main`) and
an actor (`Ractor.new`) for each cell in the grid.

General logic:
* Main actor starts one actor per cell (`Ractor.new`)
* Cell actors wait on input port (`Ractor.receive`) for seed message with neighbors
* Main actor sends seed message to each cell actor's input port (`Ractor.send`) with neighbor actors
* Repeat for each frame:
  * Main actor emits tick messages on output port (`Ractor.yield`)
  * Cell actors take tick message from main actor output port (`Ractor.take`)
  * Cell actors send liveness to neighbor input ports (`Ractor.send`)
  * Cell actors receive liveness on own input ports (`Ractor.receive`)
  * Cell actors compute next liveness state
  * Cell actors send liveness to main actor input port (`Ractor.send`)
  * Main actor receives liveness updates on own input port (`Ractor.receive`)

## Performance

Despite seemingly simple, optimal code for communication between actors,
the overhead of each `Ractor` seems to pile up quickly.

A new generation is computed in each iteration. To do so (as noted above),
each cell exchanges liveness information
with its neighbors. Each interior cell calls `Ractor.send` 8 times to
share its liveness with neighbors, and then calls `Ractor.receive` 8 times
to receive liveness information on its input port.

Cells along the edges have only 5 neighbors and cells in the corners have 3.

```ruby
neighbors = 3 * 4 + # corners
  5 * (rows - 2) * 2 + # edge columns
  5 * (cols - 2) * 2 + # edge rows
  8 * (rows - 2) * (cols - 2) # interior
```

The Game of Life animation update rate (and framerate) drops quickly
as the number of cells increases. The framerate is just bearable
with a 25 by 25 grid.

The numbers below are from a benchmark version of the code with no Gosu
dependency and no output other than generation iteration times.

These are from March 10, 2025 on my wall-powered MacBook Pro M2 Max
running `ruby 3.4.2 (2025-02-15 revision d2930f8e7a) +PRISM [arm64-darwin22]`.

| Rows | Cols | Cells | Neigh. | Iter.  | Msg/sec |
|------|------|-------|--------|--------|---------|
| 5    | 5    | 25    | 144    | 2 ms   | 72,000  |
| 10   | 10   | 100   | 684    | 15 ms  | 45,144  |
| 25   | 25   | 625   | 4704   | 70 ms  | 65,856  |
| 50   | 50   | 2500  | 19404  | 390 ms | 38,808  |

Iteration times were calculated using a monotonic clock:

```ruby
Process.clock_gettime(Process::CLOCK_MONOTONIC)
```

## Conclusion

This project was originally intended to be a fun demonstration of Ruby actors.

Unfortunately, I wasn't able to animate larger Game of Life patterns due to
the performance scaling issues outlined above.

[Gosper's glider gun](https://en.wikipedia.org/wiki/Bill_Gosper) available with
[this pattern](patterns/gosper_glider_gun.txt) is just barely workable on my current
system.

With the configuration shown below, there are 684 cells and 5,146 neighbors.
The iteration time is about 120 ms and the framerate is about 7 fps.

That's almost 50,000 messages per second: 5146 * (1000 / 120) = 42,883.

The Ruby VM and its actor scheduler aren't able to deliver enough performance
for large Game of Life grids and other comparable workloads.

## Run

```
ruby game_of_life.rb -h                                                          
Usage: ruby game_of_life.rb [options]
        --grid FILE                  Grid seed file (default: patterns/pulsar.txt)
        --left VALUE                 Left margin padding (default: 0)
        --top VALUE                  Top margin padding (default: 0)
        --right VALUE                Right margin padding (default: 0)
        --bottom VALUE               Bottom margin padding (default: 0)
        --period VALUE               Update period in ms (default: 200)
        --width VALUE                Max window width in pixels (default: 640)
        --height VALUE               Max window height in pixels (default: 480)
    -h, --help                       Show this help message
```

### Blinker

* [blinker.txt](patterns/blinker.txt)
* 5 rows
* 5 columns
* 25 cells
* 144 neighbors

```
ruby game_of_life.rb --grid patterns/blinker.txt --period 200
```

### Pulsar

* [pulsar.txt](patterns/pulsar.txt)
* 17 rows
* 17 columns
* 289 cells
* 2112 neighbors

```
ruby game_of_life.rb --grid patterns/pulsar.txt --period 200
```

### Gosper's Glider Gun

* [Gosper's glider gun](https://en.wikipedia.org/wiki/Bill_Gosper)
* [gosper_glider_gun.txt](patterns/gosper_glider_gun.txt)
* 19 rows
* 36 columns
* 684 cells
* 5146 neighbors

```
ruby game_of_life.rb --grid patterns/gosper_glider_gun.txt --bottom 10 --period 20
```