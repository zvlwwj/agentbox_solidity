import os
import re
from glob import glob

for filepath in glob('src/**/*.sol', recursive=True):
    if "Errors.sol" in filepath or "IAgentboxErrors.sol" in filepath: continue
    
    with open(filepath, 'r') as f:
        content = f.read()

    if "revert " in content:
        # Determine relative path to Errors.sol
        depth = filepath.count('/') - 1
        prefix = '../' * depth if depth > 0 else './'
        import_stmt = f'import "{prefix}Errors.sol";'
        
        if import_stmt not in content:
            # find pragma
            new_content = re.sub(r'(pragma solidity [^;]+;)', r'\1\n\n' + import_stmt, content, count=1)
            with open(filepath, 'w') as f:
                f.write(new_content)

