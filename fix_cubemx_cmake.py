#!/usr/bin/env python3
# -*- coding: utf-8 -*-

###############################################################################
# STM32CubeMX CMake 工具链文件自动修复脚本
# 
# 功能：自动更新 STM32CubeMX 生成的 CMake 工具链文件，使其支持 macOS 环境
#       主要修复：工具链路径配置，支持环境变量 ARM_TOOLCHAIN_PATH
#
# 使用方法：
#   方法1：指定文件路径（推荐，可从任何位置运行）
#     python3 /path/to/fix_cubemx_cmake.py /path/to/project/cmake/gcc-arm-none-eabi.cmake
#   
#   方法2：在项目目录中运行（自动搜索）
#     cd /path/to/project
#     python3 /path/to/fix_cubemx_cmake.py
#   
#   方法3：将脚本添加到 PATH（全局使用）
#     # 创建符号链接或添加到 PATH
#     ln -s /path/to/fix_cubemx_cmake.py /usr/local/bin/fix_cubemx_cmake
#     # 然后可以在任何位置使用：
#     fix_cubemx_cmake /path/to/project/cmake/gcc-arm-none-eabi.cmake
#
# 作者：Auto-generated
# 日期：2025年12月
###############################################################################

import sys
import os
import re
from datetime import datetime
from pathlib import Path
import glob

# 颜色输出
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_info(msg):
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {msg}")

def print_success(msg):
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {msg}")

def print_warning(msg):
    print(f"{Colors.YELLOW}[WARNING]{Colors.NC} {msg}")

def print_error(msg):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}")

def is_cubemx_cmake_toolchain(filepath):
    """检查是否是 STM32CubeMX 生成的 CMake 工具链文件"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            # 检查典型的 STM32CubeMX CMake 工具链文件特征
            if ('CMAKE_SYSTEM_NAME' in content and 
                'CMAKE_SYSTEM_PROCESSOR' in content and
                'arm-none-eabi-' in content):
                # 检查是否使用了系统 PATH（需要修复的特征）
                if re.search(r'set\s*\(\s*TOOLCHAIN_PREFIX\s+arm-none-eabi-\s*\)', content):
                    return True
                # 或者检查是否有注释说明使用 PATH
                if 'must be part of path environment' in content.lower():
                    return True
                # 或者检查是否包含 CMAKE_C_COMPILER 等设置（标准工具链文件）
                if ('CMAKE_C_COMPILER' in content and 
                    'CMAKE_ASM_COMPILER' in content and
                    'TOOLCHAIN_PREFIX' in content):
                    return True
            return False
    except Exception as e:
        print_error(f"读取文件失败: {e}")
        return False

def is_already_fixed(filepath):
    """检查是否已经修复过"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            return 'ARM_TOOLCHAIN_PATH' in content or 'ENV{ARM_TOOLCHAIN_PATH}' in content
    except:
        return False

