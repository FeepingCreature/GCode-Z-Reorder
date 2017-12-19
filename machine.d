module machine;

import std.algorithm;
import std.conv;
import std.stdio;
import std.string;

import micro;
import move;
import stringutils;

abstract class Machine
{
  MachineState state;

  abstract void flush();
  abstract bool handleMove(Move move);
  abstract void output(string line);

  void parse(string line)
  {
    bool success;
    if (auto rest = line.after("G0 ")) success = parseMove(0, rest.splitter(";").front.strip);
    else if (auto rest = line.after("G1 ")) success = parseMove(1, rest.splitter(";").front.strip);
    else if (line.after(";LAYER") || line.after(";TYPE") || line.after(";TIME_ELAPSED")) return;
    else if (line == "G92 E0")
    {
      state.extrusionDistance = µ(0);
      return;
    }

    if (!success) {
      stderr.writefln("flush because %s", line);
      flush;
      output(line);
    }
  }
  bool parseMove(int type, string str)
  {
    Move move;
    move.type = type;
    move.from = this.state.location;

    Micro newExtrusion = this.state.extrusionDistance;
    Location newLoc = this.state.location;
    const parts = str.split(" ");
    foreach (part; parts)
    {
      if (auto rest = part.after("F")) move.feedrate = rest.to!int;
      else if (auto rest = part.after("X")) newLoc.x = rest.parseµ;
      else if (auto rest = part.after("Y")) newLoc.y = rest.parseµ;
      else if (auto rest = part.after("Z")) newLoc.z = rest.parseµ;
      else if (auto rest = part.after("E")) newExtrusion = rest.parseµ;
      else assert(false, "what is "~part);
    }

    move.to = newLoc;
    move.extrusion = newExtrusion - this.state.extrusionDistance;

    // must be updated whether we handle the move or not, since move generation relies on it
    this.state.extrusionDistance = newExtrusion;
    this.state.location = newLoc;

    if (!handleMove(move)) return false;

    return true;
  }
}

struct MachineState
{
  Micro extrusionDistance;
  Location location;
}

