module dlox.interpreter.fun;

import std.variant;

import dlox.interpreter;
import dlox.parser;

class Fun : Callable
{
    private Stmt.Function declaration;
    private Environment closure;
    private bool isInitializer;

    public this(Stmt.Function declaration, Environment closure, bool isInitializer)
    {
        this.declaration = declaration;
        this.closure = closure;
        this.isInitializer = isInitializer;
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
            if (isInitializer) return closure.getAt(0, "this");

            return returnValue.value;
        }

        if (isInitializer) return closure.getAt(0, "this");

        return Variant(null);
    }

    public Fun bind(Instance instance)
    {
        Environment environment = new Environment(closure);
        environment.define("this", Variant(instance));

        return new Fun(declaration, environment, isInitializer);
    }

    public override int arity() => cast(int) declaration.params.length;

    public override string toString() const => "<fn " ~ declaration.name.lexeme ~ ">";
}
