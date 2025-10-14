#!/usr/bin/env python3
import time
import sys
import os
import json
import requests
import re

# Usage:
# python vllmChapter.py <chapter_file> <knowledge_base_json> <output_dir>

def extract_entities(chapter_text, kb_entities):
    """
    Return a list of entity names from the KB that appear in the chapter.
    """
    entities_in_chapter = []
    for entity in kb_entities:
        # Simple word boundary check, case-sensitive
        if re.search(rf"\b{re.escape(entity)}\b", chapter_text):
            entities_in_chapter.append(entity)
    return entities_in_chapter

def save_json(obj, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)

def main():
    if len(sys.argv) != 4:
        print("Usage: vllmChapter.py <chapter_file> <knowledge_base_json> <output_dir>")
        sys.exit(1)

    chapter_file = sys.argv[1]
    kb_file = sys.argv[2]
    output_dir = sys.argv[3]

    os.makedirs(output_dir, exist_ok=True)

    if not os.path.isfile(chapter_file):
        print(f"Error: Chapter file '{chapter_file}' not found.")
        sys.exit(1)
    if not os.path.isfile(kb_file):
        print(f"Error: Knowledge base file '{kb_file}' not found.")
        sys.exit(1)

    # Read chapter text
    with open(chapter_file, "r", encoding="utf-8") as f:
        chapter_text = f.read()

    # Read knowledge base
    with open(kb_file, "r", encoding="utf-8") as f:
        kb = json.load(f)

    # Identify entities present in chapter
    entities_in_chapter = extract_entities(chapter_text, kb.keys())

    # Filter KB for entities in this chapter
    filtered_kb = {name: kb[name] for name in entities_in_chapter}
    save_json(filtered_kb, os.path.join(output_dir, "filtered_kb.json"))

    # Construct prompt for the LLM
    main_prompt = (
        "You are an assistant that identifies entities (e.g. characters, places, powers, possessions, objects, periods, organizations, etc) in a chapter."
        "Be extermely thorough in identifying all entities. "
        "You are provided with the chapter text and a knowledge base for reference. "
        "For each entity mentioned in the chapter, return a JSON object with: "
        "(1) 'chapterNumber' (detected chapter number from text), "
        "(2) 'entities' as a map from entity name to a detailed 'description'. "
        "Descriptions must include historical information from the knowledge base if available. "
        "Identify at least 30 different entities."
        "Output only JSON with no extra commentary."
    )

    main_prompt = (
        "you are an advanced literary analysis assistant specialized in entity extraction. "
        "your task is to identify and provide detailed information about all entities mentioned in a chapter. "
        "entities include, but are not limited to, characters, places, organizations, objects, powers, possessions, events, periods, or concepts. "
        "you are provided with the full chapter text and a knowledge base for reference. "
        "be extremely thorough, aiming to identify at least 30 unique entities, including minor ones. "
        "for each entity, provide a detailed description that includes: "
        "(a) its nature or type (e.g., character, location, object), "
        "(b) historical or contextual information from the knowledge base if available, "
        "(c) relationships or interactions with other entities if relevant, "
        "(d) relevant attributes, abilities, or characteristics. "
        "detect and include the chapter number from the text. "
        "output must be strictly valid json, following this structure: "
        "{"
        "'chapternumber': <detected chapter number>, "
        "'entities': {"
            "<entity_name> : {"
                "'type': <entity type>, "
                "'description': <detailed description>, "
                "'relationships': <related entities if applicable>"
            "}, "
            "... "
        "}"
        "}"
        "do not include any text outside the json. "
        "ensure consistent formatting, complete sentences, and maximum detail for each entity. "
        "if the chapter mentions fewer than 30 entities, still identify all possible entities exhaustively."
    )


    combined_input = json.dumps({
        "chapterText": chapter_text,
        "knowledgeBase": filtered_kb
    })

    final_prompt = f"{main_prompt}\n\nInput:\n{combined_input}"
    with open(os.path.join(output_dir, "final_prompt.txt"), "w", encoding="utf-8") as f:
        f.write(final_prompt)

    payload = {
        "model": "mistralai/Mistral-7B-Instruct-v0.3",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": final_prompt}
        ],
        "max_tokens": 12000,
        "temperature": 0.0
    }

    try:
        response = requests.post(
            "http://127.0.0.1:1234/v1/chat/completions",
            headers={
                "Content-Type": "application/json",
                "Authorization": "Bearer lm-studio"
            },
            json=payload,
            timeout=600
        )
        response.raise_for_status()
        data = response.json()

        with open(os.path.join(output_dir, "llm_response.txt"), "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        # Save full raw LLM output
        llm_raw_output = data.get("choices", [{}])[0].get("message", {}).get("content", "").strip()
        with open(os.path.join(output_dir, "llm_raw_output.txt"), "w", encoding="utf-8") as f:
            f.write(llm_raw_output)

        if not llm_raw_output:
            print("⚠️ No content found in the API response.", file=sys.stderr)
            sys.exit(1)

        # Parse the returned JSON
        chapter_output = json.loads(llm_raw_output)
        with open(os.path.join(output_dir, "parsed_output.json"), "w", encoding="utf-8") as f:
            json.dump(chapter_output, f, indent=2, ensure_ascii=False)

        chapter_number = chapter_output.get("chapterNumber")
        entities_data = chapter_output.get("entities", {})

        # Build new partial knowledge base
        new_kb = {}
        for entity, info in entities_data.items():
            if entity in kb:
                first_seen = kb[entity].get("firstSeenChapter", chapter_number)
            else:
                first_seen = chapter_number
            new_kb[entity] = {
                "description": info["description"],
                "firstSeenChapter": first_seen,
                "lastSeenChapter": chapter_number
            }

        # Save final partial KB
        save_json(new_kb, os.path.join(output_dir, "final_partial_kb.json"))

        print(f"All outputs saved to '{output_dir}'.")

    except requests.exceptions.RequestException as e:
        print(f"Error communicating with VLLM API: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print("Error: Received invalid JSON from API.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    start_time = time.time()
    main()
    end_time = time.time()
    print(f"Execution Time: {end_time - start_time:.2f} seconds")

