module dlox.interpreter.interpreter;

import std.variant;
import std.conv;
import std.stdio;
import std.algorithm;

import dlox.error;
import dlox.scanner;
import dlox.parser;
import dlox.interpreter;

class Interpreter : Expr.Visitor, Stmt.Visitor
{
    public Environment globals = new Environment();
    public Environment environment;

    private int[Expr] locals;

    public this()
    {
        environment = globals;

        globals.define("clock", new class Callable {
            override int arity() => 0;

            override Variant call(Interpreter interpreter, Variant[] arguments)
            {
                import std.datetime : Clock, convert;

                return Variant(cast(double) convert!("hnsecs", "msecs")(Clock.currStdTime()) / 1000.0);
            }

            override string toString() const => "<native fn clock>";
        }.to!Variant());
    }

    public void interpret(Stmt[] statements)
    {
        try
        {
            foreach (Stmt statement; statements)
            {
                execute(statement);
            }
        }
        catch (RuntimeError error)
        {
            runtimeError(error);
        }
    }

    public override Variant visitFunctionStmt(Stmt.Function stmt)
    {
        Fun fun = new Fun(stmt, environment, false);
        environment.define(stmt.name.lexeme, Variant(fun));

        return Variant(null);
    }

    public override Variant visitClassStmt(Stmt.Class stmt)
    {
        environment.define(stmt.name.lexeme, Variant(null));

        Fun[string] methods;
        foreach (Stmt.Function method; stmt.methods)
        {
            Fun fun = new Fun(method, environment, method.name.lexeme == "init");
            methods[method.name.lexeme] = fun;
        }

        Class klass = new Class(stmt.name.lexeme, methods);

        environment.assign(stmt.name, Variant(klass));

        return Variant(null);
    }

    public override Variant visitExpressionStmt(Stmt.Expression stmt)
    {
        evaluate(stmt.expression);
        return Variant(null);
    }

    public override Variant visitIfStmt(Stmt.If stmt)
    {
        if (isTruthy(evaluate(stmt.condition))) execute(stmt.thenBranch);
        else if (stmt.elseBranch !is null) execute(stmt.elseBranch);

        return Variant(null);
    }

    public override Variant visitLogicalExpr(Expr.Logical expr)
    {
        Variant left = evaluate(expr.left);

        if (expr.operator.type == TokenType.OR)
        {
            if (isTruthy(left)) return left;
        }
        else
        {
            if (!isTruthy(left)) return left;
        }

        return evaluate(expr.right);
    }

    public override Variant visitWhileStmt(Stmt.While stmt)
    {
        try
        {
            while (isTruthy(evaluate(stmt.condition))) execute(stmt.body);
        }
        catch (BreakException e) { }

        return Variant(null);
    }

    public override Variant visitBreakStmt(Stmt.Break stmt)
    {
        throw new BreakException();
    }

    public override Variant visitReturnStmt(Stmt.Return stmt)
    {
        Variant value = Variant(null);
        if (stmt.value !is null) value = evaluate(stmt.value);

        throw new ReturnException(value);
    }

    public override Variant visitPrintStmt(Stmt.Print stmt)
    {
        Variant value = evaluate(stmt.expression);
        writeln(stringify(value));
        return Variant(null);
    }

    public override Variant visitBlockStmt(Stmt.Block stmt)
    {
        executeBlock(stmt.statements, new Environment(environment));
        return Variant(null);
    }

    public override Variant visitVarStmt(Stmt.Var stmt)
    {
        Variant value = Variant(null);
        if (stmt.initializer !is null)
        {
            value = evaluate(stmt.initializer);
        }

        environment.define(stmt.name.lexeme, value);

        return Variant(null);
    }

    public override Variant visitAssignExpr(Expr.Assign expr)
    {
        Variant value = evaluate(expr.value);

        if (expr in locals)
        {
            environment.assignAt(locals[expr], expr.name, value);
        }
        else
        {
            globals.assign(expr.name, value);
        }

        return value;
    }

    public override Variant visitVariableExpr(Expr.Variable expr)
    {
        return lookUpVariable(expr.name, expr);
    }

    public override Variant visitLiteralExpr(Expr.Literal expr)
    {
        return expr.value;
    }

    public override Variant visitGroupingExpr(Expr.Grouping expr)
    {
        return evaluate(expr.expression);
    }

    public override Variant visitUnaryExpr(Expr.Unary expr)
    {
        Variant right = evaluate(expr.right);

        switch (expr.operator.type)
        {
            case TokenType.MINUS:
                checkNumberOperand(expr.operator, right);
                return (-right.get!double()).to!Variant();

            case TokenType.BANG: return (!isTruthy(right)).to!Variant();

            default: assert(0);
        }
    }

