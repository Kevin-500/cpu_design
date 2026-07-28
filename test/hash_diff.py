# 导入 hashlib 模块，以便使用哈希函数
import hashlib

# 定义一个函数，用于计算文件的哈希值
def calculate_file_hash(file_path, hash_algorithm="sha256"):
    # 创建一个哈希对象，使用指定的哈希算法
    hash_obj = hashlib.new(hash_algorithm)

    # 打开文件以二进制只读模式
    with open(file_path, "rb") as file:
        while True:
            # 从文件中读取数据块（64 KB大小）
            data = file.read(65536)  # 64 KB buffer
            if not data:
                break

            # 更新哈希对象，将数据块添加到哈希值中
            hash_obj.update(data)

    # 返回哈希值的十六进制表示
    return hash_obj.hexdigest() 

# 指定要比较的两个文件的路径 
file1 = "F:\\file\\workspace\\verilog\\cpu_design\\bitstream\\coremark.bit"
file2 = "F:\\file\\workspace\\verilog\\cpu_design\\bitstream\\ctest2.bit"

# 使用哈希函数计算文件1的哈希值 
hash1 = calculate_file_hash(file1) 

# 使用哈希函数计算文件2的哈希值 
hash2 = calculate_file_hash(file2) 

# 比较两个哈希值，如果相同，表示文件内容相同 
if hash1 == hash2: 
    print("hash = ", hash1)
    print("两个文件相同") 
else: 
    print("hash1 = ", hash1)
    print("hash2 = ", hash2)
    print("两个文件不同") 
