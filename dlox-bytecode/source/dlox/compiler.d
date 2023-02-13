module dlox.compiler;

import core.stdc.stdio;
import std.typecons;

import dlox.scanner;
import dlox.common;
import dlox.value;

struct Parser
{
    Token current;
    Token previous;
    bool hadError;
    bool panicMode;
}

enum Precedence
{
    NONE,
    ASSIGNMENT,
    OR,
    AND,
    EQUALITY,
    COMPARISON,
    TERM,
    FACTOR,
    UNARY,
    CALL,
    PRIMARY
}

struct ParseRule
{
    ParseFn prefix;
    ParseFn infix;
    Precedence precedence;
}

alias ParseFn = void function();

private Parser parser;
private Scanner scanner;
private Chunk* compilingChunk;

bool compile(const char* source, Chunk* chunk)
{
    scanner = Scanner(source);
    compilingChunk = chunk;
    advance();
    expression();
    consume(TokenType.EOF, "Expect end of expression.");
    endCompiler();
    return !parser.hadError;
}

private void endCompiler()
{
    emitReturn();

    debug(printCode)
    {
        if (!parser.hadError) currentChunk().disassemble("code");
    }
}

private void binary()
{
    TokenType operatorType = parser.previous.type;
    ParseRule* rule = getRule(operatorType);
    parsePrecedence(cast(Precedence) (rule.precedence + 1));

    switch (operatorType)
    {
        case TokenType.BANG_EQUAL: emitBytes(OpCode.EQUAL, OpCode.NOT); break;
        case TokenType.EQUAL_EQUAL: emitByte(OpCode.EQUAL); break;
        case TokenType.GREATER: emitByte(OpCode.GREATER); break;
        case TokenType.GREATER_EQUAL: emitBytes(OpCode.LESS, OpCode.NOT); break;
        case TokenType.LESS: emitByte(OpCode.LESS); break;
        case TokenType.LESS_EQUAL: emitBytes(OpCode.GREATER, OpCode.NOT); break;
        case TokenType.PLUS: emitByte(OpCode.ADD); break;
        case TokenType.MINUS: emitByte(OpCode.SUBTRACT); break;
        case TokenType.STAR: emitByte(OpCode.MULTIPLY); break;
        case TokenType.SLASH: emitByte(OpCode.DIVIDE); break;
        default: assert(0);
    }
}

private void literal()
{
    switch (parser.previous.type)
    {
        case TokenType.FALSE: emitByte(OpCode.FALSE); break;
        case TokenType.NIL: emitByte(OpCode.NIL); break;
        case TokenType.TRUE: emitByte(OpCode.TRUE); break;
        default: assert(0);
    }
}

private void grouping()
{
    expression();
    consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");
}

private void number()
{
    import core.stdc.stdlib : strtod;

    double value = strtod(parser.previous.start, null);
    emitConstant(Value(value));
}

private void unary()
{
    TokenType operatorType = parser.previous.type;

    parsePrecedence(Precedence.UNARY);

    switch (operatorType)
    {
        case TokenType.BANG: emitByte(OpCode.NOT); break;
        case TokenType.MINUS: emitByte(OpCode.NEGATE); break;
        default: assert(0);
    }
}

