# ljs
Lua with C/C++/Java/Javascript syntax

I took code and ideas from :

https://github.com/ex/Killa

https://github.com/sajonoso/jual



The default extension is ".ljs".

On folder lua2ljs there is a program to convert lua sources to ljs.

```
lua2ljs afile.lua > afile.ljs
```

This is based on Lua 5.3.5, released on 26 Jun 2018.

For installation instructions, license details, and
further information about Lua, see doc/readme.html.

There is also :

ljsjit at https://github.com/mingodad/ljsjit

ljs-5.1 at https://github.com/mingodad/ljs-5.1

Here is some code to see how it's like:

```
var json = {"name": "bob"};
var A = {t: {f: 7}, n: 3}
A.n = 3;
print(A.n);
A.n += 3;
print(A.n);
A.t.f = 7;
print(A.t.f);
A.t.f += 7;
print(A.t.f);
A.t.f += 7
print(A.t.f);

A.n = 3;
A.t.f = 7;
function A::mutate(yy) {
    print(this.t.f)
    print(this.n)
    this.t.f *= yy
    this.n += yy
}
A->mutate(10)
assert(A.t.f == 70 && A.n == 13)
print(A.t.f, A.n)

```
