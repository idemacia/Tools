# STM32CubeMX CMake 工具链文件自动修复脚本使用说明

## 📋 功能说明

`fix_cubemx_cmake.py` 是一个自动化脚本，用于修复 STM32CubeMX 生成的 CMake 工具链文件，使其支持 macOS 环境下的全局工具链配置。

### 主要功能

- ✅ 自动检测 STM32CubeMX 生成的 CMake 工具链文件
- ✅ 修改工具链配置，支持 `ARM_TOOLCHAIN_PATH` 环境变量
- ✅ 自动备份原文件（带时间戳）
- ✅ 支持自动搜索工具链文件
- ✅ 友好的命令行输出和错误提示

### 修复内容

脚本会将工具链配置从：
```cmake
# arm-none-eabi- must be part of path environment
set(TOOLCHAIN_PREFIX arm-none-eabi-)
```

修改为：
```cmake
# 工具链路径配置（优先级：环境变量 > 相对路径 > 系统 PATH）
if(DEFINED ENV{ARM_TOOLCHAIN_PATH})
    set(TOOLCHAIN_DIR $ENV{ARM_TOOLCHAIN_PATH})
    set(TOOLCHAIN_PREFIX ${TOOLCHAIN_DIR}/bin/arm-none-eabi-)
elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../toolchain")
    get_filename_component(TOOLCHAIN_DIR "${CMAKE_CURRENT_LIST_DIR}/../../toolchain" ABSOLUTE)
    set(TOOLCHAIN_PREFIX ${TOOLCHAIN_DIR}/bin/arm-none-eabi-)
else()
    set(TOOLCHAIN_PREFIX arm-none-eabi-)
    message(WARNING "Using system PATH toolchain...")
endif()
```

## 🚀 使用方法

**重要**：脚本可以从任何位置运行，**无需复制到项目目录**！

### 方法一：指定文件路径（推荐，可从任何位置运行）

```bash
# 从任何位置运行，指定完整的文件路径
python3 /path/to/fix_cubemx_cmake.py /path/to/project/cmake/gcc-arm-none-eabi.cmake

# 示例
python3 ~/Desktop/git/test/fix_cubemx_cmake.py ~/Desktop/demo_cmake/cmake/gcc-arm-none-eabi.cmake
```

### 方法二：在项目目录中运行（自动搜索）

在项目根目录运行脚本，会自动搜索常见的工具链文件：

```bash
cd /path/to/your/project
python3 /path/to/fix_cubemx_cmake.py
```

### 方法三：全局安装（可选，更方便）

将脚本添加到系统 PATH，可以在任何位置直接使用：

```bash
# 创建符号链接到 /usr/local/bin（需要管理员权限）
sudo ln -s /path/to/fix_cubemx_cmake.py /usr/local/bin/fix_cubemx_cmake
chmod +x /path/to/fix_cubemx_cmake.py

# 或者添加到用户本地 bin 目录（推荐）
mkdir -p ~/bin
ln -s /path/to/fix_cubemx_cmake.py ~/bin/fix_cubemx_cmake
chmod +x /path/to/fix_cubemx_cmake.py
# 确保 ~/bin 在 PATH 中（添加到 ~/.zshrc）
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 然后可以在任何位置使用：
fix_cubemx_cmake /path/to/project/cmake/gcc-arm-none-eabi.cmake
```

脚本会自动搜索以下位置：
- `cmake/gcc-arm-none-eabi.cmake`
- `cmake/arm-none-eabi.cmake`
- `cmake/gnu-arm-none-eabi.cmake`
- `cmake/**/*.cmake`

## 📝 使用示例

### 示例 1：修复单个文件（从任何位置运行）

```bash
# 从任何位置运行，指定完整的文件路径
python3 /Users/huchenxu/Desktop/git/test/fix_cubemx_cmake.py \
    /Users/huchenxu/Desktop/demo-cmake/cmake/gcc-arm-none-eabi.cmake

# 或者使用相对路径（基于当前工作目录）
cd /Users/huchenxu/Desktop
python3 git/test/fix_cubemx_cmake.py demo-cmake/cmake/gcc-arm-none-eabi.cmake
```

