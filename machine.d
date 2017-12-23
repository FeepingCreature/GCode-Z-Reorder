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
    else if (line.after("G92 E0"))
    {
      auto move = Move(92, this.state.location, this.state.location, 0);
      this.state.extrusionDistance = µ(0);

      handleMove(move);
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
    MachineState newState = this.state;
    const parts = str.split(" ");
    foreach (part; parts)
    {
      if (auto rest = part.after("F")) newState.feedrate = rest.to!int;
      else if (auto rest = part.after("X")) newState.location.x = rest.parseµ;
      else if (auto rest = part.after("Y")) newState.location.y = rest.parseµ;
      else if (auto rest = part.after("Z")) newState.location.z = rest.parseµ;
      else if (auto rest = part.after("E")) newState.extrusionDistance = rest.parseµ;
      else assert(false, "what is "~part);
    }

    Move move;
    move.type = type;
    move.from = this.state.location;
    move.to = newState.location;
    move.extrusion = newState.extrusionDistance - this.state.extrusionDistance;
    move.feedrate = newState.feedrate;

    // must be updated whether we handle the move or not, since move generation relies on it
    this.state = newState;

    if (!handleMove(move)) return false;

    return true;
  }
}

struct MachineState
{
  Micro extrusionDistance;
  Location location;
  int feedrate;
}

