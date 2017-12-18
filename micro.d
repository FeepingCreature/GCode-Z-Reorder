module micro;

import std.algorithm;
import std.conv;
import std.range;

import stringutils;
import vector;

Micro µ(long u) { return Micro(u); }

alias Location = Vector!(Micro, 3);

struct Micro
{
  long value;
  string toString() const {
    string res = this.value.to!string;
    while (res.length < 7) res = "0" ~ res;
    res = res[0 .. $-6] ~ "." ~ res[$-6 .. $];
    while (res.before("0")) res = res.before("0");
    if (auto str = res.before(".")) res = str;
    return res;
  }
  this(float value) { this.value = cast(long) (cast(double) value * 1_000_000); }
  this(long value) { this.value = value; }
  Micro opBinary(string Op)(Micro rhs) const
    if (Op == "+" || Op == "-")
  {
    return mixin("Micro(this.value " ~ Op ~ " rhs.value)");
  }

  static enum epsilon = Micro(1);

  void opOpAssign(string Op)(Micro rhs)
    if (Op == "+" || Op == "-")
  {
    mixin("this.value " ~ Op ~ "= rhs.value;");
  }

  int opCmp(Micro rhs) const
  {
    return (this.value == rhs.value) ? 0 : (this.value < rhs.value) ? -1 : 1;
  }

  @property float toFloat() const {
    return cast(float) (cast(double) this.value / 1_000_000);
  }
}

Micro parseµ(string str)
{
  ulong whole;
  bool negative;
  if (auto rest = str.after("-")) {
    str = rest;
    negative = true;
  }
  while (str.length)
  {
    auto ch = str[0];
    if (ch == '.') {
      str.popFront;
      break;
    }
    assert(ch >= '0' && ch <= '9');
    whole = whole * 10 + (ch - '0');
    str.popFront;
  }

  assert(str.length <= 6);
  ulong fractional;
  foreach (i; iota(6))
  {
    fractional *= 10;
    if (i < str.length)
    {
      auto ch = str[i];
      assert(ch >= '0' && ch <= '9');
      fractional += ch - '0';
    }
  }
  assert(fractional >= 0 && fractional < 1_000_000);
  return µ((whole * 1_000_000 + fractional) * (negative ? -1 : 1));
}

alias vec2M = Vector!(Micro, 2);

alias vec3M = Vector!(Micro, 3);

float distance(vec2M l1a, vec2M l1b, vec2M l2a, vec2M l2b)
{
  return min(
    min(distance(l1a, l1b, l2a), distance(l1a, l1b, l2b)),
    min(distance(l2a, l2b, l1a), distance(l2a, l2b, l1b))
  );
}

float distance(vec2M a, vec2M b, vec2M p)
{
  return distance(a.toFloat, b.toFloat, p.toFloat);
}

float distance(vec2f a, vec2f b, vec2f p)
{
  auto d = b - a;
  float t = (d.dot(p) - d.dot(a)) / d.dot(d);
  t = min(1, max(0, t));
  auto c = a + d * t;
  return (p - c).length;
}
