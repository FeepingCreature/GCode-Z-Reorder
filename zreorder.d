module zreorder;

import std.algorithm;
import std.range : array, chain, drop, dropBack, enumerate, front, isInputRange;
import std.stdio;
import std.string;

import defs;
import machine;
import micro;
import move;
import sequence;

class ZReorder : Machine
{
  MachineState outputState;
  Move[] moves;

  override void output(string line)
  {
    if (line == "G92 E0")
    {
      this.state.extrusionDistance = µ(0);
      this.outputState.extrusionDistance = µ(0);
    }
    writeln(line);
  }

  override bool handleMove(Move move)
  {
    if ( (move.type == 0 && move.extrusion > µ(0)) // move rapidly about, spewing liquid plastic
      || !(move.from.xy == move.to.xy || move.from.z == move.to.z) // impure move, spanning both xy and z
    ) {
      stderr.writeln("handle failed, set output location to ", move.to);
      this.outputState.location = move.to; // fall back to plain output = output state updates
      this.outputState.extrusionDistance += move.extrusion;
      return false;
    }

    moves ~= move;
    return true;
  }

  override void flush()
  {
    if (!this.moves.length) return;

    stderr.writefln("flush run of %s", this.moves.length);

    auto sequences = breakAtTransfers(this.moves);
    string error;

    assert(sequences.valid(error), "Initial sequence invalid: "~error);

    permute(sequences);

    assert(sequences.valid(error), "Final sequence invalid: "~error);

    bool firstMoves = true;
    joinOrder(sequences, (scope Move[] moves)
    {
      if (firstMoves)
      {
        connect(this.outputState.location, moves.start, (scope Move[] moves)
        {
          foreach (move; moves) outputMove(move);
        });
        firstMoves = false;
      }
      foreach (move; moves) outputMove(move);
    });

    this.state = this.outputState;
    this.moves = null;
  }

  void outputMove(const ref Move move)
  {
    assert(move.from == this.outputState.location, "weird move: we are at %s but emit %s".format(this.outputState.location, move));
    assert(move.type == 0 || move.type == 1);
    string code = (move.type == 0) ? "G0 " : "G1 ";
    string[] parts;
    int feedrate = move.feedrate ? move.feedrate : this.outputState.feedrate;
    if (feedrate != this.outputState.feedrate)
    {
      parts ~= format!"F%s"(move.feedrate);
    }
    if (move.to.xy != move.from.xy || move.to.z != move.from.z)
    {
      parts ~= format!"X%s"(move.to.x);
      parts ~= format!"Y%s"(move.to.y);
    }
    if (move.to.z != move.from.z) parts ~= format!"Z%s"(move.to.z);
    if (move.extrusion != µ(0)) parts ~= format!"E%s"(this.outputState.extrusionDistance + move.extrusion);

    this.output(code~parts.join(" "));

    this.outputState.extrusionDistance += move.extrusion;
    this.outputState.location = move.to;
    this.outputState.feedrate = feedrate;
  }
}

Sequence[] breakAtTransfers(Move[] moves)
{
  Sequence[] res;
  Move[] list;
  void flush(size_t progress) {
    if (!list.length) return;
    auto newseq = new Sequence(res.length, list);
    // stderr.writefln("%s / %s: add %s supports", progress, moves.length, res.length);
    newseq.addSupports(res);

    res ~= newseq;
    list = null;
  }
  foreach (i, move; moves) {
    if (move.extrusion == µ(0) && move.δ.xy != vec2M(µ(0)) && move.δ.xy.toFloat.length > CLEARANCE) // not worth bothering with otherwise
    {
      flush(i);
    }
    else list ~= move;
  }
  flush(moves.length);
  return res;
}

void joinOrder(Sequence[] order, scope void delegate(scope Move[]) dg)
{
  Location prevEnd;
  foreach (i, seq; order)
  {
    if (i > 0)
    {
      connect(prevEnd, seq.moves.start, dg);
    }
    dg(seq.moves);
    prevEnd = seq.moves.end;
  }
}