def backup_file(filepath):
    """备份文件"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = f"{filepath}.backup.{timestamp}"
    try:
        import shutil
        shutil.copy2(filepath, backup_path)
        return backup_path
    except Exception as e:
        print_error(f"备份失败: {e}")
        return None

def fix_cmake_toolchain(filepath):
    """修复 CMake 工具链文件"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            lines = content.splitlines(True)
    except Exception as e:
        print_error(f"读取文件失败: {e}")
        return False
    
    # 查找 TOOLCHAIN_PREFIX 定义的位置
    toolchain_prefix_line = -1
    compiler_id_end_line = -1
    
    for i, line in enumerate(lines):
        # 查找编译器 ID 设置结束位置（通常在这些行之后）
        if 'CMAKE_CXX_COMPILER_ID' in line:
            compiler_id_end_line = i
        # 查找 TOOLCHAIN_PREFIX 定义
        if re.search(r'set\s*\(\s*TOOLCHAIN_PREFIX', line, re.IGNORECASE):
            toolchain_prefix_line = i
            break
    
    if toolchain_prefix_line == -1:
        print_error("无法找到 TOOLCHAIN_PREFIX 定义，可能不是标准的 STM32CubeMX CMake 工具链文件")
        return False
    
    print_info(f"找到 TOOLCHAIN_PREFIX 定义在第 {toolchain_prefix_line + 1} 行")
    
    # 查找工具链配置部分的结束位置
    # 查找 CMAKE_C_COMPILER 等定义之后的位置
    toolchain_config_end = -1
    for i in range(toolchain_prefix_line + 1, min(toolchain_prefix_line + 15, len(lines))):
        # 如果遇到注释行（以 # 开头）且不是空行，可能是下一个部分
        if lines[i].strip().startswith('#') and lines[i].strip() != '#':
            toolchain_config_end = i - 1
            break
        # 如果遇到其他重要的设置（如 CMAKE_EXECUTABLE_SUFFIX），说明工具链配置部分结束
        if 'CMAKE_EXECUTABLE_SUFFIX' in lines[i] or 'CMAKE_TRY_COMPILE_TARGET_TYPE' in lines[i]:
            toolchain_config_end = i - 1
            break
    
    # 如果没找到，使用默认范围
    if toolchain_config_end == -1:
        # 查找最后一个工具链命令定义（CMAKE_SIZE 通常是最后一个）
        for i in range(toolchain_prefix_line, min(toolchain_prefix_line + 10, len(lines))):
            if 'CMAKE_SIZE' in lines[i]:
                toolchain_config_end = i
                break
        if toolchain_config_end == -1:
            toolchain_config_end = toolchain_prefix_line + 7  # 默认范围
    
    print_info(f"工具链配置部分：第 {toolchain_prefix_line + 1} 行 到 第 {toolchain_config_end + 1} 行")
    
    # 生成新的工具链配置
    new_config = '''# 工具链路径配置（优先级：环境变量 > 相对路径 > 系统 PATH）
# 优先级1：使用环境变量指定的工具链（推荐，支持全局配置）
if(DEFINED ENV{ARM_TOOLCHAIN_PATH})
    # 使用环境变量指定的工具链路径
    set(TOOLCHAIN_DIR $ENV{ARM_TOOLCHAIN_PATH})
    message(STATUS "Using toolchain from environment: ${TOOLCHAIN_DIR}")
elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../toolchain")
    # 回退到相对路径（兼容旧项目结构）
    get_filename_component(TOOLCHAIN_DIR "${CMAKE_CURRENT_LIST_DIR}/../../toolchain" ABSOLUTE)
    message(STATUS "Using toolchain from relative path: ${TOOLCHAIN_DIR}")
else()
    # 尝试使用系统 PATH 中的工具链（可能缺少 newlib）
    set(TOOLCHAIN_DIR "")
    message(WARNING "ARM_TOOLCHAIN_PATH environment variable not set and ../../toolchain not found. Trying system PATH.")
    message(WARNING "If compilation fails, set ARM_TOOLCHAIN_PATH environment variable to point to ARM GNU Toolchain with newlib.")
endif()

# 设置工具链前缀
if(TOOLCHAIN_DIR)
    set(TOOLCHAIN_PREFIX                ${TOOLCHAIN_DIR}/bin/arm-none-eabi-)
else()
    set(TOOLCHAIN_PREFIX                arm-none-eabi-)
endif()

set(CMAKE_C_COMPILER                ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_ASM_COMPILER              ${CMAKE_C_COMPILER})
set(CMAKE_CXX_COMPILER              ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_LINKER                    ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_OBJCOPY                   ${TOOLCHAIN_PREFIX}objcopy)
set(CMAKE_SIZE                      ${TOOLCHAIN_PREFIX}size)

'''
    
    # 构建新的文件内容
    new_lines = []
    
    # 保留 TOOLCHAIN_PREFIX 之前的内容
    if compiler_id_end_line != -1:
        new_lines.extend(lines[:compiler_id_end_line + 1])
        print_info(f"保留编译器 ID 设置之前的内容（{compiler_id_end_line + 1} 行）")
    else:
        new_lines.extend(lines[:toolchain_prefix_line])
        print_info(f"保留 TOOLCHAIN_PREFIX 之前的内容（{toolchain_prefix_line} 行）")
    
    # 添加新的配置
    new_lines.extend(new_config.splitlines(True))
    print_info("已添加新的工具链配置")
    
    # 跳过原有的工具链配置部分，找到下一个重要部分
    skip_count = 0
    found_next_section = False
    
    for i in range(toolchain_config_end + 1, len(lines)):
        line = lines[i]
        stripped = line.strip()
        
        # 跳过原有的 TOOLCHAIN_PREFIX 和工具链命令定义
        if (re.search(r'set\s*\(\s*TOOLCHAIN_PREFIX', line, re.IGNORECASE) or
            re.search(r'set\s*\(\s*CMAKE_(C|CXX|ASM)_COMPILER', line, re.IGNORECASE) or
            re.search(r'set\s*\(\s*CMAKE_(LINKER|OBJCOPY|SIZE)', line, re.IGNORECASE)):
            skip_count += 1
            continue
        
        # 跳过注释说明行（如 "arm-none-eabi- must be part of path environment"）
        if 'must be part of path' in line.lower() or 'path environment' in line.lower():
            skip_count += 1
            continue
        
        # 如果遇到新的重要部分，从这里开始保留
        if (stripped.startswith('#') and len(stripped) > 1) or 'CMAKE_EXECUTABLE_SUFFIX' in line:
            new_lines.extend(lines[i:])
            found_next_section = True
            print_info(f"找到下一个部分，从第 {i + 1} 行开始保留后续内容（跳过了 {skip_count} 行）")
            break
    
    # 如果没有找到明显的分界，保留 toolchain_config_end 之后的所有行（跳过工具链相关）
    if not found_next_section:
        print_warning("未找到明显的分界标记，将保留所有后续内容（跳过工具链相关行）")
        for i in range(toolchain_config_end + 1, len(lines)):
            line = lines[i]
            # 跳过原有的工具链配置
            if (re.search(r'set\s*\(\s*TOOLCHAIN_PREFIX', line, re.IGNORECASE) or
                re.search(r'set\s*\(\s*CMAKE_(C|CXX|ASM)_COMPILER', line, re.IGNORECASE) or
                re.search(r'set\s*\(\s*CMAKE_(LINKER|OBJCOPY|SIZE)', line, re.IGNORECASE) or
                'must be part of path' in line.lower()):
                skip_count += 1
                continue
            new_lines.append(line)
        if skip_count > 0:
            print_info(f"跳过了 {skip_count} 行工具链相关定义")
    
    # 写入文件
    try:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        return True
    except Exception as e:
        print_error(f"写入文件失败: {e}")
        return False

