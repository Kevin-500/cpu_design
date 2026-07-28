#!/usr/bin/env python3
"""
Convert Xilinx .coe memory initialization file to Verilog $readmemh format (.mem)
Usage: python coe2mem.py <input.coe> <output.mem>
"""
import sys
import re
import os

def coe_to_mem(coe_path, mem_path):
    with open(coe_path, 'r') as f:
        content = f.read()
    
    # Remove comments and header lines
    # .coe format: memory_initialization_radix=16;
    #              memory_initialization_vector=
    #              AABBCCDD,
    #              ...
    
    # Find the start of data
    match = re.search(r'memory_initialization_vector\s*=', content, re.IGNORECASE)
    if not match:
        print(f"ERROR: Cannot find 'memory_initialization_vector=' in {coe_path}", file=sys.stderr)
        sys.exit(1)
    
    data = content[match.end():]
    # Remove trailing semicolon and whitespace
    data = re.sub(r';.*', '', data)
    
    # Extract all 8-digit hex words
    words = re.findall(r'[0-9a-fA-F]{8}', data)
    
    if not words:
        print("ERROR: No hex words found in coe file", file=sys.stderr)
        sys.exit(1)
    
    with open(mem_path, 'w') as f:
        for w in words:
            f.write(w + '\n')
    
    print(f"Converted {len(words)} words from {coe_path} -> {mem_path}")
    print(f"Total size: {len(words) * 4} bytes ({len(words) / 256:.1f} KB)")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.coe> <output.mem>", file=sys.stderr)
        sys.exit(1)
    
    coe_path = sys.argv[1]
    mem_path = sys.argv[2]
    
    if not os.path.exists(coe_path):
        print(f"ERROR: File not found: {coe_path}", file=sys.stderr)
        sys.exit(1)
    
    coe_to_mem(coe_path, mem_path)
