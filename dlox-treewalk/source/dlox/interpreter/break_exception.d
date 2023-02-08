module dlox.interpreter.break_exception;

class BreakException : Exception
{
    this(string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super("", file, line, nextInChain);
    }
}
