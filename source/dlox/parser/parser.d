module dlox.parser.parser;

import std.variant;

import dlox.error;
import dlox.scanner;
import dlox.parser.expression;

class Parser
{
    private Token[] tokens;
    private int current = 0;

    public this(Token[] tokens)
    {
        this.tokens = tokens;
    }

    public Expr parse()
    {
        try
        {
            return expression();
        }
        catch (ParseError err)
        {
            return null;
        }
    }

    // expression → equality ;
    private Expr expression()
    {
        return equality();
    }

    // equality → comparison ( ( "!=" | "==" ) comparison )* ;
    private Expr equality()
    {
        Expr expr = comparison();

        while (match(TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL))
        {
            Token operator = previous();
            Expr right = comparison();

            expr = new Expr.Binary(expr, operator, right);
        }

        return expr;
    }

    // comparison → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
    private Expr comparison()
    {
        Expr expr = term();

        while (match(TokenType.GREATER, TokenType.GREATER_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL))
        {
            Token operator = previous();
            Expr right = term();
            
            expr = new Expr.Binary(expr, operator, right);
        }

        return expr;
    }

    // term → factor ( ( "-" | "+" ) factor )* ;
    private Expr term()
    {
        Expr expr = factor();

        while (match(TokenType.MINUS, TokenType.PLUS))
        {
            Token operator = previous();
            Expr right = factor();

            expr = new Expr.Binary(expr, operator, right);
        }

        return expr;
    }

    // factor → unary ( ( "/" | "*" ) unary )* ;
    private Expr factor()
    {
        Expr expr = unary();

        while (match(TokenType.SLASH, TokenType.STAR))
        {
            Token operator = previous();
            Expr right = unary();

            expr = new Expr.Binary(expr, operator, right);
        }

        return expr;
    }

    // unary → ( "!" | "-" ) unary
    //       | primary ;
    private Expr unary()
    {
        if (match(TokenType.BANG, TokenType.MINUS))
        {
            Token operator = previous();
            Expr right = unary();

            return new Expr.Unary(operator, right);
        }

        return primary();
    }

    // primary → NUMBER | STRING | "true" | "false" | "nil"
    //         | "(" expression ")" ;
    private Expr primary()
    {
        if (match(TokenType.FALSE)) return new Expr.Literal(Variant(false));
        if (match(TokenType.TRUE)) return new Expr.Literal(Variant(true));
        if (match(TokenType.NIL)) return new Expr.Literal(Variant(null));

        if (match(TokenType.NUMBER, TokenType.STRING))
        {
            return new Expr.Literal(previous().literal);
        }

        if (match(TokenType.LEFT_PAREN))
        {
            Expr expr = expression();
            consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");

            return new Expr.Grouping(expr);
        }

        throw parseError(peek(), "Expect expression.");
    } 

    private bool match(TokenType[] types...)
    {
        foreach (type; types)
        {
            if (check(type))
            {
                advance();
                return true;
            }
        }

        return false;
    }

    private Token consume(TokenType type, string message)
    {
        if (check(type)) return advance();

        throw parseError(peek(), message);
    }

    private ParseError parseError(Token token, string message)
    {
        error(token, message);
        return new ParseError();
    }

    private bool check(TokenType type)
    {
        if (isAtEnd()) return false;
        return peek().type == type;
    }

    private Token advance()
    {
        if (!isAtEnd()) current++;
        return previous();
    }

    private bool isAtEnd()
    {
        return peek().type == TokenType.EOF;
    }

    private Token peek()
    {
        return tokens[current];
    }

    private Token previous()
    {
        return tokens[current - 1];
    }

    private void synchronize()
    {
        advance();

        while (!isAtEnd())
        {
            if (previous().type == TokenType.SEMICOLON) return;

            switch (peek().type)
            {
                case TokenType.CLASS:
                case TokenType.FUN:
                case TokenType.VAR:
                case TokenType.FOR:
                case TokenType.IF:
                case TokenType.WHILE:
                case TokenType.PRINT:
                case TokenType.RETURN:
                    return;
                
                default: break;
            }

            advance();
        }
    }
}
