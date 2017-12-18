module main;

import std.algorithm;
import std.stdio;
import std.string;

import zreorder;

void main()
{
  auto machine = new ZReorder;
  foreach (string line; stdin.byLineCopy.map!strip)
  {
    machine.parse(line);
  }
}
