module dlox.interpreter.callable;

import std.variant;

import dlox.interpreter;

interface Callable
{
    Variant call(Interpreter interpreter, Variant[] arguments);
    int arity();
}
