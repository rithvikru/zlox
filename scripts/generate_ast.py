import os
import sys
import os.path

def define_struct_zig(class_name: str, fields_str: str, base_name: str) -> str:
    lines = []
    lines.append(f"const {class_name} = struct {{")
    for field in fields_str.split(", "):
        name, type = field.split(":", 1)
        name = name.strip()
        type = type.strip()

        if type == base_name:
            type = f"*{base_name}"
        lines.append(f"    {name}: {type},")
    lines.append("};")
    return "\n".join(lines)

def define_ast(output_dir: str, base_name: str, types: list[str]) -> None:
    path = os.path.join(output_dir, "ast.zig")
    os.makedirs(output_dir, exist_ok=True)
    with open(path, "w") as f:
        f.write("const std = @import(\"std\");\n")
        f.write("const Token = @import(\"scanner.zig\").Token;\n")

        type_details = {}
        struct_definitions = []
        for type_str in types:
            class_name, fields_str = type_str.split(":", 1)
            class_name = class_name.strip()
            fields = fields_str.strip()
            type_details[class_name] = fields
            struct_definitions.append(define_struct_zig(class_name, fields, base_name))

        for struct_def in struct_definitions:
            f.write(struct_def)
            f.write("\n\n")

        f.write(f"pub const {base_name} = union(enum) {{\n")

        for class_name in type_details.keys():
            f.write(f"    {class_name.lower()}: {class_name},\n")

        f.write("};\n")

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <output directory>")
        sys.exit(64)
    output_dir = sys.argv[1]

    define_ast(output_dir, "Expression", [
        "Binary   : left: Expression, operator: Token, right: Expression",
        "Grouping : expression: Expression",
        "Literal  : value: *Expression",
        "Unary    : operator: Token, right: Expression",
    ])

if __name__ == "__main__":
    main()