def find_cmake_toolchain_files(search_dir='.'):
    """查找 CMake 工具链文件"""
    toolchain_files = []
    seen_files = set()  # 用于去重
    # 常见的工具链文件名
    patterns = [
        '**/gcc-arm-none-eabi.cmake',
        '**/arm-none-eabi.cmake',
        '**/gnu-arm-none-eabi.cmake',
        'cmake/**/*.cmake'
    ]
    
    for pattern in patterns:
        for filepath in glob.glob(os.path.join(search_dir, pattern), recursive=True):
            # 转换为绝对路径以便去重
            abs_path = os.path.abspath(filepath)
            if os.path.isfile(filepath) and abs_path not in seen_files:
                toolchain_files.append(filepath)
                seen_files.add(abs_path)
    
    return toolchain_files

def check_environment():
    """检查环境变量"""
    arm_toolchain = os.environ.get('ARM_TOOLCHAIN_PATH')
    if not arm_toolchain:
        print_warning("环境变量 ARM_TOOLCHAIN_PATH 未设置")
        print_info("建议执行以下命令：")
        print("  export ARM_TOOLCHAIN_PATH=\"$HOME/toolchains/arm-gnu-toolchain-14.2.1\"")
        print("  # 或添加到 ~/.zshrc 或 ~/.bashrc")
        print()
        response = input("是否继续修复工具链文件？(y/n): ")
        if response.lower() != 'y':
            return False
    else:
        print_success(f"环境变量已设置: {arm_toolchain}")
        toolchain_gcc = os.path.join(arm_toolchain, 'bin', 'arm-none-eabi-gcc')
        if not os.path.exists(toolchain_gcc):
            print_warning("工具链文件不存在，请检查路径是否正确")
    return True