private ParseRule[] rules = [
  TokenType.LEFT_PAREN    : ParseRule(&grouping, null,    Precedence.NONE),
  TokenType.RIGHT_PAREN   : ParseRule(null,      null,    Precedence.NONE),
  TokenType.LEFT_BRACE    : ParseRule(null,      null,    Precedence.NONE),
  TokenType.RIGHT_BRACE   : ParseRule(null,      null,    Precedence.NONE),
  TokenType.COMMA         : ParseRule(null,      null,    Precedence.NONE),
  TokenType.DOT           : ParseRule(null,      null,    Precedence.NONE),
  TokenType.MINUS         : ParseRule(&unary,    &binary, Precedence.TERM),
  TokenType.PLUS          : ParseRule(null,      &binary, Precedence.TERM),
  TokenType.SEMICOLON     : ParseRule(null,      null,    Precedence.NONE),
  TokenType.SLASH         : ParseRule(null,      &binary, Precedence.FACTOR),
  TokenType.STAR          : ParseRule(null,      &binary, Precedence.FACTOR),
  TokenType.BANG          : ParseRule(&unary,    null,    Precedence.NONE),
  TokenType.BANG_EQUAL    : ParseRule(null,      &binary, Precedence.EQUALITY),
  TokenType.EQUAL         : ParseRule(null,      null,    Precedence.NONE),
  TokenType.EQUAL_EQUAL   : ParseRule(null,      &binary, Precedence.EQUALITY),
  TokenType.GREATER       : ParseRule(null,      &binary, Precedence.COMPARISON),
  TokenType.GREATER_EQUAL : ParseRule(null,      &binary, Precedence.COMPARISON),
  TokenType.LESS          : ParseRule(null,      &binary, Precedence.COMPARISON),
  TokenType.LESS_EQUAL    : ParseRule(null,      &binary, Precedence.COMPARISON),
  TokenType.IDENTIFIER    : ParseRule(null,      null,    Precedence.NONE),
  TokenType.STRING        : ParseRule(null,      null,    Precedence.NONE),
  TokenType.NUMBER        : ParseRule(&number,   null,    Precedence.NONE),
  TokenType.AND           : ParseRule(null,      null,    Precedence.NONE),
  TokenType.CLASS         : ParseRule(null,      null,    Precedence.NONE),
  TokenType.ELSE          : ParseRule(null,      null,    Precedence.NONE),
  TokenType.FALSE         : ParseRule(&literal,  null,    Precedence.NONE),
  TokenType.FOR           : ParseRule(null,      null,    Precedence.NONE),
  TokenType.FUN           : ParseRule(null,      null,    Precedence.NONE),
  TokenType.IF            : ParseRule(null,      null,    Precedence.NONE),
  TokenType.NIL           : ParseRule(&literal,  null,    Precedence.NONE),
  TokenType.OR            : ParseRule(null,      null,    Precedence.NONE),
  TokenType.PRINT         : ParseRule(null,      null,    Precedence.NONE),
  TokenType.RETURN        : ParseRule(null,      null,    Precedence.NONE),
  TokenType.SUPER         : ParseRule(null,      null,    Precedence.NONE),
  TokenType.THIS          : ParseRule(null,      null,    Precedence.NONE),
  TokenType.TRUE          : ParseRule(&literal,  null,    Precedence.NONE),
  TokenType.VAR           : ParseRule(null,      null,    Precedence.NONE),
  TokenType.WHILE         : ParseRule(null,      null,    Precedence.NONE),
  TokenType.ERROR         : ParseRule(null,      null,    Precedence.NONE),
  TokenType.EOF           : ParseRule(null,      null,    Precedence.NONE),
];

private void parsePrecedence(Precedence precedence)
{
    advance();
    ParseFn prefixRule = getRule(parser.previous.type).prefix;
    if (prefixRule is null)
    {
        error("Expect expression.");
        return;
    }

    prefixRule();

    while (precedence <= getRule(parser.current.type).precedence)
    {
        advance();
        ParseFn infixRule = getRule(parser.previous.type).infix;
        infixRule();
    }
}

private ParseRule* getRule(TokenType type)
{
    return &rules[type];
}

private void expression()
{
    parsePrecedence(Precedence.ASSIGNMENT);
}

private Chunk* currentChunk()
{
    return compilingChunk;
}

private void advance()
{
    parser.previous = parser.current;

    while (true)
    {
        parser.current = scanner.scanToken();
        if (parser.current.type != TokenType.ERROR) break;

        errorAtCurrent(parser.current.start);
    }
}

private void consume(TokenType type, const char* message)
{
    if (parser.current.type == type)
    {
        advance();
        return;
    }

    errorAtCurrent(message);
}

private void emitByte(ubyte b)
{
    *currentChunk() ~= tuple(b, parser.previous.line);
}

private void emitBytes(ubyte b1, ubyte b2)
{
    emitByte(b1);
    emitByte(b2);
}

private void emitReturn()
{
    emitByte(OpCode.RETURN);
}

private void emitConstant(Value value)
{
    emitBytes(OpCode.CONSTANT, makeConstant(value));
}

private ubyte makeConstant(Value value)
{
    int constant = currentChunk().addConstant(value);
    if (constant > ubyte.max)
    {
        error("Too many constants in one chunk.");
        return 0;
    }

    return cast(ubyte) constant;
}

private void errorAtCurrent(const char* message)
{
    errorAt(&parser.current, message);
}

private void error(const char* message)
{
    errorAt(&parser.previous, message);
}

private void errorAt(Token* token, const char* message)
{
    if (parser.panicMode) return;
    parser.panicMode = true;

    fprintf(stderr, "[line %d] Error", token.line);

    if (token.type == TokenType.EOF)
    {
        fprintf(stderr, " at end");
    }
    else if (token.type == TokenType.ERROR)
    {

    }
    else
    {
        fprintf(stderr, " at '%.*s'", token.length, token.start);
    }

    fprintf(stderr, ": %s\n", message);
    parser.hadError = true;
}
