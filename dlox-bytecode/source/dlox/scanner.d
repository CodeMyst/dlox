module dlox.scanner;

enum TokenType
{
    LEFT_PAREN, RIGHT_PAREN, LEFT_BRACE,
    RIGHT_BRACE, COMMA, DOT, MINUS,
    PLUS, SEMICOLON, SLASH, STAR,

    BANG, BANG_EQUAL, EQUAL, EQUAL_EQUAL,
    GREATER, GREATER_EQUAL, LESS, LESS_EQUAL,

    IDENTIFIER, STRING, NUMBER,

    AND, CLASS, ELSE, FALSE, FUN, FOR, IF, NIL, OR,
    PRINT, RETURN, SUPER, THIS, TRUE, VAR, WHILE, BREAK,

    ERROR, EOF
}

struct Token
{
    TokenType type;
    const char* start;
    int length;
    int line;
}

struct Scanner
{
    const(char)* start;
    const(char)* current;
    int line;

    this(const char* source)
    {
        start = source;
        current = source;
        line = 1;
    }

    Token scanToken()
    {
        skipWhitespace();

        start = current;

        if (isAtEnd()) return makeToken(TokenType.EOF);

        char c = advance();
        if (isAlpha(c)) return scanIdentifier();
        if (isDigit(c)) return scanNumber();

        switch(c)
        {
            case '(': return makeToken(TokenType.LEFT_PAREN);
            case ')': return makeToken(TokenType.RIGHT_PAREN);
            case '{': return makeToken(TokenType.LEFT_BRACE);
            case '}': return makeToken(TokenType.RIGHT_BRACE);
            case ';': return makeToken(TokenType.SEMICOLON);
            case ',': return makeToken(TokenType.COMMA);
            case '.': return makeToken(TokenType.DOT);
            case '-': return makeToken(TokenType.MINUS);
            case '+': return makeToken(TokenType.PLUS);
            case '/': return makeToken(TokenType.SLASH);
            case '*': return makeToken(TokenType.STAR);

            case '!': return makeToken(match('=') ? TokenType.BANG_EQUAL : TokenType.BANG);
            case '=': return makeToken(match('=') ? TokenType.EQUAL_EQUAL : TokenType.EQUAL);
            case '<': return makeToken(match('=') ? TokenType.LESS_EQUAL : TokenType.LESS);
            case '>': return makeToken(match('=') ? TokenType.GREATER_EQUAL : TokenType.GREATER);

            case '"': return scanString();

            default: break;
        }

        return errorToken("Unexpected character.");
    }

    private void skipWhitespace()
    {
        while (true)
        {
            char c = peek();
            switch (c)
            {
                case ' ':
                case '\r':
                case '\t':
                    advance();
                    break;
                case '\n':
                    line++;
                    advance();
                    break;
                case '/':
                    // TODO: implement c-style comments, with nesting
                    if (peekNext() == '\n')
                    {
                        while (peek() != '\n' && !isAtEnd()) advance();
                    }
                    else
                    {
                        return;
                    }
                    break;

                default: return;
            }
        }
    }

    private TokenType identifierType()
    {
        switch (start[0])
        {
            case 'a': return checkKeyword(1, 2, "nd", TokenType.AND);
            case 'c': return checkKeyword(1, 4, "lass", TokenType.CLASS);
            case 'e': return checkKeyword(1, 3, "lse", TokenType.ELSE);
            case 'f': {
                if (current - start > 1)
                {
                    switch (start[1])
                    {
                        case 'a': return checkKeyword(2, 3, "lse", TokenType.FALSE);
                        case 'o': return checkKeyword(2, 1, "r", TokenType.FOR);
                        case 'u': return checkKeyword(2, 1, "n", TokenType.FUN);
                        default: break;
                    }
                }
            } break;
            case 'i': return checkKeyword(1, 1, "f", TokenType.IF);
            case 'n': return checkKeyword(1, 2, "il", TokenType.NIL);
            case 'o': return checkKeyword(1, 1, "r", TokenType.OR);
            case 'p': return checkKeyword(1, 4, "rint", TokenType.PRINT);
            case 'r': return checkKeyword(1, 5, "eturn", TokenType.RETURN);
            case 's': return checkKeyword(1, 4, "uper", TokenType.SUPER);
            case 't': {
                if (current - start > 1)
                {
                    switch (start[1])
                    {
                        case 'h': return checkKeyword(2, 2, "is", TokenType.THIS);
                        case 'r': return checkKeyword(2, 2, "ue", TokenType.TRUE);
                        default: break;
                    }
                }
            } break;
            case 'v': return checkKeyword(1, 2, "ar", TokenType.VAR);
            case 'w': return checkKeyword(1, 4, "hile", TokenType.WHILE);
            default: break;
        }

        return TokenType.IDENTIFIER;
    }

    private TokenType checkKeyword(int start, int length, const char* rest, TokenType type)
    {
        import core.stdc.string : memcmp;

        if (this.current - this.start == start + length &&
            memcmp(this.start + start, rest, length) == 0)
        {
            return type;
        }

        return TokenType.IDENTIFIER;
    }

    private Token scanIdentifier()
    {
        while (isAlpha(peek()) || isDigit(peek())) advance();
        return makeToken(identifierType());
    }

    private Token scanNumber()
    {
        while (isDigit(peek())) advance();

        if (peek() == '.' && isDigit(peekNext()))
        {
            advance();

            while (isDigit(peek())) advance();
        }

        return makeToken(TokenType.NUMBER);
    }

    private Token scanString()
    {
        while (peek() != '"' && !isAtEnd())
        {
            if (peek() == '\n') line++;
            advance();
        }

        if (isAtEnd()) return errorToken("Unterminated string.");

        advance();
        return makeToken(TokenType.STRING);
    }

    private char peekNext()
    {
        if (isAtEnd()) return '\0';
        return current[1];
    }

    private char peek()
    {
        return *current;
    }

    private char advance()
    {
        current++;
        return current[-1];
    }

    private bool match(char expected)
    {
        if (isAtEnd()) return false;
        if (*current != expected) return false;
        current++;
        return true;
    }

    private bool isAtEnd()
    {
        return *current == '\0';
    }

    private Token makeToken(TokenType type)
    {
        return Token(type, start, cast(int) (current - start), line);
    }

    private Token errorToken(const char* message)
    {
        import core.stdc.string : strlen;

        return Token(TokenType.ERROR, message, cast(int) strlen(message), line);
    }

    private bool isDigit(char c)
    {
        return c >= '0' && c <= '9';
    }

    private bool isAlpha(char c)
    {
        return (c >= 'a' && c <= 'z') ||
               (c >= 'A' && c <= 'Z') ||
               (c == '_');
    }
}
