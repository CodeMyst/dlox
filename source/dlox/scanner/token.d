module dlox.scanner.token;

import std.variant;

import dlox.scanner.token_type;

class Token
{
    public const TokenType type;
    public const string lexeme;
    public const Variant literal;
    public const int line;

    public this(TokenType type, string lexeme, Variant literal, int line)
    {
        this.type = type;
        this.lexeme = lexeme;
        this.literal = literal;
        this.line = line;
    }

    public override string toString() const
    {
        import std.conv : to;

        string literalString = "";

        if (literal.peek!string !is null) literalString = literal.get!string();
        else if (literal.peek!double !is null) literalString = literal.get!double().to!string();

        return type.to!string() ~ " " ~ lexeme;
    }
}
