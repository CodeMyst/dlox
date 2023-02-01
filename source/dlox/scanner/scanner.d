module dlox.scanner.scanner;

import std.variant;

import dlox.scanner.token;
import dlox.scanner.token_type;
import dlox.error;

class Scanner
{
    private const string source;

    private Token[] tokens = [];

    private int start = 0;
    private int current = 0;
    private int line = 1;

    private TokenType[string] keywords;

    public this(string source)
    {
        this.source = source;

        keywords = [
            "and": TokenType.AND,
            "class": TokenType.CLASS,
            "else": TokenType.ELSE,
            "false": TokenType.FALSE,
            "for": TokenType.FOR,
            "fun": TokenType.FUN,
            "if": TokenType.IF,
            "nil": TokenType.NIL,
            "or": TokenType.OR,
            "print": TokenType.PRINT,
            "return": TokenType.RETURN,
            "super": TokenType.SUPER,
            "this": TokenType.THIS,
            "true": TokenType.TRUE,
            "var": TokenType.VAR,
            "while": TokenType.WHILE
        ];
    }

    public Token[] scanTokens()
    {
        while (!isAtEnd())
        {
            start = current;
            scanToken();
        }

        tokens ~= new Token(TokenType.EOF, "", Variant(null), line);

        return tokens;
    }

    private void scanToken()
    {
        import std.ascii : isDigit;

        char c = advance();
        switch (c)
        {
            case '(': addToken(TokenType.LEFT_PAREN); break;
            case ')': addToken(TokenType.RIGHT_PAREN); break;
            case '{': addToken(TokenType.LEFT_BRACE); break;
            case '}': addToken(TokenType.RIGHT_BRACE); break;
            case ',': addToken(TokenType.COMMA); break;
            case '.': addToken(TokenType.DOT); break;
            case '-': addToken(TokenType.MINUS); break;
            case '+': addToken(TokenType.PLUS); break;
            case ';': addToken(TokenType.SEMICOLON); break;
            case '*': addToken(TokenType.STAR); break;

            case '!':
                addToken(match('=') ? TokenType.BANG_EQUAL : TokenType.BANG);
                break;

            case '=':
                addToken(match('=') ? TokenType.EQUAL_EQUAL : TokenType.EQUAL);
                break;

            case '<':
                addToken(match('=') ? TokenType.LESS_EQUAL : TokenType.LESS);
                break;

            case '>':
                addToken(match('=') ? TokenType.GREATER_EQUAL : TokenType.GREATER);
                break;

            case '/':
                if (match('/'))
                {
                    while (peek() != '\n' && !isAtEnd()) advance();
                }
                else if (match('*'))
                {
                    scanBlockComment();
                }
                else
                {
                    addToken(TokenType.SLASH);
                }
                break; 
            
            case '"': scanString(); break;
            
            case '\n':
                line++;
                break;
            
            case ' ':
            case '\r':
            case '\t':
                break;

            default:
                if (isDigit(c)) scanNumber();
                else if (isAlpha(c)) scanIdentifier();
                else error(line, "Unexpected character.");
                break;
        }
    }

    private void scanBlockComment()
    {
        int level = 1;
        while (!isAtEnd() && level != 0)
        {
            if (peek() == '\n')
            {
                line++;
            }
            else if (peek() == '/')
            {
                advance();
                if (peek() == '*') level++;
            }
            else if (peek() == '*')
            {
                advance();
                if (peek() == '/') level--;
            }

            advance();
        }
    }

    private void scanString()
    {
        while (peek() != '"' && !isAtEnd())
        {
            if (peek() == '\n') line++;
            advance();
        }

        if (isAtEnd()) {
            error(line, "Unterminated string.");
            return;
        }

        // closing "
        advance();

        // value without ""
        string value = source[start + 1 .. current - 1];
        addToken(TokenType.STRING, Variant(value));
    }

    private void scanNumber()
    {
        import std.ascii : isDigit;
        import std.conv : to;

        while (isDigit(peek())) advance();

        if (peek() == '.' && isDigit(peekNext()))
        {
            advance();

            while (isDigit(peek())) advance();
        }

        addToken(TokenType.NUMBER, to!double(source[start..current]));
    }

    private void scanIdentifier()
    {
        while (isAlphaNumeric(peek())) advance();

        string text = source[start..current];

        if (text in keywords) addToken(keywords[text]);
        else addToken(TokenType.IDENTIFIER);
    }

    private void addToken(TokenType type)
    {
        addToken(type, null);
    }

    private void addToken(TokenType type, double literal)
    {
        addToken(type, Variant(literal));
    }

    private void addToken(TokenType type, string literal)
    {
        addToken(type, Variant(literal));
    }

    private void addToken(TokenType type, Variant literal)
    {
        string text = source[start..current];
        tokens ~= new Token(type, text, literal, line);
    }

    private bool match(char expected)
    {
        if (isAtEnd()) return false;
        if (source[current] != expected) return false;

        current++;

        return true;
    }

    private char peek()
    {
        if (isAtEnd()) return '\0';
        return source[current];
    }

    private char peekNext()
    {
        if (current + 1 >= source.length) return '\0';
        return source[current + 1];
    }

    private char advance()
    {
        return source[current++];
    }

    private bool isAtEnd()
    {
        return current >= source.length;
    }

    private bool isAlpha(char c)
    {
        return (c >= 'a' && c <= 'z') ||
               (c >= 'A' && c <= 'Z') ||
               (c == '_');
    }

    private bool isAlphaNumeric(char c)
    {
        import std.ascii : isDigit;

        return isDigit(c) || isAlpha(c);
    }
}
