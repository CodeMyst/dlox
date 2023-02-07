module dlox.interpreter.resolver;

import std.variant;
import std.range;

import dlox.interpreter;
import dlox.parser;
import dlox.scanner;
import dlox.error;

class Resolver : Expr.Visitor, Stmt.Visitor
{
    private Interpreter interpreter;
    private bool[string][] scopes;
    private FunctionType currentFunction = FunctionType.NONE;
    private ClassType currentClass = ClassType.NONE;

    public this(Interpreter interpreter)
    {
        this.interpreter = interpreter;
    }

    public override Variant visitBlockStmt(Stmt.Block stmt)
    {
        beginScope();
        resolve(stmt.statements);
        endScope();

        return Variant(null);
    }

    public override Variant visitClassStmt(Stmt.Class stmt)
    {
        ClassType enclosingClass = currentClass;
        currentClass = ClassType.CLASS;

        declare(stmt.name);
        define(stmt.name);

        beginScope();
        scopes.back["this"] = true;

        foreach (Stmt.Function method; stmt.methods)
        {
            FunctionType declaration = FunctionType.METHOD;
            if (method.name.lexeme == "init") declaration = FunctionType.INITIALIZER;
            resolveFunction(method, declaration);
        }

        endScope();

        currentClass = enclosingClass;

        return Variant(null);
    }

    public override Variant visitVarStmt(Stmt.Var stmt)
    {
        declare(stmt.name);
        if (stmt.initializer !is null) resolve(stmt.initializer);
        define(stmt.name);

        return Variant(null);
    }

    public override Variant visitVariableExpr(Expr.Variable expr)
    {
        if (!scopes.empty && expr.name.lexeme in scopes.back && scopes.back[expr.name.lexeme] == false)
        {
            error(expr.name, "Can't read local variable in its own initializer.");
        }

        resolveLocal(expr, expr.name);

        return Variant(null);
    }

    public override Variant visitAssignExpr(Expr.Assign expr)
    {
        resolve(expr.value);
        resolveLocal(expr, expr.name);

        return Variant(null);
    }

    public override Variant visitFunctionStmt(Stmt.Function stmt)
    {
        declare(stmt.name);
        define(stmt.name);

        resolveFunction(stmt, FunctionType.FUNCTION);

        return Variant(null);
    }

    public override Variant visitExpressionStmt(Stmt.Expression stmt)
    {
        resolve(stmt.expression);

        return Variant(null);
    }

    public override Variant visitIfStmt(Stmt.If stmt)
    {
        resolve(stmt.condition);
        resolve(stmt.thenBranch);

        if (stmt.elseBranch !is null) resolve(stmt.elseBranch);

        return Variant(null);
    }

    public override Variant visitPrintStmt(Stmt.Print stmt)
    {
        resolve(stmt.expression);

        return Variant(null);
    }

    public override Variant visitReturnStmt(Stmt.Return stmt)
    {
        if (currentFunction == FunctionType.NONE) error(stmt.keyword, "Can't return from top-level code.");

        if (stmt.value !is null)
        {
            if (currentFunction == FunctionType.INITIALIZER)
            {
                error(stmt.keyword, "Can't return a value from an initializer.");
            }
            resolve(stmt.value);
        }

        return Variant(null);
    }

    public override Variant visitBreakStmt(Stmt.Break stmt)
    {
        return Variant(null);
    }

    public override Variant visitWhileStmt(Stmt.While stmt)
    {
        resolve(stmt.condition);
        resolve(stmt.body);

        return Variant(null);
    }

    public override Variant visitBinaryExpr(Expr.Binary expr)
    {
        resolve(expr.left);
        resolve(expr.right);

        return Variant(null);
    }

    public override Variant visitCallExpr(Expr.Call expr)
    {
        resolve(expr.callee);

        foreach (arg; expr.arguments) resolve(arg);

        return Variant(null);
    }

    public override Variant visitGetExpr(Expr.Get expr)
    {
        resolve(expr.object);

        return Variant(null);
    }

    public override Variant visitGroupingExpr(Expr.Grouping expr)
    {
        resolve(expr.expression);

        return Variant(null);
    }

    public override Variant visitLiteralExpr(Expr.Literal expr)
    {
        return Variant(null);
    }

    public override Variant visitLogicalExpr(Expr.Logical expr)
    {
        resolve(expr.left);
        resolve(expr.right);

        return Variant(null);
    }

    public override Variant visitSetExpr(Expr.Set expr)
    {
        resolve(expr.value);
        resolve(expr.object);

        return Variant(null);
    }

    public override Variant visitThisExpr(Expr.This expr)
    {
        if (currentClass == ClassType.NONE)
        {
            error(expr.keyword, "Can't use 'this' outside of a class.");
            return Variant(null);
        }

        resolveLocal(expr, expr.keyword);

        return Variant(null);
    }

    public override Variant visitUnaryExpr(Expr.Unary expr)
    {
        resolve(expr.right);

        return Variant(null);
    }

    private void resolveFunction(Stmt.Function stmt, FunctionType type)
    {
        FunctionType enclosingFunction = currentFunction;
        currentFunction = type;

        beginScope();
        foreach (param; stmt.params)
        {
            declare(param);
            define(param);
        }

        resolve(stmt.body);
        endScope();

        currentFunction = enclosingFunction;
    }

    private void resolveLocal(Expr expr, Token name)
    {
        for (int i = cast(int) scopes.length - 1; i >= 0; i--)
        {
            if (name.lexeme in scopes[i])
            {
                interpreter.resolve(expr, cast(int) scopes.length - 1 - i);
                return;
            }
        }
    }

    private void declare(Token name)
    {
        if (scopes.empty) return;

        auto s = scopes.back;
        if (name.lexeme in s)
        {
            error(name, "Already a variable with this name in this scope.");
        }

        s[name.lexeme] = false;
    }

    private void define(Token name)
    {
        if (scopes.empty) return;
        scopes.back[name.lexeme] = true;
    }

    private void beginScope()
    {
        scopes.length++;
    }

    private void endScope()
    {
        scopes.popBack();
    }

    public void resolve(Stmt[] statements)
    {
        foreach (stmt; statements) resolve(stmt);
    }

    private void resolve(Stmt stmt)
    {
        stmt.accept(this);
    }

    private void resolve(Expr expr)
    {
        expr.accept(this);
    }
}
