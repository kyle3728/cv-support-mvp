import os
import json
import csv
import uuid
from bs4 import BeautifulSoup
from pathlib import Path
from tqdm import tqdm  # For progress indication

# Configurations
#
# Source Types:
# - help_file: Cabinet Vision built-in help files
# - user_forum: Cabinet Vision user forum (paid)
# - community_chat: Publicly available Discord discussions
# - public_snippet: Random code snippets shared online
# - other: Any other data sources
#
CHM_ROOT = 'C:/CV_Help/HTML_Extracted'
IMAGE_METADATA_FILE = 'C:/CV_Help/Metadata/all_images_with_paths.txt'
ALIAS_MAP_FILE = 'C:/CV_Help/Metadata/alias_map.csv'
MANUAL_ALIAS_MAP_FILE = 'C:/CV_Help/Metadata/manual_alias_map.csv'
DUPLICATES_FILE = 'C:/CV_Help/Metadata/duplicates_in_index.txt'
UUID_MAP_FILE = 'C:/CV_Help/Metadata/uuid_map.csv'
JSON_OUTPUT_DIR = 'C:/CV_Help/JSON_Converted'
SOURCE_TYPE = 'help_file'  # Set this based on the data source

# Ensure output directory exists
os.makedirs(JSON_OUTPUT_DIR, exist_ok=True)

# Create or load UUID map
uuid_map = {}
if os.path.exists(UUID_MAP_FILE):
    with open(UUID_MAP_FILE, 'r') as f:
        reader = csv.reader(f)
        uuid_map = {rows[0]: rows[1] for rows in reader}


def deduplicate_images():
    print("Deduplicating images...")
    unique_images = {}
    duplicate_images = set()
    
    # Read duplicates file
    with open(DUPLICATES_FILE, 'r') as f:
        for line in f:
            parts = line.strip().split('|')
            if len(parts) == 2:
                filename, path = parts
                if filename not in unique_images:
                    unique_images[filename] = path
                else:
                    duplicate_images.add(filename)
    
    # Write consolidated alias map
    with open(ALIAS_MAP_FILE, 'w', newline='') as f:
        writer = csv.writer(f)
        for filename, path in unique_images.items():
            writer.writerow([filename, path])

    print(f"Deduplication complete. Unique images: {len(unique_images)}")
    print(f"Duplicate images removed: {len(duplicate_images)}")


def extract_table(elem):
    # Extract table headers and rows
    headers = []
    rows = []
    is_parameter_table = False
    for row in elem.find_all('tr'):
        cells = [cell.get_text(separator=' ').strip() for cell in row.find_all(['th', 'td'])]
        if not headers:
            headers = cells  # First row is the header
            # Detect parameter table by common field names
            if set(headers) & {"Field Name", "Description", "Valid Range", "Visibility", "Applies To"}:
                is_parameter_table = True
        else:
            rows.append(cells)
    
    # Return structured table if it's a parameter table
    if is_parameter_table:
        return {
            "type": "parameter_table",
            "data": {
                "headers": headers,
                "rows": rows
            }
        }
    else:
        return {
            "type": "table",
            "data": {
                "headers": headers,
                "rows": rows
            }
        }


def extract_context_tags(elements):
    # Extract context tags from surrounding text
    context_tags = []
    for elem in elements:
        if elem['type'] == 'text':
            words = elem['data'].split()
            context_tags.extend(words)
    # Return a unique, sorted list of context tags
    return sorted(set(context_tags))


def convert_htm_to_json():
    print("Converting HTM files to JSON...")
    all_files = []
    for root, dirs, files in os.walk(CHM_ROOT):
        for file in files:
            if file.endswith('.htm'):
                all_files.append(os.path.join(root, file))
    
    for file_path in tqdm(all_files, desc="Processing HTM Files", unit="file"):
        file_stem = Path(file_path).stem
        # Generate or reuse UUID for this file
        if file_stem not in uuid_map:
            uuid_map[file_stem] = str(uuid.uuid4())
        file_uuid = uuid_map[file_stem]
        
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            soup = BeautifulSoup(f, 'html.parser')
            elements = []
            for elem in soup.find_all(['p', 'img', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'table', 'a']):
                if elem.name == 'img' and 'src' in elem.attrs:
                    image_name = elem['src'].split('/')[-1]
                    context_tags = extract_context_tags(elements)
                    elements.append({
                        "type": "image",
                        "data": image_name,
                        "description": "[Placeholder for AI-generated description]",
                        "context_tags": context_tags
                    })
                elif elem.name == 'table':
                    elements.append(extract_table(elem))
                elif elem.name == 'a' and 'href' in elem.attrs:
                    link_text = elem.get_text(separator=' ').strip()
                    href = elem['href'].replace('\\', '/')  # Normalize paths
                    link_stem = Path(href).stem
                    # Replace HTM link with UUID if available
                    if link_stem in uuid_map:
                        link_uuid = uuid_map[link_stem]
                        elements.append({
                            "type": "link",
                            "data": {
                                "text": link_text,
                                "uuid": link_uuid,
                                "description": "[Placeholder for AI-generated description]"
                            }
                        })
                else:
                    text_content = elem.get_text(separator=' ').strip()
                    if text_content:
                        elements.append({"type": "text", "data": text_content})
            
            json_data = {
                "id": file_uuid,
                "title": file_stem,
                "content": elements,
                "source_file": file_path.replace(CHM_ROOT + os.sep, ''),
                "version": "2024",
                "source_type": SOURCE_TYPE
            }
            output_file = os.path.join(JSON_OUTPUT_DIR, file_stem + '.json')
            with open(output_file, 'w', encoding='utf-8') as json_file:
                json.dump(json_data, json_file, indent=4)
    print("HTM to JSON conversion complete.")

    # Save updated UUID map
    with open(UUID_MAP_FILE, 'w', newline='') as f:
        writer = csv.writer(f)
        for key, value in uuid_map.items():
            writer.writerow([key, value])


def main():
    deduplicate_images()
    convert_htm_to_json()


if __name__ == '__main__':
    main()
