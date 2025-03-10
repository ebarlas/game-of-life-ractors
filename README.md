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
the overhead of each `Ractor` seems to pile up quickly. The time to compute
a new generation exceeds 100 milliseconds with a grid that has 500 or more cells
on my current machine (MacBook Pro M2 Max). However, the CPU utilization for the
`ruby` process is only around 150%.

As noted in the outline above, for each generation, each cell must send and receive
liveness messages with each neighbor (most cells have 8 neighbors). 

This seems to suggest hidden costs with frequent communication between many `Ractor`
instances. This could also be related to the use of a platform OS thread per `Ractor`
instance by the Ruby VM.

Note for reference that the proof-of-concept code below trivially uses 4 dedicated cores,
with my MacBook reporting 400% CPU utilization.

```
ractors = 4.times.map do
  Ractor.new do
    loop do
      Math.sqrt(rand) # Some meaningless computation
    end
  end
end

ractors.each(&:take)
```

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

[Gosper's glider gun](https://en.wikipedia.org/wiki/Bill_Gosper) (performance issues noted above):

```
ruby game_of_life.rb --grid patterns/gosper_glider_gun.txt --bottom 10 --period 20
```