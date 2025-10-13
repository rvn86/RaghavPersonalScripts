#!/usr/bin/env python3
import sys
import os
import json
import requests

# Usage:
# python vllmChapter.py "Main prompt" /tmp/chapter.txt "Suffix prompt"

def main():
    if len(sys.argv) != 4:
        print("Usage: vllmChapter.py <main_prompt> <input_file> <suffix_prompt>")
        sys.exit(1)

    main_prompt = sys.argv[1]
    file_path = sys.argv[2]
    suffix_prompt = sys.argv[3]

    if not os.path.isfile(file_path):
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)

    # Read file content
    with open(file_path, "r", encoding="utf-8") as f:
        file_content = f.read()

    # Combine prompts
    combined = f"{main_prompt}```{file_content}```{suffix_prompt}"

    # Prepare JSON payload
    payload = {
        "model": "mistralai/Mistral-7B-Instruct-v0.3",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": combined}
        ],
        "max_tokens": 10000,
        "stop": []
    }

    try:
        response = requests.post(
            "http://127.0.0.1:1234/v1/chat/completions",
            headers={
                "Content-Type": "application/json",
                "Authorization": "Bearer lm-studio"
            },
            json=payload,
            timeout=600  # 10-minute timeout for long generations
        )
        response.raise_for_status()
        data = response.json()

        # Extract assistant message content
        content = (
            data.get("choices", [{}])[0]
            .get("message", {})
            .get("content", "")
            .strip()
        )

        if not content:
            print("⚠️ No content found in the API response.", file=sys.stderr)
            sys.exit(1)

        print(content)
        print(data.get("usage"))

    except requests.exceptions.RequestException as e:
        print(f"Error communicating with VLLM API: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print("Error: Received invalid JSON from API.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()


