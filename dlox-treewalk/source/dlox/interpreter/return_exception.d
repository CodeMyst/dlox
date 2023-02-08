module dlox.interpreter.return_exception;

import std.variant;

class ReturnException : Exception
{
    public Variant value;

    this(Variant value, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super("", file, line, nextInChain);
        this.value = value;
    }
}
