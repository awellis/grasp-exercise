#!/usr/bin/env python3
"""
Exercise validation script using JSON Schema
"""

import json
import yaml
import jsonschema
import sys
import argparse
from pathlib import Path

def load_schema(schema_file):
    """Load JSON schema from file"""
    with open(schema_file, 'r') as f:
        return json.load(f)

def load_exercise_data(exercise_file):
    """Load exercise data from YAML or JSON file"""
    with open(exercise_file, 'r') as f:
        if exercise_file.suffix.lower() in ['.yml', '.yaml']:
            return yaml.safe_load(f)
        elif exercise_file.suffix.lower() == '.json':
            return json.load(f)
        else:
            raise ValueError(f"Unsupported file format: {exercise_file.suffix}")

def validate_exercise(exercise_data, schema):
    """Validate exercise data against schema"""
    try:
        jsonschema.validate(exercise_data, schema)
        return True, []
    except jsonschema.ValidationError as e:
        return False, [str(e)]
    except jsonschema.SchemaError as e:
        return False, [f"Schema error: {str(e)}"]

def main():
    parser = argparse.ArgumentParser(description='Validate exercise YAML/JSON files')
    parser.add_argument('exercise_file', help='Path to exercise YAML/JSON file')
    parser.add_argument('--schema', default='exercise-schema.json', 
                       help='Path to JSON schema file')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Print detailed validation results')
    
    args = parser.parse_args()
    
    try:
        # Load schema and exercise data
        schema = load_schema(args.schema)
        exercise_data = load_exercise_data(Path(args.exercise_file))
        
        # Validate
        is_valid, errors = validate_exercise(exercise_data, schema)
        
        if is_valid:
            print(f"✅ {args.exercise_file} is valid!")
            if args.verbose:
                print(f"   Title: {exercise_data['metadata']['title']}")
                print(f"   Checkpoints: {len(exercise_data['checkpoints'])}")
                print(f"   Total steps: {sum(len(cp.get('steps', [])) for cp in exercise_data['checkpoints'])}")
        else:
            print(f"❌ {args.exercise_file} is invalid!")
            for error in errors:
                print(f"   Error: {error}")
            sys.exit(1)
            
    except Exception as e:
        print(f"❌ Error processing {args.exercise_file}: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()