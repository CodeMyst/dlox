module dlox.compiler;

import core.stdc.stdio;
import std.typecons;

import dlox.scanner;
import dlox.common;
import dlox.value;
import dlox.object;

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

struct Local
{
    Token name;
    int depth;
}

struct Compiler
{
    Local[ubyte.max + 1] locals;
    int localCount;
    int scopeDepth;
}

alias ParseFn = void function(bool);

private Parser parser;
private Scanner scanner;
private Compiler* current = null;
private Chunk* compilingChunk;

bool compile(const char* source, Chunk* chunk)
{
    scanner = Scanner(source);
    Compiler compiler;
    initCompiler(&compiler);
    compilingChunk = chunk;
    advance();

    while (!match(TokenType.EOF))
    {
        declaration();
    }

    endCompiler();
    return !parser.hadError;
}

private void endCompiler()
{
    emitReturn();

    debug (printCode)
    {
        if (!parser.hadError)
            currentChunk().disassemble("code");
    }
}

private void beginScope()
{
    current.scopeDepth++;
}

private void endScope()
{
    current.scopeDepth--;

    while (current.localCount > 0 &&
            current.locals[current.localCount - 1].depth > current.scopeDepth)
    {
        emitByte(OpCode.POP);
        current.localCount--;
    }
}

private void binary(bool _)
{
    TokenType operatorType = parser.previous.type;
    ParseRule* rule = getRule(operatorType);
    parsePrecedence(cast(Precedence)(rule.precedence + 1));

    switch (operatorType)
    {
    case TokenType.BANG_EQUAL:
        emitBytes(OpCode.EQUAL, OpCode.NOT);
        break;
    case TokenType.EQUAL_EQUAL:
        emitByte(OpCode.EQUAL);
        break;
    case TokenType.GREATER:
        emitByte(OpCode.GREATER);
        break;
    case TokenType.GREATER_EQUAL:
        emitBytes(OpCode.LESS, OpCode.NOT);
        break;
    case TokenType.LESS:
        emitByte(OpCode.LESS);
        break;
    case TokenType.LESS_EQUAL:
        emitBytes(OpCode.GREATER, OpCode.NOT);
        break;
    case TokenType.PLUS:
        emitByte(OpCode.ADD);
        break;
    case TokenType.MINUS:
        emitByte(OpCode.SUBTRACT);
        break;
    case TokenType.STAR:
        emitByte(OpCode.MULTIPLY);
        break;
    case TokenType.SLASH:
        emitByte(OpCode.DIVIDE);
        break;
    default:
        assert(0);
    }
}

private void literal(bool _)
{
    switch (parser.previous.type)
    {
    case TokenType.FALSE:
        emitByte(OpCode.FALSE);
        break;
    case TokenType.NIL:
        emitByte(OpCode.NIL);
        break;
    case TokenType.TRUE:
        emitByte(OpCode.TRUE);
        break;
    default:
        assert(0);
    }
}

private void grouping(bool _)
{
    expression();
    consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");
}

private void number(bool _)
{
    import core.stdc.stdlib : strtod;

    double value = strtod(parser.previous.start, null);
    emitConstant(Value(value));
}

private void string(bool _)
{
    Obj* obj = cast(Obj*) copyString(parser.previous.start + 1, parser.previous.length - 2);
    emitConstant(Value(obj));
}

private void namedVariable(Token name, bool canAssign)
{
    ubyte getOp;
    ubyte setOp;
    int arg = resolveLocal(current, &name);
    if (arg != -1)
    {
        getOp = OpCode.GET_LOCAL;
        setOp = OpCode.SET_LOCAL;
    }
    else
    {
        arg = identifierConstant(&name);
        getOp = OpCode.GET_GLOBAL;
        setOp = OpCode.SET_GLOBAL;
    }

    if (canAssign && match(TokenType.EQUAL))
    {
        expression();
        emitBytes(OpCode.SET_GLOBAL, cast(ubyte) arg);
    }
    else
    {
        emitBytes(OpCode.GET_GLOBAL, cast(ubyte) arg);
    }
}

private void variable(bool canAssign)
{
    namedVariable(parser.previous, canAssign);
}

