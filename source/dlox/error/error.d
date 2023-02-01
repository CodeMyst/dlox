module dlox.error.error;

import std.stdio;

import dlox.scanner;

bool hadError = false;

void error(int line, string message)
{
    report(line, "", message);
}

void error(Token token, string message)
{
    if (token.type == TokenType.EOF) report(token.line, " at end", message);
    else report(token.line, " at '" ~ token.lexeme ~ "'", message);
}

void report(int line, string where, string message)
{
    import std.conv : to;

    writeln("[line " ~ line.to!string() ~ "] Error" ~ where ~ ": " ~ message);
    hadError = true;
}
