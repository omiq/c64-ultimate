"""
Merriam-Webster Word of the Day fetcher.

Fetches the word of the day from the Merriam-Webster RSS feed.
"""

import requests
import xml.etree.ElementTree as ET
import re
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
        
        # Parse HTML description to extract just the definition
        description_html = description_elem.text.strip() if description_elem.text else ""
        

        # Extract definition from HTML using regex
        # The definition is in a <p> tag and typically starts with "To [word]", "A [word]", etc.
        # Look for <p> tags that contain definition-like text
        definition_pattern = r'<p>(To [^<]+(?:is|are|refers|means|is a)[^<]+\.)</p>'
        match = re.search(definition_pattern, description_html, re.IGNORECASE)
        
        if match:
            definition = match.group(1)
            # Clean up any HTML entities
            definition = definition.replace('&nbsp;', ' ').replace('&#149;', '')
            definition = re.sub(r'<[^>]+>', '', definition)  # Remove any remaining HTML tags
            print("Match Found:")
        else:
            # Fallback: try to find any <p> tag that looks like a definition
            # Pattern: starts with To/A/An/The followed by the word
            fallback_pattern = r'<p>((?:To|A|An|The|adjective)\s+[^<]+\.)</p>'
            match = re.search(fallback_pattern, description_html, re.IGNORECASE)
            if match:
                definition = match.group(1)
                definition = definition.replace('&nbsp;', ' ').replace('&#149;', '')
                definition = re.sub(r'<[^>]+>', '', definition)
                print("Fallback Found:")
            else:
                definition = description_html.splitlines()[9]
                definition = definition.replace('&nbsp;', ' ').replace('&#149;', '')
                definition = re.sub(r'<[^>]+>', '', definition)
                print("Match NOT Found:")
        
        definition = definition.strip()
        
        print(title,definition)

        return {
            'title': title,
            'description': definition
        }
        
    except (requests.RequestException, ET.ParseError, AttributeError, Exception) as e:
        print(f"Error fetching word of the day: {e}")
        return None


if __name__ == "__main__":
    # Test the function
    result = get_word_of_the_day()
    if result:
        print(f"{result['title']}\n{result['description']}")
    else:
        print("Failed to fetch word of the day")
