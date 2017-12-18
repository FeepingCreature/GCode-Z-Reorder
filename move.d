module move;

import std.algorithm;

import defs;
import micro;

struct Move
{
  int type;
  int feedrate;
  Micro extrusion;
  Location from, to;
  this(int type, Location from, Location to, Micro extrusion = µ(0), int feedrate = 0)
  {
    assert(from.xy == to.xy || from.z == to.z);
    this.type = type;
    this.feedrate = feedrate;
    this.extrusion = extrusion;
    this.from = from;
    this.to = to;
  }
  @property auto δ() { return this.to - this.from; };
  float distance() { return δ.toFloat.length; }
}

bool overlaps(const ref Move m1, const ref Move m2)
{
  return distance(m1, m2) < CLEARANCE;
}

bool runsInto(const ref Move movement, const ref Move obstacle)
{
  return min(movement.from.z, movement.to.z) <= max(obstacle.from.z, obstacle.to.z)
    && movement.overlaps(obstacle);
}

@property Location start(const Move[] moves)
{
  return moves[0].from;
}

@property Location end(const Move[] moves)
{
  return moves[$-1].to;
}

Move[] connect(Location from, Location to)
{
  if (from == to)
  {
    return [];
  }
  if (from.z == to.z)
  {
    return [Move(0, from, to)];
  }
  if (from.z < to.z)
  {
    auto inter = from.xy_(to.z);
    return [Move(0, from, inter), Move(0, inter, to)];
  }
  /*if (from.z > to.z)*/ {
    auto inter = to.xy_(from.z);
    return [Move(0, from, inter), Move(0, inter, to)];
  }
}

float distance(const ref Move m1, const ref Move m2)
{
  return micro.distance(m1.from.xy, m1.to.xy, m2.from.xy, m2.to.xy);
}
