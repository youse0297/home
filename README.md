# VecMath —— C++ 二维/三维向量库

轻量级控制台工程，实现 `Vec2` / `Vec3` 的加减、数乘、归一化。

## 构建与运行

```bash
mkdir build && cd build
cmake ..
make
./vecmath
```

## 使用示例

```cpp
Vec2 a(1, 2), b(4, -1);
Vec2 c = a + b;            // 加法
Vec2 d = a - b;            // 减法
Vec2 e = a * 2.5;          // 数乘
Vec2 f = 3.0 * a;          // 标量乘向量
Vec2 g = a.normalized();   // 归一化（返回单位向量）

std::cout << a << " + " << b << " = " << c << std::endl;
```

`Vec3` 用法完全一致。

## 设计要点

- 运算符重载：`+`、`-`、`*`（标量）、`/`（标量），支持 `+=`、`-=`、`*=`、`/=`
- 归一化：`normalized()`（不修改原对象）和 `normalize()`（原地修改）
- 零向量归一化返回零向量，除零抛出异常
- 仅依赖 C++17 标准库

## 文件结构

```
src/
  Vec2.hpp / Vec2.cpp
  Vec3.hpp / Vec3.cpp
  main.cpp
CMakeLists.txt
```
