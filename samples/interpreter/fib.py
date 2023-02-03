length = 21

a = 0
b = 1

print(a, b, end=" ")

length -= 2

while length > 0:
    print(a + b, end=" ")

    temp = b
    b = a + b
    a = temp

    length -= 1
