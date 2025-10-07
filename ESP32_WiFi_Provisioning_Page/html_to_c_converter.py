#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HTML转C语言字符串转换工具
用于将HTML文件转换为C语言中的字符串常量

作者: AI Assistant
版本: 1.0
日期: 2024年
"""

import os
import re
import argparse
import sys


class HTMLToCConverter:
    def __init__(self):
        self.line_length = 80  # 每行最大长度
        self.indent = "        "  # C代码缩进
        
    def escape_string(self, content):
        """转义字符串中的特殊字符"""
        # 转义双引号
        content = content.replace('"', '\\"')
        # 转义反斜杠
        content = content.replace('\\', '\\\\')
        # 转义换行符
        content = content.replace('\n', '\\n')
        # 转义回车符
        content = content.replace('\r', '\\r')
        # 转义制表符
        content = content.replace('\t', '\\t')
        
        return content
    
    def minify_html(self, content):
        """压缩HTML内容"""
        # 移除HTML注释
        content = re.sub(r'<!--.*?-->', '', content, flags=re.DOTALL)
        
        # 移除多余空白
        content = re.sub(r'\s+', ' ', content)
        
        # 移除标签间的空白
        content = re.sub(r'>\s+<', '><', content)
        
        # 压缩CSS
        content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
        content = re.sub(r'\s*{\s*', '{', content)
        content = re.sub(r';\s*', ';', content)
        content = re.sub(r'\s*}\s*', '}', content)
        content = re.sub(r':\s*', ':', content)
        content = re.sub(r',\s*', ',', content)
        
        # 压缩JavaScript
        # 移除单行注释
        content = re.sub(r'//.*?\n', '', content)
        # 移除多行注释
        content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
        # 移除多余空白
        content = re.sub(r'\s+', ' ', content)
        
        return content.strip()
    
    def split_string(self, content, max_length=None):
        """将长字符串分割为多行"""
        if max_length is None:
            max_length = self.line_length
        
        lines = []
        current_line = self.indent + '"'
        current_length = len(current_line)
        
        i = 0
        while i < len(content):
            char = content[i]
            
            # 处理转义字符
            if char == '\\' and i + 1 < len(content):
                next_char = content[i + 1]
                if next_char in ['"', '\\', 'n', 'r', 't']:
                    escape_seq = f"\\{next_char}"
                    if current_length + len(escape_seq) > max_length:
                        lines.append(current_line + '"')
                        current_line = self.indent + '"' + escape_seq
                        current_length = len(current_line)
                    else:
                        current_line += escape_seq
                        current_length += len(escape_seq)
                    i += 2
                    continue
            
            # 普通字符
            if current_length + 1 > max_length:
                lines.append(current_line + '"')
                current_line = self.indent + '"' + char
                current_length = len(current_line)
            else:
                current_line += char
                current_length += 1
            
            i += 1
        
        if current_line != self.indent + '"':
            lines.append(current_line + '"')
        
        return lines
    
    def convert_file(self, input_file, output_file=None, minify=True, variable_name="html_content"):
        """转换HTML文件为C语言字符串"""
        try:
            # 读取HTML文件
            with open(input_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 压缩HTML
            if minify:
                content = self.minify_html(content)
            
            # 转义字符串
            content = self.escape_string(content)
            
            # 分割为多行
            lines = self.split_string(content)
            
            # 生成C代码
            c_code = self.generate_c_code(lines, variable_name)
            
            # 输出到文件或控制台
            if output_file:
                with open(output_file, 'w', encoding='utf-8') as f:
                    f.write(c_code)
                print(f"转换完成！输出文件: {output_file}")
            else:
                print(c_code)
                
        except FileNotFoundError:
            print(f"错误: 找不到文件 {input_file}")
            return False
        except Exception as e:
            print(f"转换过程中出现错误: {e}")
            return False
        
        return True
    
    def generate_c_code(self, lines, variable_name):
        """生成C语言代码"""
        c_code = f"// 自动生成的HTML字符串常量\n"
        c_code += f"// 变量名: {variable_name}\n"
        c_code += f"// 生成时间: {self.get_timestamp()}\n\n"
        c_code += f"const char* {variable_name} =\n"
        
        for i, line in enumerate(lines):
            if i == len(lines) - 1:
                # 最后一行添加分号
                c_code += line + ";\n"
            else:
                c_code += line + "\n"
        
        return c_code
    
    def get_timestamp(self):
        """获取当前时间戳"""
        import datetime
        return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def main():
    parser = argparse.ArgumentParser(
        description="HTML转C语言字符串转换工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  python html_to_c_converter.py input.html
  python html_to_c_converter.py input.html -o output.c
  python html_to_c_converter.py input.html -v wifi_page_html --no-minify
  python html_to_c_converter.py input.html -l 100 -o output.c
        """
    )
    
    parser.add_argument('input_file', help='输入的HTML文件路径')
    parser.add_argument('-o', '--output', help='输出的C文件路径（可选）')
    parser.add_argument('-v', '--variable', default='html_content', 
                       help='C语言变量名（默认: html_content）')
    parser.add_argument('-l', '--line-length', type=int, default=80,
                       help='每行最大长度（默认: 80）')
    parser.add_argument('--no-minify', action='store_true',
                       help='不压缩HTML内容')
    
    args = parser.parse_args()
    
    # 检查输入文件是否存在
    if not os.path.exists(args.input_file):
        print(f"错误: 文件 {args.input_file} 不存在")
        sys.exit(1)
    
    # 创建转换器
    converter = HTMLToCConverter()
    converter.line_length = args.line_length
    
    # 执行转换
    success = converter.convert_file(
        args.input_file,
        args.output,
        not args.no_minify,
        args.variable
    )
    
    if not success:
        sys.exit(1)


if __name__ == '__main__':
    main()
