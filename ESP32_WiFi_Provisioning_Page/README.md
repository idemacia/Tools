# HTML转C语言转换工具使用说明

## 工具概述

`html_to_c_converter.py` 是一个专门用于将HTML文件转换为C语言字符串常量的Python工具。该工具特别适用于嵌入式开发中需要将HTML页面嵌入到固件中的场景。

## 功能特性

- ✅ **智能HTML压缩**: 自动移除注释、多余空白，压缩CSS和JavaScript
- ✅ **字符串转义**: 自动处理C语言字符串中的特殊字符
- ✅ **代码格式化**: 智能换行，保持代码可读性
- ✅ **灵活配置**: 支持自定义变量名、行长度等参数
- ✅ **批量处理**: 支持批量转换多个文件

## 安装要求

- Python 3.6+
- 无需额外依赖包

## 使用方法

### 基本用法

```bash
# 转换单个HTML文件，输出到控制台
python3 html_to_c_converter.py input.html

# 转换并保存到文件
python3 html_to_c_converter.py input.html -o output.c
```

### 高级用法

```bash
# 自定义变量名和行长度
python3 html_to_c_converter.py input.html -o output.c -v wifi_page_html -l 100

# 不压缩HTML内容
python3 html_to_c_converter.py input.html --no-minify

# 查看帮助信息
python3 html_to_c_converter.py -h
```

### 参数说明

| 参数 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `input_file` | - | 输入的HTML文件路径 | 必需 |
| `--output` | `-o` | 输出的C文件路径 | 输出到控制台 |
| `--variable` | `-v` | C语言变量名 | `html_content` |
| `--line-length` | `-l` | 每行最大长度 | `80` |
| `--no-minify` | - | 不压缩HTML内容 | 默认压缩 |

## 使用示例

### 示例1：基本转换

```bash
python3 html_to_c_converter.py example.html
```

输出：
```c
const char* html_content =
        "<!DOCTYPE html><html><head><title>Example</title></head><body>"
        "<h1>Hello World</h1></body></html>";
```

### 示例2：自定义参数

```bash
python3 html_to_c_converter.py example.html -o wifi_page.c -v wifi_html -l 120
```

输出：
```c
// 自动生成的HTML字符串常量
// 变量名: wifi_html
// 生成时间: 2024-10-07 10:49:15

const char* wifi_html =
        "<!DOCTYPE html><html><head><title>WiFi Setup</title></head><body>"
        "<h1>WiFi Configuration</h1><form><input type=\"text\" name=\"ssid\">"
        "<input type=\"password\" name=\"password\"><button type=\"submit\">"
        "Connect</button></form></body></html>";
```

### 示例3：批量转换

```bash
# 转换多个文件
for file in *.html; do
    python3 html_to_c_converter.py "$file" -o "${file%.html}.c" -v "${file%.html}_html"
done
```

## 转换过程详解

### 1. HTML压缩

工具会自动执行以下压缩操作：
- 移除HTML注释 (`<!-- -->`)
- 移除CSS注释 (`/* */`)
- 移除JavaScript注释 (`//` 和 `/* */`)
- 压缩多余空白字符
- 优化CSS和JavaScript代码结构

### 2. 字符串转义

自动处理以下特殊字符：
- 双引号: `"` → `\"`
- 反斜杠: `\` → `\\`
- 换行符: `\n` → `\\n`
- 回车符: `\r` → `\\r`
- 制表符: `\t` → `\\t`

### 3. 代码格式化

- 智能换行，避免超长行
- 保持代码缩进
- 添加必要的注释信息

## 最佳实践

### 1. 文件组织

```
project/
├── tools/
│   ├── html_to_c_converter.py
│   └── html_pages/
│       ├── wifi_setup.html
│       ├── device_config.html
│       └── status_page.html
├── components/
│   └── web_server/
│       ├── wifi_setup.c
│       ├── device_config.c
│       └── status_page.c
└── main/
    └── app_main.c
```

### 2. 命名规范

- HTML文件使用描述性名称：`wifi_setup.html`
- C文件对应命名：`wifi_setup.c`
- 变量名使用下划线：`wifi_setup_html`

### 3. 版本管理

```bash
# 在转换前备份原始HTML文件
cp original.html original.html.backup

# 使用版本控制跟踪变化
git add tools/html_pages/
git commit -m "Update WiFi setup page"
```

## 常见问题

### Q: 转换后的代码无法编译？
A: 检查以下几点：
1. 确保所有引号都正确转义
2. 检查字符串长度是否超过编译器限制
3. 验证C语言语法是否正确

### Q: HTML压缩后功能异常？
A: 可以尝试以下解决方案：
1. 使用 `--no-minify` 参数跳过压缩
2. 检查JavaScript代码是否有语法错误
3. 手动修复压缩后的代码

### Q: 如何处理大型HTML文件？
A: 对于大型文件：
1. 增加行长度参数：`-l 120`
2. 考虑将HTML拆分为多个小文件
3. 使用外部资源链接而非内嵌

### Q: 支持哪些HTML特性？
A: 工具支持标准HTML5特性：
- HTML标签和属性
- CSS样式（包括媒体查询）
- JavaScript代码
- 响应式设计
- 现代浏览器API

## 扩展功能

### 自定义转换规则

可以通过修改源代码来添加自定义转换规则：

```python
def custom_minify(self, content):
    """自定义压缩规则"""
    # 移除特定注释
    content = re.sub(r'<!-- TODO:.*?-->', '', content, flags=re.DOTALL)
    
    # 自定义CSS压缩
    content = re.sub(r'\s*>\s*', '>', content)
    
    return content
```

### 集成到构建系统

```makefile
# Makefile示例
HTML_SOURCES := $(wildcard html_pages/*.html)
C_SOURCES := $(HTML_SOURCES:.html=.c)

%.c: %.html
	python3 tools/html_to_c_converter.py $< -o $@ -v $(basename $(notdir $<))_html

all: $(C_SOURCES)
	# 继续构建过程
```

## 技术支持

如有问题或建议，请：
1. 检查本文档的常见问题部分
2. 查看工具源代码中的注释
3. 提交Issue到项目仓库

## 更新日志

### v1.0.0 (2024-10-07)
- 初始版本发布
- 支持基本的HTML到C语言转换
- 实现HTML压缩和字符串转义
- 支持自定义参数配置
