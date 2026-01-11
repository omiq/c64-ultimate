import sys
import requests


def run_prg(reader):
    """
    Run a PRG file on the C64 Ultimate device.
    
    Args:
        reader: A file-like object or bytes containing the PRG data
        
    Returns:
        None on success
        
    Raises:
        requests.RequestException: If the HTTP request fails
    """
    url = "http://192.168.0.64/v1/runners:run_prg"
    
    headers = {
        "Content-Type": "application/octet-stream"
    }
    
    # If reader is bytes, use it directly; otherwise read from file-like object
    if isinstance(reader, bytes):
        data = reader
    else:
        data = reader.read()
    
    response = requests.post(url, data=data, headers=headers)
    response.raise_for_status()
    
    return response.text

if __name__ == "__main__":
    # check cli parameters and if used load the file and run it
    if len(sys.argv) > 1:
        file = sys.argv[1]
        with open(file, "rb") as f:
            response = run_prg(f)
            print(response)
    else:
        print("Usage: python runner.py <file>")
        sys.exit(1)

