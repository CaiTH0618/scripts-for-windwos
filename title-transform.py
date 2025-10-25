import re
import pyperclip


def title_transform(text: str) -> str:
    """
    Replace all non-letter, non-digit characters in the input string with underscores.
    Postprocessing: Replace multiple consecutive underscores with a single underscore,
    and remove leading/trailing underscores.
    
    Args:
        text (str): The input string to transform
        
    Returns:
        str: The transformed string with non-letter, non-digit characters replaced by underscores
    """
    # Replace all non-letter, non-digit characters with underscores
    result = re.sub(r'[^a-zA-Z0-9]', '_', text)
    
    # Replace multiple consecutive underscores with a single underscore
    result = re.sub(r'_+', '_', result)
    
    # Remove leading and trailing underscores
    result = result.strip('_')
    
    return result


def test():
    # Test the function
    # test_string = "Hello, World! 123"
    # test_string = "[][]][]Hello,[][][] World! ,,,,123[][]]"
    test_string = "Hydra: Harnessing Expert Popularity for Efficient_Mixture-of-Expert Inference on Chiplet System"
    transformed = title_transform(test_string)
    print(f"Original: '{test_string}'")
    print(f"Transformed: '{transformed}'")


def run():
    while True:
        str_in = ""
        print("\n>>> Input string >>>")
        while True:
            a = str(input())
            if a != "":
                str_in += " " + a
            else:
                break
        str_out = title_transform(str_in)
        if str_out != "":
            pyperclip.copy(str_out)  # Copy to clipboard
            print("\n>>> Output string >>>")
            print(str_out)


if __name__ == "__main__":
    # test()
    run()