    public override Variant visitCallExpr(Expr.Call expr)
    {
        Variant callee = evaluate(expr.callee);

        Variant[] arguments;
        foreach (argument; expr.arguments)
        {
            arguments ~= evaluate(argument);
        }

        if (!callee.convertsTo!Callable)
        {
            throw new RuntimeError(expr.paren, "Can only call functions and classes.");
        }

        Callable fun = callee.get!Callable();
        if (arguments.length != fun.arity())
        {
            throw new RuntimeError(expr.paren, "Expected " ~
                fun.arity().to!string ~ " arguments but got " ~
                arguments.length.to!string() ~ ".");
        }

        return fun.call(this, arguments);
    }

    public override Variant visitGetExpr(Expr.Get expr)
    {
        Variant obj = evaluate(expr.object);
        if (obj.peek!Instance !is null) return obj.get!Instance().get(expr.name);

        throw new RuntimeError(expr.name, "Only instances have properties.");
    }

    public override Variant visitSetExpr(Expr.Set expr)
    {
        Variant obj = evaluate(expr.object);

        if (obj.peek!Instance is null) throw new RuntimeError(expr.name, "Only instances have fields.");

        Variant value = evaluate(expr.value);
        obj.get!Instance().set(expr.name, value);

        return value;
    }

    public override Variant visitThisExpr(Expr.This expr)
    {
        return lookUpVariable(expr.keyword, expr);
    }

    public override Variant visitBinaryExpr(Expr.Binary expr)
    {
        Variant left = evaluate(expr.left);
        Variant right = evaluate(expr.right);

        switch (expr.operator.type)
        {
            case TokenType.MINUS:
                checkNumberOperands(expr.operator, left, right);
                return Variant(left.get!double() - right.get!double());

            case TokenType.SLASH:
                checkNumberOperands(expr.operator, left, right);
                if (right.get!double == 0) throw new RuntimeError(expr.operator, "Cannot divide by zero.");
                return Variant(left.get!double() / right.get!double());

            case TokenType.STAR:
                checkNumberOperands(expr.operator, left, right);
                return Variant(left.get!double() * right.get!double());

            case TokenType.PLUS:
                if (left.peek!double !is null && right.peek!double !is null)
                    return Variant(left.get!double() + right.get!double());

                if (left.peek!string !is null || right.peek!string !is null)
                    return Variant(left.toString() ~ right.toString());

                throw new RuntimeError(expr.operator, "Operands must be two numbers or two strings.");

            case TokenType.GREATER:
                checkNumberOperands(expr.operator, left, right);
                return Variant(left.get!double() > right.get!double());

            case TokenType.GREATER_EQUAL:
                checkNumberOperands(expr.operator, left, right);
                return Variant(left.get!double() >= right.get!double());

            case TokenType.LESS:
                checkNumberOperands(expr.operator, left, right);
                return Variant(left.get!double() < right.get!double());

            case TokenType.LESS_EQUAL:
                checkNumberOperands(expr.operator, left, right);
                return Variant(left.get!double() <= right.get!double());

            case TokenType.BANG_EQUAL: return (!isEqual(left, right)).to!Variant();
            case TokenType.EQUAL_EQUAL: return isEqual(left, right).to!Variant();

            default: assert(0);
        }
    }

    private Variant evaluate(Expr expr)
    {
        return expr.accept(this);
    }

    private void execute(Stmt stmt)
    {
        stmt.accept(this);
    }

    public void resolve(Expr expr, int depth)
    {
        locals[expr] = depth;
    }

    private Variant lookUpVariable(Token name, Expr expr)
    {
        if (expr !in locals) return globals.get(name);

        return environment.getAt(locals[expr], name.lexeme);
    }

    public void executeBlock(Stmt[] statements, Environment environment)
    {
        Environment previous = this.environment;
        try
        {
            this.environment = environment;

            foreach (Stmt statement; statements) execute(statement);
        }
        finally
        {
            this.environment = previous;
        }
    }

    private bool isTruthy(Variant obj)
    {
        if (obj == Variant(null)) return false;
        if (obj.peek!bool !is null) return obj.get!bool();
        return true;
    }

    private bool isEqual(Variant a, Variant b)
    {
        if (a == Variant(null) && b == Variant(null)) return true;
        if (a == Variant(null)) return false;

        return a == b;
    }

    private void checkNumberOperand(Token operator, Variant operand)
    {
        if (operand.peek!double() !is null) return;
        throw new RuntimeError(operator, "Operand must be a number.");
    }

    private void checkNumberOperands(Token operator, Variant left, Variant right)
    {
        if (left.peek!double() !is null && right.peek!double() !is null) return;
        throw new RuntimeError(operator, "Operands must be numbers.");
    }

    private string stringify(Variant obj)
    {
        if (obj == Variant(null)) return "nil";

        if (obj.peek!double !is null)
        {
            string text = obj.toString();

            if (text.endsWith(".0"))
            {
                text = text[0 .. $ - 2];
            }

            return text;
        }

        return obj.toString();
    }
}
