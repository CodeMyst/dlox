module dlox.error.runtime_error;

import dlox.scanner;

class RuntimeError : Exception {
    public const Token token;

    this(Token token, string message, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) pure nothrow @nogc @safe {
        super(message, file, line, nextInChain);
        this.token = token;
    }
}