def main():
    """主函数"""
    print_info("=" * 50)
    print_info("STM32CubeMX CMake 工具链文件自动修复工具")
    print_info("=" * 50)
    print()
    
    # 获取文件路径
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
        # 转换为绝对路径，支持从任何位置运行
        if not os.path.isabs(filepath):
            # 如果是相对路径，基于当前工作目录解析
            filepath = os.path.abspath(filepath)
        if not os.path.exists(filepath):
            print_error(f"文件不存在: {filepath}")
            # 检查是否有备份文件
            backup_files = []
            file_dir = os.path.dirname(filepath) if os.path.dirname(filepath) else '.'
            if os.path.exists(file_dir):
                for f in os.listdir(file_dir):
                    if f.startswith(os.path.basename(filepath) + '.backup.'):
                        backup_files.append(os.path.join(file_dir, f))
            
            if backup_files:
                print_warning("发现备份文件：")
                for bf in sorted(backup_files):
                    print(f"  - {bf}")
                print()
                response = input("是否从最新的备份文件恢复？(y/n): ")
                if response.lower() == 'y':
                    latest_backup = sorted(backup_files)[-1]
                    import shutil
                    shutil.copy2(latest_backup, filepath)
                    print_success(f"已从备份恢复: {latest_backup} -> {filepath}")
                    print_info("现在可以重新运行修复脚本")
                else:
                    print_info("提示：")
                    print_info("  1. 从备份恢复：cp <备份文件> <目标文件>")
                    print_info("  2. 或从 STM32CubeMX 重新生成项目")
            else:
                print_info("提示：如果文件被删除，可以：")
                print_info("  1. 从 STM32CubeMX 重新生成项目")
                print_info("  2. 或检查其他位置是否有备份文件")
            sys.exit(1)
        toolchain_files = [filepath]
    else:
        # 自动搜索当前目录
        print_info("未指定文件路径，正在搜索 CMake 工具链文件...")
        toolchain_files = find_cmake_toolchain_files('.')
        if not toolchain_files:
            print_warning("未找到 CMake 工具链文件")
            print_info("可能的原因：")
            print_info("  1. 文件已被删除或移动")
            print_info("  2. 文件不在常见位置")
            print_info("")
            print_info("解决方法：")
            print_info("  1. 检查备份文件：ls cmake/*.backup.*")
            print_info("  2. 从备份恢复：cp cmake/gcc-arm-none-eabi.cmake.backup.* cmake/gcc-arm-none-eabi.cmake")
            print_info("  3. 或从 STM32CubeMX 重新生成项目")
            print_info("  4. 或手动指定文件路径：python3 fix_cubemx_cmake.py <文件路径>")
            print()
            response = input("是否继续搜索其他位置？(y/n): ")
            if response.lower() == 'y':
                # 尝试搜索更广泛的模式
                all_cmake_files = []
                for root, dirs, files in os.walk('.'):
                    for file in files:
                        if file.endswith('.cmake') and 'toolchain' in file.lower():
                            all_cmake_files.append(os.path.join(root, file))
                if all_cmake_files:
                    print_info(f"找到 {len(all_cmake_files)} 个可能的工具链文件：")
                    for f in all_cmake_files:
                        print(f"  - {f}")
                    toolchain_files = all_cmake_files
                else:
                    sys.exit(1)
            else:
                sys.exit(1)
        print_info(f"找到 {len(toolchain_files)} 个可能的工具链文件")
    
    # 检查环境变量
    if not check_environment():
        sys.exit(0)
    
    # 处理每个文件（去重，使用绝对路径）
    fixed_count = 0
    processed_files = set()  # 用于跟踪已处理的文件
    
    for filepath in toolchain_files:
        # 转换为绝对路径以便去重
        abs_path = os.path.abspath(filepath)
        if abs_path in processed_files:
            print_info(f"跳过重复文件: {filepath}")
            continue
        processed_files.add(abs_path)
        
        print()
        print_info(f"处理文件: {filepath}")
        
        # 检查是否是 STM32CubeMX 生成的
        if not is_cubemx_cmake_toolchain(filepath):
            print_warning("这可能不是 STM32CubeMX 生成的 CMake 工具链文件")
            response = input("是否继续修复此文件？(y/n): ")
            if response.lower() != 'y':
                print_info(f"跳过文件: {filepath}")
                continue
        
        # 检查是否已经修复过
        if is_already_fixed(filepath):
            print_warning("工具链文件似乎已经修复过（包含 ARM_TOOLCHAIN_PATH）")
            print_info("提示：如果这是新工程，可能是文件内容已包含 ARM_TOOLCHAIN_PATH 配置")
            response = input("是否重新修复此文件？(y/n): ")
            if response.lower() != 'y':
                print_info(f"跳过文件: {filepath}（已修复或不需要修复）")
                continue
        
        # 备份文件
        backup_path = backup_file(filepath)
        if backup_path:
            print_info(f"已备份原文件到: {backup_path}")
        
        # 修复文件
        print_info(f"开始修复工具链文件: {filepath}")
        if fix_cmake_toolchain(filepath):
            print_success("工具链文件修复完成！")
            fixed_count += 1
            if backup_path:
                print_info(f"备份文件: {backup_path}")
        else:
            print_error("修复失败")
    
    # 总结
    print()
    print_info("=" * 50)
    if fixed_count > 0:
        print_success(f"成功修复 {fixed_count} 个文件！")
        print()
        print_info("修复的文件已更新，现在可以尝试编译：")
        print("  cmake --preset Debug")
        print("  cmake --build --preset Debug")
        print()
        print_info("如果环境变量未设置，请执行：")
        print("  export ARM_TOOLCHAIN_PATH=\"$HOME/toolchains/arm-gnu-toolchain-14.2.1\"")
        print("  source ~/.zshrc  # 或 ~/.bashrc")
    else:
        print_warning("没有文件被修复")
        print_info("可能的原因：")
        print_info("  1. 所有文件都已修复过")
        print_info("  2. 跳过了所有文件")
        print_info("  3. 文件不是标准的 STM32CubeMX 工具链文件")

if __name__ == '__main__':
    main()

