module dlox.interpreter.klass;

import std.variant;

import dlox.interpreter;

class Class : Callable
{
    public string name;
    private Class superclass;

    private Fun[string] methods;

    public this(string name, Class superclass, Fun[string] methods)
    {
        this.name = name;
        this.methods = methods;
        this.superclass = superclass;
    }

    public override Variant call(Interpreter interpreter, Variant[] arguments)
    {
        Instance instance = new Instance(this);

        Fun initializer = findMethod("init");
        if (initializer !is null) initializer.bind(instance).call(interpreter, arguments);

        return Variant(instance);
    }

    public Fun findMethod(string name)
    {
        if (name in methods) return methods[name];

        if (superclass !is null) return superclass.findMethod(name);

        return null;
    }

    public override int arity()
    {
        Fun initializer = findMethod("init");
        if (initializer is null) return 0;
        return initializer.arity();
    }

    public override string toString() const
    {
        return name;
    }
}
