import importlib.util
import sys

package_name = 'kaslcred'

spec = importlib.util.find_spec(package_name)
if spec is None:
    print(f'{package_name} is not installed. Do a "pip install {package_name}"')
    sys.exit(1)

