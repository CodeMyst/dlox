module dlox.memory;

import core.stdc.stdlib;

int growCapacity(int capacity)
{
    return capacity < 8 ? 8 : capacity * 2;
}

T[] growArray(T)(T[] arr, int oldCount, int newCount)
{
    return reallocate!T(arr, T.sizeof * oldCount, T.sizeof * newCount);
}

void freeArray(T)(T[] arr, int oldCount)
{
    reallocate(arr, T.sizeof * oldCount, 0);
}

T[] reallocate(T)(T[] arr, size_t oldSize, size_t newSize)
{
    // TODO: maybe try and implement this without malloc and free :)

    if (newSize == 0)
    {
        free(arr.ptr);
        return null;
    }

    void* res = realloc(arr.ptr, newSize);
    if (res is null) exit(137);

    return cast(T[]) res[0..newSize];
}
