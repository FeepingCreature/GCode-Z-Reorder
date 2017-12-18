module vector;

import std.algorithm;
import std.conv;
import std.range;
import std.string;

struct Vector(T, size_t Size)
{
  union
  {
    T[Size] components;
    struct
    {
      mixin ComponentTuples!(0, "x", "y", "z", "e");
    }
  }

  this(T val)
  {
    this.components = val;
  }

  string toString() const
  {
    return "vec%s%s(".format(Size, T.stringof[0]) ~ this.components[].map!(to!string).join(",") ~ ")";
  }

  mixin(VectorConstructor);

  static enum VectorConstructor()
  {
    return "this(" ~ Size.iota.map!(i => format!"T arg%s"(i)).join(",") ~ ")" ~
      "{" ~
        Size.iota.map!(i => format!"this.components[%s] = arg%s; "(i, i)).join ~
      "}";
  }

  Vector opBinary(string Op)(Vector rhs) const
  {
    mixin(
      "return Vector(" ~
        Size.iota.map!(i => format!"this.components[%s] %s rhs.components[%s]"(i, Op, i)).join(", ") ~
      ");"
    );
  }

  Vector opBinary(string Op)(T rhs) const
  {
    mixin(
      "return Vector(" ~
        Size.iota.map!(i => format!"this.components[%s] %s rhs"(i, Op)).join(", ") ~
      ");"
    );
  }

  mixin template ComponentTuples(size_t Index, Names...)
  {
    static if (Index < Names.length)
    {
      mixin("T "~Names[Index]~";");
    }
    static if (Index < Size - 1)
    {
      mixin ComponentTuples!(Index + 1, Names);
    }
  }

  auto swiz(string Str, Args...)(Args args) const
  {
    enum string prop(size_t i, dchar ch)
    {
      if (ch == '_') return "args[%s]".format(Str[0..i].count('_'));
      if (ch == '0' || ch == '1') return ch.to!string;
      return format!"this.%s"(ch);
    }
    enum props()
    {
      string[] res;
      foreach (i, ch; Str)
      {
        res ~= prop(i, ch);
      }
      return res.join(", ");
    }
    return mixin("Vector!(T, %s)(".format(Str.length) ~ props() ~ ")");
  }

  alias opDispatch = swiz;

  static if (is(typeof(T.init * T.init)))
  {
    auto dot(const ref Vector rhs) const
    {
      mixin("return " ~ Size.iota.map!(a => format!"this.components[%s] * this.components[%s]"(a, a)).join(" + ") ~ ";");
    }
  }

  static if (is(typeof(cast(float) T.init)))
  {
    Vector!(float, Size) toFloat()() const
    {
      mixin("return Vector!(float, Size)(" ~
        Size.iota.map!(a => format!"cast(float) this.components[%s]"(a)).join(", ") ~
      ");");
    }
  }

  static if (is(typeof(T.init.toFloat) == float))
  {
    Vector!(float, Size) toFloat()() const
    {
      mixin("return Vector!(float, Size)(" ~
        Size.iota.map!(a => format!"this.components[%s].toFloat"(a)).join(", ") ~
      ");");
    }
  }

  import std.math : sqrt;
  static if (is(typeof(sqrt(this.dot(this)))))
  {
    auto length() const
    {
      return sqrt(this.dot(this));
    }
  }
}

unittest
{
  auto v1 = vec4l(1, 2, 3, 4);
  auto v2 = vec4l(4, 3, 2, 1);
  assert(v1 + v2 == vec4l(5, 5, 5, 5));
  assert(v1 + v2 == vec4l(5));
  assert(v1.swiz!"ezyx" == v2);
  assert(v1.swiz!"x0z1" == vec4l(1, 0, 3, 1));
  assert(v1.ezyx == v2);
  assert(v1.x0z1 == vec4l(1, 0, 3, 1));
  assert(v1.x_z_(7, 9) == vec4l(1, 7, 3, 9));
  assert(v1.to!string == "vec4l(1,2,3,4)");
}

alias Vector!(long, 4) vec4l;

alias Vector!(long, 3) vec3l;

alias Vector!(long, 2) vec2l;

alias Vector!(float, 2) vec2f;
