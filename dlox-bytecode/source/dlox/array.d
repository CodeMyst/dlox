module dlox.array;

import dlox.memory;

struct Array(T)
{
    int length;
    int capacity;
    T[] data;

    auto opOpAssign(string op : "~")(const T rhs)
    {
        if (capacity < length + 1)
        {
            int oldCapacity = capacity;
            capacity = growCapacity(capacity);
            data = growArray!T(data, oldCapacity, capacity);
        }

        data[length] = rhs;
        length++;

        return this;
    }

    ref auto opIndex(size_t index)
    {
        return data[index];
    }

    void free()
    {
        freeArray(data, capacity);
        length = length.init;
        capacity = capacity.init;
        data = data.init;
    }
}
