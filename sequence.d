module sequence;

import std.algorithm;
import std.range;
import std.string;

import micro;
import move;

class Sequence
{
  size_t id; // unique in the Sequence[], smaller than Sequence[].length
  Move[] moves;
  bool[Sequence] supports; // transitive
  Micro minz, maxz;
  vec2M minxy, maxxy; // I'll take "stripper names" for 200.
  invariant
  {
    assert(moves.length > 0);
  }
  @property Location start() const { return this.moves.start; }
  @property Location end() const { return this.moves.end; }
  public void addSupports(Sequence[] preceding)
  {
    bool[Sequence] impliedSupportCache;
    preceding.retro.each!(s => this.addSupport(s, impliedSupportCache));
  }
  /**
   * impliedSupports is a bit tricky.
   * Basically, we treat it as a gradual way to build up a transitive support list.
   * since this.supports only stores "direct" supports, ie. overlapping sequences
   * that don't support any of ours, and we know we're called with supports in backwards support order
   * via addSupports(), we know we will only see supports for a Sequence after we've seen that sequence.
   * Consequently, we only add supports for a sequence once we actually see it,
   * and can still be assured that when we hit a sequence as support and it's not in impliedSupports,
   * it's a sequence that doesn't support by any support we've already added, transitively.
   */
  private void addSupport(Sequence support, ref bool[Sequence] impliedSupports)
  {
    if (support !in impliedSupports) {
      // TODO make test one-directional in z
      if (!moves.any!(m1 => support.moves.any!(m2 => m1.overlaps(m2))))
      {
        return;
      }
      this.supports[support] = true; // since we haven't seen it via transitive supports before
    }

    foreach (next; support.supports.byKey)
    {
      impliedSupports[next] = true;
    }
  }
  this(size_t id, Move[] moves)
  {
    alias vmin = (a, b) => vec2M(min(a.x, b.x), min(a.y, b.y));
    alias vmax = (a, b) => vec2M(max(a.x, b.x), max(a.y, b.y));
    this.id = id;
    this.moves = moves;
    this.minz = moves.map!(m => min(m.from.z, m.to.z)).minElement;
    this.maxz = moves.map!(m => max(m.from.z, m.to.z)).maxElement;
    this.minxy = moves.map!(m => vmin(m.from.xy, m.to.xy)).fold1!vmin;
    this.maxxy = moves.map!(m => vmax(m.from.xy, m.to.xy)).fold1!vmax;
  }
  override string toString() const
  {
    return "Sequence(<%s - %s>: %s moves)".format(this.minz, this.maxz, this.moves.length);
  }
}

bool runsInto(const ref Move move, const Sequence sequence)
{
  if (min(move.from.z, move.to.z) > sequence.maxz)
  {
    return false;
  }
  if (!move.overlaps(sequence.minxy, sequence.maxxy)) {
    version(check_aabb)
    {
      bool res = sequence.moves.any!((const ref sequenceMove) => .move.runsInto(move, sequenceMove));
      assert(!res);
    }
    return false;
  }
  return sequence.moves.any!((const ref sequenceMove) => .move.runsInto(move, sequenceMove));
}

auto fold1(alias Fun, Range)(Range range)
if (isInputRange!Range)
{
  return range.drop(1).fold!Fun(range.front);
}

unittest
{
  assert([[1], [2], [3], [4], [5]].fold1!((a, b) => a ~ b) == [1, 2, 3, 4, 5]);
}
