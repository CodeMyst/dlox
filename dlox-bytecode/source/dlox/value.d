module dlox.value;

alias Value = double;

void printValue(Value value)
{
    import core.stdc.stdio : printf;

    printf("%g", value);
}
