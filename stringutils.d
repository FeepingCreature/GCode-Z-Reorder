module stringutils;

import std.range;
import std.string;

string before(string haystack, string needle)
{
  if (haystack.length < needle.length) return null;
  if (haystack[$-needle.length..$] != needle) return null;
  return haystack[0..$-needle.length];
}

string after(string haystack, string needle)
{
  if (haystack.length < needle.length) return null;
  if (haystack[0..needle.length] != needle) return null;
  return haystack[needle.length..$];
}

unittest
{
  assert("Hello World".before("World") == "Hello ");
  assert("Hello".before("Hello"));
  assert(!"Hello World".before("Spoon"));
  assert("Hello World".after("Hello") == " World");
  assert("Hello".after("Hello"));
  assert(!"Hello World".after("Spoon"));
}

