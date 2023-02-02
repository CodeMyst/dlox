module dlox.parser.parser;

import std.variant;

import dlox.error;
import dlox.scanner;
import dlox.parser;

class Parser
{
    private Token[] tokens;
    private int current = 0;

    public this(Token[] tokens)
    {
        this.tokens = tokens;
    }

    public Stmt[] parse()
    {
        Stmt[] statements;
        while (!isAtEnd())
        {
            statements ~= declaration();
        }

        return statements;
    }

    // declaration → varDecl
    //             | statement ;
    private Stmt declaration()
    {
        try
        {
            if (match(TokenType.VAR)) return varDeclaration();

            return statement();
        }
        catch (ParseError error)
        {
            synchronize();
            return null;
        }
    }

    // varDecl → "var" IDENTIFIER ( "=" expression )? ";" ;
    private Stmt varDeclaration()
    {
        Token name = consume(TokenType.IDENTIFIER, "Expect variable name.");

        Expr initializer = null;
        if (match(TokenType.EQUAL)) initializer = expression();

        consume(TokenType.SEMICOLON, "Expect ';' after variable declaration.");

        return new Stmt.Var(name, initializer);
    }

    // statement → exprStmt
    //           | printStmt
    //           | block ;
    private Stmt statement()
    {
        if (match(TokenType.PRINT)) return printStatement();
        if (match(TokenType.LEFT_BRACE)) return new Stmt.Block(block());

        return expressionStatement();
    }

    // printStmt → "print" expression ";" ;
    private Stmt printStatement()
    {
        Expr value = expression();

        consume(TokenType.SEMICOLON, "Expect ';' after value.");

        return new Stmt.Print(value);
    } 

    // block → "{" declaration* "}" ;
    private Stmt[] block()
    {
        Stmt[] statements;

        while (!check(TokenType.RIGHT_BRACE) && !isAtEnd())
        {
            statements ~= declaration();
        }

        consume(TokenType.RIGHT_BRACE, "Expect '}' after block.");
        return statements;
    }

    // exprStmt → expression ";" ;
    private Stmt expressionStatement()
    {
        Expr expr = expression();

        consume(TokenType.SEMICOLON, "Expect ';' after expression.");

        return new Stmt.Expression(expr);
    }

    // expression → assignment ;
    private Expr expression()
    {
        return assignment();
    }

    // assignment → IDENTIFIER "=" assignment
    //            | equality ;
    private Expr assignment()
    {
        Expr expr = equality();

        if (match(TokenType.EQUAL))
        {
            Token equals = previous();
            Expr value = assignment();

            if (auto exprVar = cast(Expr.Variable) expr)
            {
                Token name = exprVar.name;
                return new Expr.Assign(name, value);
            }

            error(equals, "Invalid assignment target.");
        }

        return expr;
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
    //         | "(" expression ")"
    //         | IDENTIFIER ;
    private Expr primary()
    {
        if (match(TokenType.FALSE)) return new Expr.Literal(Variant(false));
        if (match(TokenType.TRUE)) return new Expr.Literal(Variant(true));
        if (match(TokenType.NIL)) return new Expr.Literal(Variant(null));

        if (match(TokenType.NUMBER, TokenType.STRING)) return new Expr.Literal(previous().literal);

        if (match(TokenType.IDENTIFIER)) return new Expr.Variable(previous());

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
