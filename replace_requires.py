import os
import re
from glob import glob

error_def_pattern = re.compile(r'error\s+([A-Za-z0-9_]+)\(\);')
require_pattern = re.compile(r'require\(([^,]+),\s*"([^"]+)"\);')

errors = set()

def to_camel_case(s):
    s = re.sub(r'[^a-zA-Z0-9]', ' ', s).title().replace(' ', '')
    return s

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    new_content = content
    matches = require_pattern.findall(content)
    
    for expr, msg in matches:
        error_name = to_camel_case(msg)
        if error_name == "":
            error_name = "CustomError"
        errors.add(error_name)
        
        orig = f'require({expr}, "{msg}");'
        repl = f'if (!({expr})) revert {error_name}();'
        new_content = new_content.replace(orig, repl)
        
    if new_content != content:
        # Check if we need to add import for IAgentboxErrors
        if "interface IAgentboxErrors" not in new_content and "IAgentboxErrors.sol" not in new_content:
            pass # we'll just put errors in a common file or inside the file
            # wait, if we define them in IAgentboxErrors, we need to import it or define it.
            # actually it's better to just put the errors in IAgentboxErrors.sol
            
        with open(filepath, 'w') as f:
            f.write(new_content)

for filepath in glob('src/**/*.sol', recursive=True):
    if "AgentboxDiamond" in filepath or "DiamondLoupeFacet" in filepath: continue
    process_file(filepath)

with open('src/interfaces/IAgentboxErrors.sol', 'w') as f:
    f.write('// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\ninterface IAgentboxErrors {\n')
    for e in sorted(list(errors)):
        f.write(f'    error {e}();\n')
    f.write('}\n')

