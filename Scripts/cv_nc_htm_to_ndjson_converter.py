import os
import json
from bs4 import BeautifulSoup
from pathlib import Path
from tqdm import tqdm

# Configuration
CHM_ROOT = "C:/CV_Help/HTML_Extracted"
TARGET_FOLDERS = ["CVEnglish", "NCEnglish"]
NDJSON_OUTPUT_DIR = "C:/CV_Help/NDJSON_Bundles"
SOURCE_TYPE = "help_file"

# Ensure output directory exists
os.makedirs(NDJSON_OUTPUT_DIR, exist_ok=True)

def extract_table(elem):
    headers = []
    rows = []
    for row in elem.find_all('tr'):
        cells = [cell.get_text(separator=' ').strip() for cell in row.find_all(['th', 'td'])]
        if not headers:
            headers = cells
        else:
            rows.append(cells)
    return {"type": "table", "data": {"headers": headers, "rows": rows}}


def convert_htm_to_ndjson():
    print("Converting HTM files to NDJSON...")
    buckets = {"Basics": [], "Parts": [], "Assemblies": [], "Jobs": [], "Tips": [], "Nested_CNC": [], "General": []}
    for target_folder in TARGET_FOLDERS:
        target_path = Path(CHM_ROOT) / target_folder
        for root, dirs, files in os.walk(target_path):
            for file in files:
                if file.endswith('.htm'):
                    file_path = os.path.join(root, file)
                    file_stem = Path(file_path).stem

                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        soup = BeautifulSoup(f, 'html.parser')
                        elements = []
                        for elem in soup.find_all(['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'table', 'a']):
                            if elem.name == 'table':
                                elements.append(extract_table(elem))
                            elif elem.name == 'a' and 'href' in elem.attrs:
                                link_text = elem.get_text(separator=' ').strip()
                                href = elem['href'].replace('\\', '/')
                                elements.append({"type": "link", "data": {"text": link_text, "url": href}})
                            else:
                                text_content = elem.get_text(separator=' ').strip()
                                if text_content:
                                    elements.append({"type": "text", "data": text_content})

                        json_data = {
                            "title": file_stem,
                            "content": elements,
                            "source_file": file_path.replace(CHM_ROOT + os.sep, ''),
                            "source_type": SOURCE_TYPE
                        }

                        # Assign to correct bucket based on directory context
                        relative_path = file_path.replace(CHM_ROOT + os.sep, '')
                        if "Part_Level" in relative_path:
                            buckets["Parts"].append(json_data)
                        elif "Assembly_Level" in relative_path:
                            buckets["Assemblies"].append(json_data)
                        elif "Job_Level" in relative_path:
                            buckets["Jobs"].append(json_data)
                        elif "System_Level" in relative_path or "Introduction" in relative_path or "Room_Level" in relative_path:
                            buckets["Basics"].append(json_data)
                        elif "Tips_Tricks_FAQs" in relative_path:
                            buckets["Tips"].append(json_data)
                        elif "NCEnglish" in relative_path:
                            buckets["Nested_CNC"].append(json_data)
                        else:
                            buckets["General"].append(json_data)
    
    # Write out each NDJSON bucket without extra formatting
    for bucket_name, items in buckets.items():
        output_file = os.path.join(NDJSON_OUTPUT_DIR, f"{bucket_name.lower()}.ndjson")
        with open(output_file, 'w', encoding='utf-8') as ndjson_file:
            for item in items:
                # Ensure each object is on a single line
                ndjson_file.write(json.dumps(item, separators=(",", ":")) + "\n")
    print("HTM to NDJSON conversion complete.")


if __name__ == '__main__':
    convert_htm_to_ndjson()
    print("Conversion complete.")
