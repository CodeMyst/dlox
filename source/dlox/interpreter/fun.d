module dlox.interpreter.fun;

import std.variant;

import dlox.interpreter;
import dlox.parser;

class Fun : Callable
{
    private Stmt.Function declaration;
    private Environment closure;

    public this(Stmt.Function declaration, Environment closure)
    {
        this.declaration = declaration;
        this.closure = closure;
    }

    public override Variant call(Interpreter interpreter, Variant[] arguments)
    {
        Environment environment = new Environment(closure);
        for (int i = 0; i < declaration.params.length; i++)
        {
            environment.define(declaration.params[i].lexeme, arguments[i]);
        }

        try
        {
            interpreter.executeBlock(declaration.body, environment);
        }
        catch (ReturnException returnValue)
        {
            return returnValue.value;
        }

        return Variant(null);
    }

    public override int arity() => cast(int) declaration.params.length;

    public override string toString() const => "<fn " ~ declaration.name.lexeme ~ ">";
}
