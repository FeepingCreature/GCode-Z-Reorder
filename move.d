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

bool overlaps(const ref Move move, vec2M low, vec2M high)
{
  import std.algorithm;
  import vector;
  low = low - vec2M(Micro(CLEARANCE));
  high = high + vec2M(Micro(CLEARANCE));
  const lowf = low.toFloat, highf = high.toFloat;
  const origin = move.from.xy.toFloat, dest = move.to.xy.toFloat;
  const dir = dest - origin;
  if (dir == vec2f(0)) { // stationary move
    return origin.x >= lowf.x && origin.y >= lowf.y
      && origin.x <= highf.x && origin.y <= highf.y;
  }
  if (dir.x == 0) { // pure y move
    const cross_low_t = (lowf.y - origin.y) / dir.y;
    const cross_high_t = (highf.y - origin.y) / dir.y;
    const enter_t = min(cross_low_t, cross_high_t);
    const exit_t = max(cross_low_t, cross_high_t);
    return enter_t <= exit_t && enter_t < 1 && exit_t > 0;
  }
  if (dir.y == 0) { // pure x move
    const cross_low_t = (lowf.x - origin.x) / dir.x;
    const cross_high_t = (highf.x - origin.x) / dir.x;
    const enter_t = min(cross_low_t, cross_high_t);
    const exit_t = max(cross_low_t, cross_high_t);
    return enter_t <= exit_t && enter_t < 1 && exit_t > 0;
  }
  const cross_low_t = (lowf - origin) / dir;
  const cross_high_t = (highf - origin) / dir;
  const enter_t = vector.min(cross_low_t, cross_high_t);
  const exit_t = vector.max(cross_low_t, cross_high_t);
  const last_enter_t = max(enter_t.x, enter_t.y);
  const first_exit_t = max(exit_t.x, exit_t.y);
  // last_enter_t .. first_exit_t is our aabb crossing range
  // we check if it overlaps with 0..1, our interval range.
  // last_enter > first_exit -> move misses aabb entirely
  return last_enter_t <= first_exit_t && last_enter_t < 1 && first_exit_t > 0;
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
