module dlox.value;

import std.sumtype;

alias Value = SumType!(bool, typeof(null), double);

void printValue(Value value)
{
    import core.stdc.stdio : printf;

    value.match!(
        (bool v) => printf(v ? "true" : "false"),
        (typeof(null) v) => printf("nil"),
        (double v) => printf("%g", v)
    );
}

bool isBool(Value value)
{
    return value.match!(
        (bool b) => true,
        _ => false
    );
}

bool asBool(Value value)
{
    return value.match!(
        (bool b) => b,
        _ => assert(0)
    );
}

bool isNil(Value value)
{
    return value.match!(
        (typeof(null) b) => true,
        _ => false
    );
}

bool isNumber(Value value)
{
    return value.match!(
        (bool b) => false,
        (double b) => true,
        _ => false
    );
}

double asNumber(Value value)
{
    return value.match!(
        (double b) => b,
        _ => assert(0)
    );
}

bool valuesEqual(Value a, Value b)
{
    return a == b;
}
