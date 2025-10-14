import json, sys

a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))

a = a["entities"]
b = b["entities"]
print("Missing in", sys.argv[1], ":")
for i in (set(b) - set(a)):
    print("\t" + i)

print("\n\nMissing in", sys.argv[2], ":")
for i in (set(a) - set(b)):
    print("\t" + i)

print("\nIntersection:")
for i in set(a).intersection(b):
    print("\t" + i)
