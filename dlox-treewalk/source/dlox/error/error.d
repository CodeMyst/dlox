module dlox.error.error;

import std.stdio;

import dlox.scanner;
import dlox.error.runtime_error;

bool hadError = false;
bool hadRuntimeError = false;

void error(int line, string message)
{
    report(line, "", message);
}

void error(Token token, string message)
{
    if (token.type == TokenType.EOF) report(token.line, " at end", message);
    else report(token.line, " at '" ~ token.lexeme ~ "'", message);
}

void runtimeError(RuntimeError error)
{
    import std.conv : to;

    writeln("[line " ~ error.token.line.to!string() ~ "] " ~ error.message);
    hadRuntimeError = true;
}

void report(int line, string where, string message)
{
    import std.conv : to;

    writeln("[line " ~ line.to!string() ~ "] Error" ~ where ~ ": " ~ message);
    hadError = true;
}