**输出示例**：
```
[INFO] ==================================================
[INFO] STM32CubeMX CMake 工具链文件自动修复工具
[INFO] ==================================================

[SUCCESS] 环境变量已设置: /Users/huchenxu/toolchains/arm-gnu-toolchain-14.2.1
[INFO] 处理文件: /Users/huchenxu/Desktop/demo-cmake/cmake/gcc-arm-none-eabi.cmake
[INFO] 已备份原文件到: /Users/huchenxu/Desktop/demo-cmake/cmake/gcc-arm-none-eabi.cmake.backup.20251202_140000
[INFO] 开始修复工具链文件: /Users/huchenxu/Desktop/demo-cmake/cmake/gcc-arm-none-eabi.cmake
[INFO] 找到 TOOLCHAIN_PREFIX 定义在第 9 行
[INFO] 工具链配置部分：第 9 行 到 第 16 行
[INFO] 保留编译器 ID 设置之前的内容（5 行）
[INFO] 已添加新的工具链配置
[INFO] 找到下一个部分，从第 17 行开始保留后续内容（跳过了 7 行）
[SUCCESS] 工具链文件修复完成！
[INFO] 备份文件: /Users/huchenxu/Desktop/demo-cmake/cmake/gcc-arm-none-eabi.cmake.backup.20251202_140000

[SUCCESS] 成功修复 1 个文件！
```

### 示例 2：自动搜索（在项目目录中运行）

```bash
# 进入项目目录
cd /Users/huchenxu/Desktop/demo-cmake

# 运行脚本（会自动搜索工具链文件）
python3 /Users/huchenxu/Desktop/git/test/fix_cubemx_cmake.py
```

### 示例 3：全局安装后使用

```bash
# 如果已经全局安装（添加到 PATH）
fix_cubemx_cmake /Users/huchenxu/Desktop/demo-cmake/cmake/gcc-arm-none-eabi.cmake

# 或者在项目目录中自动搜索
cd /Users/huchenxu/Desktop/demo-cmake
fix_cubemx_cmake
```

**输出示例**：
```
[INFO] ==================================================
[INFO] STM32CubeMX CMake 工具链文件自动修复工具
[INFO] ==================================================

[INFO] 未指定文件路径，正在搜索 CMake 工具链文件...
[INFO] 找到 1 个可能的工具链文件
[SUCCESS] 环境变量已设置: /Users/huchenxu/toolchains/arm-gnu-toolchain-14.2.1
...
```

## ⚙️ 前置条件

### 1. 环境变量配置

确保已设置 `ARM_TOOLCHAIN_PATH` 环境变量：

```bash
# 检查环境变量
echo $ARM_TOOLCHAIN_PATH

# 如果未设置，添加到 ~/.zshrc 或 ~/.bashrc
export ARM_TOOLCHAIN_PATH="$HOME/toolchains/arm-gnu-toolchain-14.2.1"
```

### 2. Python 环境

脚本需要 Python 3.6+，通常 macOS 已自带。

## 🔍 检测逻辑

脚本会检测以下特征来判断是否是 STM32CubeMX 生成的工具链文件：

1. 包含 `CMAKE_SYSTEM_NAME` 和 `CMAKE_SYSTEM_PROCESSOR` 设置
2. 包含 `arm-none-eabi-` 相关配置
3. 包含 `set(TOOLCHAIN_PREFIX arm-none-eabi-)` 或类似配置
4. 包含 "must be part of path environment" 注释

## ⚠️ 注意事项

### 1. 备份文件

脚本会自动备份原文件，备份文件名格式：
```
原文件名.backup.YYYYMMDD_HHMMSS
```

例如：
```
gcc-arm-none-eabi.cmake.backup.20251202_140000
```

### 2. 已修复的文件

如果文件已经包含 `ARM_TOOLCHAIN_PATH` 配置，脚本会提示是否重新修复。

### 3. 非标准文件

如果检测到不是标准的 STM32CubeMX 工具链文件，脚本会询问是否继续。

## 🐛 故障排除

### 问题 1：找不到工具链文件

**错误信息**：
```
[ERROR] 未找到 CMake 工具链文件
```