private void unary(bool _)
{
    TokenType operatorType = parser.previous.type;

    parsePrecedence(Precedence.UNARY);

    switch (operatorType)
    {
    case TokenType.BANG:
        emitByte(OpCode.NOT);
        break;
    case TokenType.MINUS:
        emitByte(OpCode.NEGATE);
        break;
    default:
        assert(0);
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
  TokenType.IDENTIFIER    : ParseRule(&variable, null,    Precedence.NONE),
  TokenType.STRING        : ParseRule(&string,   null,    Precedence.NONE),
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

    bool canAssign = precedence <= Precedence.ASSIGNMENT;
    prefixRule(canAssign);

    while (precedence <= getRule(parser.current.type).precedence)
    {
        advance();
        ParseFn infixRule = getRule(parser.previous.type).infix;
        infixRule(canAssign);
    }

    if (canAssign && match(TokenType.EQUAL))
    {
        error("Invalid assignment target.");
    }
}

private ubyte identifierConstant(Token* name)
{
    return makeConstant(Value(cast(Obj*) copyString(name.start, name.length)));
}

private bool identifiersEqual(Token* a, Token* b)
{
    import core.stdc.string : memcmp;

    if (a.length != b.length) return false;

    return memcmp(a.start, b.start, a.length) == 0;
}

private int resolveLocal(Compiler* compiler, Token* name)
{
    for (int i = compiler.localCount - 1; i >= 0; i--)
    {
        Local* local = &compiler.locals[i];
        if (identifiersEqual(name, &local.name))
        {
            if (local.depth == -1)
            {
                error("Can't read local variable in its own initializer.");
            }

            return i;
        }
    }

    return -1;
}

private void addLocal(Token name)
{
    if (current.localCount == ubyte.max + 1)
    {
        error("Too many local variables in function.");
        return;
    }

    Local* local = &current.locals[current.localCount++];
    local.name = name;
    local.depth = -1;
}

private void declareVariable()
{
    if (current.scopeDepth == 0) return;

    Token* name = &parser.previous;

    for (int i = current.localCount - 1; i >= 0; i--)
    {
        Local* local = &current.locals[i];
        if (local.depth != -1 && local.depth < current.scopeDepth)
        {
            break;
        }

        if (identifiersEqual(name, &local.name))
        {
            error("Already a variable with this name in this scope.");
        }
    }

    addLocal(*name);
}

private ubyte parseVariable(const char* errorMessage)
{
    consume(TokenType.IDENTIFIER, errorMessage);

    declareVariable();
    if (current.scopeDepth > 0) return 0;

    return identifierConstant(&parser.previous);
}

private void markInitialized()
{
    current.locals[current.localCount - 1].depth = current.scopeDepth;
}

private void defineVariable(ubyte global)
{
    if (current.scopeDepth > 0)
    {
        markInitialized();
        return;
    }

    emitBytes(OpCode.DEFINE_GLOBAL, global);
}

private ParseRule* getRule(TokenType type)
{
    return &rules[type];
}

private void expression()
{
    parsePrecedence(Precedence.ASSIGNMENT);
}

private void block()
{
    while (!check(TokenType.RIGHT_BRACE) && !check(TokenType.EOF))
    {
        declaration();
    }

    consume(TokenType.RIGHT_BRACE, "Expect '}' after block.");
}

private void varDeclaration()
{
    ubyte global = parseVariable("Expect variable name.");

    if (match(TokenType.EQUAL))
    {
        expression();
    }
    else
    {
        emitByte(OpCode.NIL);
    }

    consume(TokenType.SEMICOLON, "Expect ';' after variable declaration.");

    defineVariable(global);
}

private void expressionStatement()
{
    expression();
    consume(TokenType.SEMICOLON, "Expect ';' after expression.");
    emitByte(OpCode.POP);
}

private void printStatement()
{
    expression();
    consume(TokenType.SEMICOLON, "Expect ';' after value.");
    emitByte(OpCode.PRINT);
}

private void synchronize()
{
    parser.panicMode = false;

    while (parser.current.type != TokenType.EOF)
    {
        if (parser.previous.type == TokenType.SEMICOLON) return;

        switch (parser.current.type)
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

private void declaration()
{
    if (match(TokenType.VAR))
    {
        varDeclaration();
    }
    else
    {
        statement();
    }

    if (parser.panicMode) synchronize();
}

private void statement()
{
    if (match(TokenType.PRINT))
    {
        printStatement();
    }
    else if (match(TokenType.LEFT_BRACE))
    {
        beginScope();
        block();
        endScope();
    }
    else
    {
        expressionStatement();
    }
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
        if (parser.current.type != TokenType.ERROR)
            break;

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

private bool check(TokenType type)
{
    return parser.current.type == type;
}

private bool match(TokenType type)
{
    if (!check(type)) return false;
    advance();
    return true;
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

private void initCompiler(Compiler* compiler)
{
    compiler.localCount = 0;
    compiler.scopeDepth = 0;
    current = compiler;
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
    if (parser.panicMode)
        return;
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