// all Sequences before uncheckedFrom are unchanged from previous valid=true runs
bool valid(Sequence[] order, out string error, size_t uncheckedFrom = 0)
{
  // condition 1: all sequences are preceded by all their supports
  {
    scope preceding = new bool[order.length];
    foreach (i, seq; order)
    {
      if (i >= uncheckedFrom && !seq.supports.byKey.all!(s => preceding[s.id]))
      {
        error = "condition 1, unsupported sequence";
        return false;
      }
      preceding[seq.id] = true;
    }
  }
  // condition 2: intermoves don't collide with any preceding sequence move
  foreach (i, _; order.enumerate.drop(1))
  {
    if (i < uncheckedFrom) continue;
    const preceding = order[0..i-1], fromSeq = order[i-1], toSeq = order[i];
    const from = fromSeq.end, to = toSeq.start;
    bool any_run_into;
    connect(from + vec3M(µ(0), µ(0), Micro.epsilon), to + vec3M(µ(0), µ(0), Micro.epsilon), (scope Move[] intermoves)
    {
      if (any_run_into) return;
      any_run_into = any_run_into || preceding.any!(s => intermoves.any!((const ref intermove) => intermove.runsInto(s)));
      if (any_run_into)
      {
        error = "condition 2, intermove %s collides at %s: %s".format(intermoves, i, preceding);
      }
    });
    if (any_run_into)
    {
      stderr.writefln("interesting... we hit an intermove collide at %s / %s", i+1, order.length);
      return false;
    }
  }
  // condition 3: no sequence must be preceded by any sequence
  // that contains any moves higher than the lowest move in it plus Z_CLEARANCE.
  {
    Micro highmark = µ(0);
    foreach (i, seq; order)
    {
      if (i >= uncheckedFrom && highmark > seq.minz + Z_CLEARANCE)
      {
        stderr.writefln("interesting... we hit a z spread violate: %s > %s + %s",
          highmark, seq.minz, Z_CLEARANCE);
        error = "condition 3, z spread violated";
        return false;
      }
      assert(seq.maxz >= µ(0)); // else initial is not guaranteed
      highmark = highmark.max(seq.maxz);
    }
  }

  return true;
}

unittest
{
  assert(
    [1, 2, 3, 4, 5].cumulativeFold!"a ~ b"((int[]).init).drop(1).array
    == [[1, 2], [1, 2, 3], [1, 2, 3, 4], [1, 2, 3, 4, 5]]
  );
}

void permute(Sequence[] order)
{
  foreach (i, sequence; order.dropBack(1))
  {
    stderr.writefln("(%s / %s)", i + 1, order.length);
    // find a candidate to replace i+1
    auto replace = i+1;
    auto end = sequence.end;
    auto candidates = order.enumerate
      .drop(replace)
      .array
      .schwartzSort!(a => (a[1].start - end).toFloat.length);
    foreach (j, pair; candidates.enumerate)
    {
      auto k = pair[0], candidate = pair[1];
      bringToFront(order[replace .. k], order[k .. k+1]); // rotate k to the front
      string error;
      if (order.valid(error, replace))
      {
        if (k != replace)
        {
          stderr.writefln("improvement found: insert %s at %s", k, replace);
        }
        else
        {
          if (j < candidates.length - 1)
          {
            auto nextCandidate = candidates[j+1][1];
            stderr.writefln("candidate is already optimal at %s: %s < %s",
              replace+1, (candidate.start - end).toFloat.length, (nextCandidate.start - end).toFloat.length);
          }
          else
          {
            stderr.writefln("candidate is already optimal at replace=%s: %s, candidate index j=%s/%s, array index k=%s",
              replace+1, (candidate.start - end).toFloat.length, j+1, candidates.length, k+1);
          }
        }
        break;
      }
      else
      {
        // stderr.writefln("rollback: can't insert %s at %s: %s", k, i, error);
        // rollback
        // heh. get it? "roll"back... it's a wordplay.
        bringToFront(order[replace..replace+1], order[replace+1..k+1]);
      }
      // try the next candidate
    }
  }
}