**解决方法**：
- 手动指定文件路径
- 确保在项目根目录运行脚本
- 检查文件是否存在：`ls cmake/*.cmake`

### 问题 2：环境变量未设置

**错误信息**：
```
[WARNING] 环境变量 ARM_TOOLCHAIN_PATH 未设置
```

**解决方法**：
```bash
# 临时设置（当前终端有效）
export ARM_TOOLCHAIN_PATH="$HOME/toolchains/arm-gnu-toolchain-14.2.1"

# 永久设置（添加到 ~/.zshrc）
echo 'export ARM_TOOLCHAIN_PATH="$HOME/toolchains/arm-gnu-toolchain-14.2.1"' >> ~/.zshrc
source ~/.zshrc
```

### 问题 3：修复后编译仍然失败

**可能原因**：
- 环境变量未正确设置
- 工具链路径不正确
- 需要重新配置 CMake

**解决方法**：
```bash
# 1. 检查环境变量
echo $ARM_TOOLCHAIN_PATH

# 2. 验证工具链
$ARM_TOOLCHAIN_PATH/bin/arm-none-eabi-gcc --version

# 3. 清理并重新配置
rm -rf build
cmake --preset Debug
cmake --build --preset Debug
```

## 📊 修复前后对比

### 修复前

```cmake
set(CMAKE_C_COMPILER_ID GNU)
set(CMAKE_CXX_COMPILER_ID GNU)

# Some default GCC settings
# arm-none-eabi- must be part of path environment
set(TOOLCHAIN_PREFIX arm-none-eabi-)

set(CMAKE_C_COMPILER ${TOOLCHAIN_PREFIX}gcc)
```

**问题**：
- 使用系统 PATH 中的工具链
- 在 macOS 上可能使用 Homebrew 的工具链（缺少 newlib）
- 无法使用全局配置的工具链

### 修复后

```cmake
set(CMAKE_C_COMPILER_ID GNU)
set(CMAKE_CXX_COMPILER_ID GNU)

# 工具链路径配置（优先级：环境变量 > 相对路径 > 系统 PATH）
if(DEFINED ENV{ARM_TOOLCHAIN_PATH})
    set(TOOLCHAIN_DIR $ENV{ARM_TOOLCHAIN_PATH})
    set(TOOLCHAIN_PREFIX ${TOOLCHAIN_DIR}/bin/arm-none-eabi-)
elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../toolchain")
    get_filename_component(TOOLCHAIN_DIR "${CMAKE_CURRENT_LIST_DIR}/../../toolchain" ABSOLUTE)
    set(TOOLCHAIN_PREFIX ${TOOLCHAIN_DIR}/bin/arm-none-eabi-)
else()
    set(TOOLCHAIN_PREFIX arm-none-eabi-)
    message(WARNING "Using system PATH toolchain...")
endif()

set(CMAKE_C_COMPILER ${TOOLCHAIN_PREFIX}gcc)
```

**优势**：
- ✅ 优先使用环境变量指定的工具链（包含 newlib）
- ✅ 支持全局配置，项目可移植
- ✅ 兼容旧项目结构（相对路径）
- ✅ 提供警告信息

## 🔗 相关文档

- [STM32_CMake编译配置完整教程.md](./STM32_CMake编译配置完整教程.md)
- [工具链路径可移植性配置指南.md](./工具链路径可移植性配置指南.md)
- [fix_cubemx_makefile.py](./fix_cubemx_makefile.py) - Makefile 修复脚本

## 📝 更新日志

### v1.0.0 (2025-12-02)
- 初始版本
- 支持自动检测和修复 STM32CubeMX CMake 工具链文件
- 支持环境变量配置
- 自动备份功能

## 💡 提示

1. **一键修复**：在项目根目录运行脚本，无需指定路径
2. **安全备份**：每次修复前自动备份，可随时恢复
3. **全局配置**：配合 `ARM_TOOLCHAIN_PATH` 环境变量，一次配置，所有项目可用

## 📧 反馈

如果遇到问题或有改进建议，请检查：
1. Python 版本（需要 3.6+）
2. 文件权限（脚本需要读取和写入权限）
3. 环境变量配置

