"""
Merriam-Webster Word of the Day fetcher.

Fetches the word of the day from the Merriam-Webster RSS feed.
"""

import requests
import xml.etree.ElementTree as ET
from typing import Dict, Optional


def get_word_of_the_day() -> Optional[Dict[str, str]]:
    """
    Fetch the Merriam-Webster Word of the Day from RSS feed.
    
    Returns:
        A dictionary with 'title' (the word) and 'description' (the definition),
        or None if there's an error fetching/parsing the feed.
        
    Example:
        >>> result = get_word_of_the_day()
        >>> print(result['title'])
        'schmooze'
        >>> print(result['description'])
        'To schmooze is to warmly chat with someone often in order to gain favor...'
    """
    url = "https://www.merriam-webster.com/wotd/feed/rss2"
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        # Parse the XML/RSS feed
        root = ET.fromstring(response.content)
        
        # Find the first item (most recent word of the day)
        # RSS items are typically in the channel/item path
        item = root.find('.//item')
        
        if item is None:
            return None
        
        # Extract title and description
        title_elem = item.find('title')
        description_elem = item.find('description')
        
        if title_elem is None or description_elem is None:
            return None
        
        title = title_elem.text.strip() if title_elem.text else ""
        
        # Description contains HTML, we'll return it as-is
        # You can parse it further if needed
        description = description_elem.text.strip() if description_elem.text else ""
        
        return {
            'title': title,
            'description': description
        }
        
    except (requests.RequestException, ET.ParseError, AttributeError) as e:
        print(f"Error fetching word of the day: {e}")
        return None


if __name__ == "__main__":
    # Test the function
    result = get_word_of_the_day()
    if result:
        print(f"Word of the Day: {result['title']}")
        print(f"\nDescription:\n{result['description']}")
    else:
        print("Failed to fetch word of the day")
